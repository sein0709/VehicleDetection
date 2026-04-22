import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:greyeye_mobile/features/sites/models/site_calibration.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistence boundary for [SiteCalibration]. Defined as an interface
/// so the in-memory test impl can drop in for unit tests, and a future
/// `SupabaseCalibrationStorage` can swap in for cross-device sync
/// without touching the screen.
abstract interface class SiteCalibrationStorage {
  Future<SiteCalibration?> load(String siteId);
  Future<void> save(String siteId, SiteCalibration cal);
  Future<void> clear(String siteId);
}

/// Backed by one JSON file per site under app documents:
///   `${appDocs}/site_calibrations/${siteId}.json`
///
/// Chosen over a Drift table because the data is one-row-per-site with
/// JSON blobs that are never queried into — a relational schema would
/// add a build_runner step for no actual query benefit. Atomic writes
/// (write to `.tmp`, rename) so a crash mid-write doesn't leave a
/// half-flushed file that breaks the loader.
class FileSiteCalibrationStorage implements SiteCalibrationStorage {
  FileSiteCalibrationStorage({Directory? rootOverride})
      : _rootOverride = rootOverride;

  /// Test seam — production callers leave this null and the storage
  /// falls back to `getApplicationDocumentsDirectory()`.
  final Directory? _rootOverride;
  Directory? _resolvedRoot;

  Future<Directory> _root() async {
    if (_resolvedRoot != null) return _resolvedRoot!;
    final base =
        _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'site_calibrations'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _resolvedRoot = dir;
    return dir;
  }

  /// Sanitises [siteId] to a filename — strips path separators and
  /// `..` to prevent a crafted siteId from escaping the root dir.
  String _filenameFor(String siteId) {
    final safe = siteId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$safe.json';
  }

  Future<File> _fileFor(String siteId) async {
    final root = await _root();
    return File(p.join(root.path, _filenameFor(siteId)));
  }

  @override
  Future<SiteCalibration?> load(String siteId) async {
    try {
      final f = await _fileFor(siteId);
      if (!f.existsSync()) return null;
      final raw = await f.readAsString();
      if (raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, Object?>;
      return SiteCalibration.fromJson(json);
    } on Exception catch (e, st) {
      debugPrint('[SiteCalibrationStorage] load failed for $siteId: $e\n$st');
      return null;
    }
  }

  @override
  Future<void> save(String siteId, SiteCalibration cal) async {
    final f = await _fileFor(siteId);
    final tmp = File('${f.path}.tmp');
    final body = const JsonEncoder.withIndent('  ').convert(cal.toJson());
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear(String siteId) async {
    final f = await _fileFor(siteId);
    if (f.existsSync()) await f.delete();
  }
}

/// In-memory impl for unit tests. Does not touch disk.
class InMemorySiteCalibrationStorage implements SiteCalibrationStorage {
  final Map<String, SiteCalibration> _store = {};

  @override
  Future<SiteCalibration?> load(String siteId) async => _store[siteId];

  @override
  Future<void> save(String siteId, SiteCalibration cal) async {
    _store[siteId] = cal;
  }

  @override
  Future<void> clear(String siteId) async {
    _store.remove(siteId);
  }
}
