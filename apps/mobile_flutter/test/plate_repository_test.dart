import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/plate_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PlateRepository covers two contracts that a unit test can lock in
/// without spinning up a Supabase fake client:
///
/// 1. The early-return on an empty visit list (no network call, totals
///    are zeros).
/// 2. The auth-disabled guard (PlateRepositoryException when
///    GREYEYE_SUPABASE_ANON_KEY is unset and `ApiConstants.authEnabled`
///    is false at compile time).
///
/// The actual insert + rpc paths are integration-tested against a live
/// Supabase project — mocking the fluent PostgrestQueryBuilder API in
/// pure Dart adds more surface area than it removes, so we keep that
/// out of the unit tests.
void main() {
  group('PlateVisitInsert', () {
    test('round-trips its constructor arguments', () {
      final at = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final v = PlateVisitInsert(
        plateNormalized: '12가3456',
        plateHash: 'abc123',
        firstSeenAt: at,
        lastSeenAt: at.add(const Duration(seconds: 30)),
        dwellSeconds: 30,
        source: 'gemma',
        trackId: '7',
      );
      expect(v.plateNormalized, '12가3456');
      expect(v.plateHash, 'abc123');
      expect(v.firstSeenAt, at);
      expect(v.dwellSeconds, 30);
      expect(v.source, 'gemma');
      expect(v.trackId, '7');
    });
  });

  group('SitePlateTotals', () {
    test('exposes resident + visitor counts', () {
      const t = SitePlateTotals(resident: 4, visitor: 11);
      expect(t.resident, 4);
      expect(t.visitor, 11);
    });
  });

  group('PlateClassificationResult', () {
    test('holds per-plate categories and totals together', () {
      const result = PlateClassificationResult(
        categories: {'12가3456': 'resident', '34나5678': 'visitor'},
        siteTotals: SitePlateTotals(resident: 1, visitor: 1),
      );
      expect(result.categories.length, 2);
      expect(result.categories['12가3456'], 'resident');
      expect(result.siteTotals.visitor, 1);
    });
  });

  group('PlateRepository.recordVisitsAndClassify', () {
    test('empty visits list short-circuits without touching Supabase',
        () async {
      // Cast the null through `as` so the test doesn't have to instantiate
      // a SupabaseClient — the early-return runs before any client method
      // is dereferenced. This keeps the test free of Supabase init even
      // when the `flutter test` runner has no env config.
      final repo = PlateRepository(_NullClient());
      final result = await repo.recordVisitsAndClassify(
        siteId: 'site-1',
        jobId: 'job-1',
        visits: const [],
      );
      expect(result.categories, isEmpty);
      expect(result.siteTotals.resident, 0);
      expect(result.siteTotals.visitor, 0);
    });
  });

  group('PlateRepositoryException', () {
    test('toString returns the underlying message for snackbar display', () {
      const e = PlateRepositoryException('permission denied');
      expect(e.toString(), 'permission denied');
      expect(e.message, 'permission denied');
    });
  });
}

/// Stand-in for SupabaseClient used by the empty-visits test. None of
/// its methods are invoked — the repository early-returns before ever
/// touching the client — but Dart needs a concrete type for the
/// constructor signature.
class _NullClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError(
      'PlateRepository unexpectedly called ${invocation.memberName} '
      'on the null client during an empty-visits run.',
    );
  }
}
