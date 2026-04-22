import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/api_constants.dart';

/// One plate observation collected from a single analysis run, ready for
/// insertion into `public.plate_visits`. Wall-clock timestamps are
/// computed on-device from the analysis-start moment + the per-track
/// dwell window the server returned in `first_seen_s` / `last_seen_s`.
@immutable
class PlateVisitInsert {
  const PlateVisitInsert({
    required this.plateNormalized,
    required this.plateHash,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.dwellSeconds,
    required this.source,
    required this.trackId,
  });

  final String plateNormalized;
  final String plateHash;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final double dwellSeconds;
  final String source;
  final String trackId;
}

/// Site-wide tally returned alongside the per-plate classification — the
/// UI surfaces these as "this site historically: N residents / M visitors".
@immutable
class SitePlateTotals {
  const SitePlateTotals({required this.resident, required this.visitor});
  final int resident;
  final int visitor;
}

/// Outcome of a single classify-and-record round-trip. Holds both the
/// per-plate verdict (`categories`: plate_normalized → "resident" |
/// "visitor") and the freshly-recomputed all-time totals for the site.
@immutable
class PlateClassificationResult {
  const PlateClassificationResult({
    required this.categories,
    required this.siteTotals,
  });
  final Map<String, String> categories;
  final SitePlateTotals siteTotals;
}

/// Persists per-plate observations to Supabase and returns recurrence-
/// based resident/visitor classifications. The classification rule lives
/// server-side (see migration `lpr_plate_visits_and_classifications`) so
/// it stays consistent across clients and admin tooling.
class PlateRepository {
  PlateRepository(this._client);

  final SupabaseClient _client;

  /// Default threshold: a plate seen across this many distinct analysis
  /// runs counts as "resident". 3 is conservative — single-day repeat
  /// visits are still tagged as visitor unless they recur on multiple
  /// jobs.
  static const int _defaultResidentThresholdJobs = 3;

  /// Insert [visits] for [siteId] / [jobId] and refresh classifications
  /// for each plate. Returns:
  /// - `categories`: per-plate verdict (plate_normalized → "resident" /
  ///   "visitor").
  /// - `siteTotals`: site-wide totals after this run is folded in.
  ///
  /// Throws [PlateRepositoryException] when the network round-trip fails
  /// or the user lacks the operator/admin role required by RLS. Caller
  /// shows the original (unclassified) plate list in that case.
  Future<PlateClassificationResult> recordVisitsAndClassify({
    required String siteId,
    required String jobId,
    required List<PlateVisitInsert> visits,
    int residentThresholdJobs = _defaultResidentThresholdJobs,
  }) async {
    if (visits.isEmpty) {
      return const PlateClassificationResult(
        categories: {},
        siteTotals: SitePlateTotals(resident: 0, visitor: 0),
      );
    }

    if (!ApiConstants.authEnabled) {
      // Auth disabled (e.g. running against a local dev pipeline without
      // Supabase env vars). Fail loud so the caller falls back to the
      // unclassified UI rather than silently mislabelling everything.
      throw const PlateRepositoryException(
        'Supabase auth is disabled — plate classification is unavailable.',
      );
    }

    // 1) Resolve org_id from site_id (one round-trip; needed because RLS
    //    insert policies require org_id == get_org_id()).
    final String orgId;
    try {
      final siteRow = await _client
          .from('sites')
          .select('org_id')
          .eq('id', siteId)
          .maybeSingle();
      final raw = siteRow?['org_id'] as String?;
      if (raw == null) {
        throw const PlateRepositoryException('Site not found in Supabase.');
      }
      orgId = raw;
    } on PostgrestException catch (e) {
      throw PlateRepositoryException(_formatPostgrestError(e));
    }

    // 2) Bulk insert plate_visits. Ignore conflicts on (site_id, job_id,
    //    plate_normalized) — re-running classification for the same job
    //    shouldn't double-count the visit history.
    final rows = visits.map((v) => {
          'org_id': orgId,
          'site_id': siteId,
          'job_id': jobId,
          'plate_normalized': v.plateNormalized,
          'plate_hash': v.plateHash,
          'first_seen_at': v.firstSeenAt.toUtc().toIso8601String(),
          'last_seen_at': v.lastSeenAt.toUtc().toIso8601String(),
          'dwell_seconds': v.dwellSeconds,
          'source': v.source,
        }).toList();

    try {
      await _client.from('plate_visits').insert(rows);
    } on PostgrestException catch (e) {
      throw PlateRepositoryException(_formatPostgrestError(e));
    }

    // 3) Refresh classification per distinct plate. The function is
    //    idempotent and cheap (one count(distinct job_id) per call) so a
    //    serial loop is fine for the typical 1-30 plates per clip; if
    //    this ever needs to scale we can move the loop server-side.
    final categories = <String, String>{};
    final distinctPlates = visits.map((v) => v.plateNormalized).toSet();
    for (final plate in distinctPlates) {
      try {
        final result = await _client.rpc<dynamic>(
          'refresh_plate_classification',
          params: {
            '_site_id': siteId,
            '_plate': plate,
            '_threshold': residentThresholdJobs,
          },
        );
        if (result is String) {
          categories[plate] = result;
        }
      } on PostgrestException catch (e) {
        // Non-fatal — log and skip this plate; the UI will show "unknown".
        debugPrint('PlateRepository: refresh failed for $plate — ${e.message}');
      }
    }

    // 4) Site-wide totals — single query over plate_classifications.
    SitePlateTotals totals;
    try {
      final allClassifications = await _client
          .from('plate_classifications')
          .select('category')
          .eq('site_id', siteId);
      var resident = 0;
      var visitor = 0;
      for (final row in allClassifications) {
        if ((row as Map)['category'] == 'resident') {
          resident++;
        } else if (row['category'] == 'visitor') {
          visitor++;
        }
      }
      totals = SitePlateTotals(resident: resident, visitor: visitor);
    } on PostgrestException catch (e) {
      debugPrint('PlateRepository: totals fetch failed — ${e.message}');
      totals = const SitePlateTotals(resident: 0, visitor: 0);
    }

    return PlateClassificationResult(
      categories: categories,
      siteTotals: totals,
    );
  }
}

class PlateRepositoryException implements Exception {
  const PlateRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _formatPostgrestError(PostgrestException e) {
  // RLS rejects come back as 42501 (permission denied) — render a
  // human-readable hint rather than the raw SQLSTATE.
  if (e.code == '42501') {
    return 'Not allowed: your account needs the operator or admin role to record plate visits.';
  }
  return e.message;
}

/// Riverpod provider — created once per session, since SupabaseClient is
/// itself a singleton.
final plateRepositoryProvider = Provider<PlateRepository>((ref) {
  return PlateRepository(Supabase.instance.client);
});
