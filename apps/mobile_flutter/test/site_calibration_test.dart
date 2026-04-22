import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/models/site_calibration.dart';
import 'package:greyeye_mobile/features/sites/services/site_calibration_storage.dart';
import 'package:greyeye_mobile/features/sites/services/task_calibration_builder.dart';

void main() {
  group('SiteCalibration JSON round-trip', () {
    SiteCalibration roundTrip(SiteCalibration original) {
      final encoded = jsonEncode(original.toJson());
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      return SiteCalibration.fromJson(decoded);
    }

    test('empty calibration round-trips to defaults', () {
      final back = roundTrip(SiteCalibration.empty);
      expect(back.includeAnnotatedVideo, isTrue);
      // Vehicles is now part of the default set so out-of-the-box behavior
      // matches the legacy "always count" expectation, but operators can
      // opt out via the picker card.
      expect(back.enabledTasks, contains(AnalysisTask.vehicles));
      expect(back.enabledTasks, contains(AnalysisTask.pedestrians));
      expect(back.trafficLightOverrides, isEmpty);
      expect(back.speedOverride, isNull);
      expect(back.transitOverride, isNull);
      expect(back.countLineOverride, isNull);
      expect(back.lprAllowlist, isEmpty);
    });

    test('count line override round-trips with both endpoints', () {
      const original = SiteCalibration(
        countLineOverride: CountLineOverride(
          inLineXY: [[0.10, 0.40], [0.90, 0.45]],
          outLineXY: [[0.05, 0.80], [0.95, 0.85]],
        ),
      );
      final back = roundTrip(original);
      expect(back.countLineOverride, isNotNull);
      expect(back.countLineOverride!.inLineXY,
          [[0.10, 0.40], [0.90, 0.45]],);
      expect(back.countLineOverride!.outLineXY,
          [[0.05, 0.80], [0.95, 0.85]],);
    });

    test('malformed count line override (one point) is dropped', () {
      final json = {
        'count_line_override': {
          'in_line_xy': [[0.1, 0.5]], // only 1 point
          'out_line_xy': [[0.1, 0.8], [0.9, 0.8]],
        },
      };
      final cal = SiteCalibration.fromJson(json);
      expect(cal.countLineOverride, isNull);
    });

    test('speed override with arbitrary lines_xy round-trips', () {
      const original = SiteCalibration(
        speedOverride: SpeedOverride(
          sourceQuadXY: [
            [0.30, 0.55], [0.70, 0.55], [0.85, 0.95], [0.15, 0.95],
          ],
          linesYRatio: [0.60, 0.90],
          realWorldWidthM: 3.5,
          realWorldLengthM: 20.0,
          linesXY: [
            [[0.10, 0.60], [0.90, 0.62]],
            [[0.05, 0.90], [0.95, 0.91]],
          ],
        ),
      );
      final back = roundTrip(original);
      expect(back.speedOverride!.linesXY, isNotNull);
      expect(back.speedOverride!.linesXY!.length, 2);
      expect(back.speedOverride!.linesXY![0],
          [[0.10, 0.60], [0.90, 0.62]],);
    });

    test('full payload round-trips with every field preserved', () {
      const original = SiteCalibration(
        includeAnnotatedVideo: false,
        enabledTasks: {
          AnalysisTask.vehicles,
          AnalysisTask.pedestrians,
          AnalysisTask.speed,
          AnalysisTask.transit,
          AnalysisTask.trafficLight,
          AnalysisTask.lpr,
        },
        trafficLightOverrides: [
          TrafficLightOverride(
            label: 'main',
            roi: [0.45, 0.05, 0.10, 0.12],
          ),
          TrafficLightOverride(
            label: 'left_turn',
            roi: [0.55, 0.05, 0.08, 0.12],
          ),
        ],
        speedOverride: SpeedOverride(
          sourceQuadXY: [
            [0.30, 0.55], [0.70, 0.55], [0.85, 0.95], [0.15, 0.95],
          ],
          linesYRatio: [0.60, 0.90],
          realWorldWidthM: 3.5,
          realWorldLengthM: 20.0,
        ),
        transitOverride: TransitOverride(
          stopPolygonXY: [
            [0.10, 0.70], [0.90, 0.70], [0.90, 0.95], [0.10, 0.95],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          busZonePolygonXY: [
            [0.10, 0.50], [0.90, 0.50], [0.90, 0.95], [0.10, 0.95],
          ],
          maxCapacity: 45,
        ),
        lprAllowlist: ['12가3456', '34나5678'],
      );

      final back = roundTrip(original);

      expect(back.includeAnnotatedVideo, isFalse);
      expect(back.enabledTasks, original.enabledTasks);
      expect(back.trafficLightOverrides, hasLength(2));
      expect(back.trafficLightOverrides[0].label, 'main');
      expect(back.trafficLightOverrides[1].roi, [0.55, 0.05, 0.08, 0.12]);
      expect(back.speedOverride, isNotNull);
      expect(back.speedOverride!.realWorldLengthM, 20.0);
      expect(back.transitOverride, isNotNull);
      expect(back.transitOverride!.maxCapacity, 45);
      expect(back.transitOverride!.busZonePolygonXY, hasLength(4));
      expect(back.lprAllowlist, ['12가3456', '34나5678']);
    });

    test('transit without bus zone round-trips with null bus zone', () {
      const original = SiteCalibration(
        transitOverride: TransitOverride(
          stopPolygonXY: [
            [0.10, 0.70], [0.90, 0.70], [0.90, 0.95], [0.10, 0.95],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          maxCapacity: 30,
        ),
      );
      final back = roundTrip(original);
      expect(back.transitOverride, isNotNull);
      expect(back.transitOverride!.busZonePolygonXY, isNull);
    });

    test('malformed speed override (wrong quad length) is dropped', () {
      final json = {
        'speed_override': {
          'source_quad_xy': [[0.0, 0.0], [1.0, 1.0]], // only 2 points
          'lines_y_ratio': [0.5, 0.8],
          'real_world_width_m': 3.5,
          'real_world_length_m': 20.0,
        },
      };
      final cal = SiteCalibration.fromJson(json);
      expect(cal.speedOverride, isNull);
    });

    test('malformed transit override (polygon < 3) is dropped', () {
      final json = {
        'transit_override': {
          'stop_polygon_xy': [[0.0, 0.0], [1.0, 1.0]], // only 2 vertices
          'door_line_xy': [[0.0, 0.5], [1.0, 0.5]],
          'max_capacity': 30,
        },
      };
      final cal = SiteCalibration.fromJson(json);
      expect(cal.transitOverride, isNull);
    });

    test('pedestrian zone override round-trips with the polygon preserved', () {
      const original = SiteCalibration(
        pedestrianZoneOverride: PedestrianZoneOverride(
          polygonXY: [
            [0.10, 0.40], [0.90, 0.40],
            [0.90, 0.95], [0.10, 0.95],
          ],
        ),
      );
      final back = roundTrip(original);
      expect(back.pedestrianZoneOverride, isNotNull);
      expect(back.pedestrianZoneOverride!.polygonXY, hasLength(4));
      expect(back.pedestrianZoneOverride!.polygonXY[0], [0.10, 0.40]);
    });

    test('malformed pedestrian zone override (polygon < 3) is dropped', () {
      // Schema-level validation matches the server's parser — a 2-point
      // polygon is silently rejected so the rest of the calibration
      // still loads.
      final json = {
        'pedestrian_zone_override': {
          'polygon_xy': [[0.0, 0.0], [1.0, 1.0]],
        },
      };
      final cal = SiteCalibration.fromJson(json);
      expect(cal.pedestrianZoneOverride, isNull);
    });

    test('withoutPedestrianZone clears the override but keeps siblings', () {
      const cal = SiteCalibration(
        countLineOverride: CountLineOverride(
          inLineXY: [[0.0, 0.5], [1.0, 0.5]],
          outLineXY: [[0.0, 0.8], [1.0, 0.8]],
        ),
        pedestrianZoneOverride: PedestrianZoneOverride(
          polygonXY: [[0.1, 0.4], [0.9, 0.4], [0.9, 0.9]],
        ),
      );
      final cleared = cal.withoutPedestrianZone();
      expect(cleared.pedestrianZoneOverride, isNull);
      expect(cleared.countLineOverride, isNotNull);
    });

    test('forward-compat: unknown keys are ignored', () {
      final cal = SiteCalibration.fromJson({
        'schema_version': 99,
        'mystery_field': 'something',
        'enabled_tasks': ['vehicles'],
      });
      expect(cal.enabledTasks, {'vehicles'});
    });

    test('auto-mode flags default ON and round-trip', () {
      // Defaults: empty calibration is in auto mode for both transit
      // and traffic light, so first-time users get the VLM-driven UX.
      expect(SiteCalibration.empty.transitAutoMode, isTrue);
      expect(SiteCalibration.empty.lightAutoMode, isTrue);
      expect(SiteCalibration.empty.transitMaxCapacity, 30);

      const original = SiteCalibration(
        transitAutoMode: false,
        lightAutoMode: false,
        transitMaxCapacity: 75,
        lightAutoLabel: 'left_turn',
      );
      final back = roundTrip(original);
      expect(back.transitAutoMode, isFalse);
      expect(back.lightAutoMode, isFalse);
      expect(back.transitMaxCapacity, 75);
      expect(back.lightAutoLabel, 'left_turn');
    });

    test('schema_version=1 records back-fill auto-mode flags as ON', () {
      // Older mobile builds (schema_version=1) didn't write the
      // transit_auto_mode / light_auto_mode keys. Loading those on a
      // newer build should default them to ON so existing operators
      // get the auto-detect UX without a re-save.
      final cal = SiteCalibration.fromJson({
        'schema_version': 1,
        'enabled_tasks': ['vehicles', 'transit'],
      });
      expect(cal.transitAutoMode, isTrue);
      expect(cal.lightAutoMode, isTrue);
    });
  });

  group('FileSiteCalibrationStorage', () {
    late Directory tmpDir;
    late FileSiteCalibrationStorage storage;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('site_cal_test_');
      storage = FileSiteCalibrationStorage(rootOverride: tmpDir);
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    test('load returns null for unknown site', () async {
      expect(await storage.load('site-1'), isNull);
    });

    test('save then load returns equivalent calibration', () async {
      const original = SiteCalibration(
        enabledTasks: {AnalysisTask.vehicles, AnalysisTask.lpr},
        lprAllowlist: ['12가3456'],
      );
      await storage.save('site-1', original);
      final loaded = await storage.load('site-1');
      expect(loaded, isNotNull);
      expect(loaded!.lprAllowlist, ['12가3456']);
      expect(loaded.enabledTasks, contains(AnalysisTask.lpr));
    });

    test('clear removes the persisted file', () async {
      await storage.save('site-1', SiteCalibration.empty);
      await storage.clear('site-1');
      expect(await storage.load('site-1'), isNull);
    });

    test('siteId with path-traversal characters is sanitised', () async {
      // The crafted siteId should not escape the storage root.
      const evil = '../../../../etc/passwd';
      await storage.save(evil, SiteCalibration.empty);
      final files =
          tmpDir.listSync(recursive: true).whereType<File>().toList();
      // Every persisted file should still live under tmpDir.
      for (final f in files) {
        expect(f.path.startsWith(tmpDir.path), isTrue,
            reason: 'siteId leaked outside storage root: ${f.path}',);
      }
      // And the safe filename should not contain the evil prefix.
      expect(files.first.path, isNot(contains('..')));
    });

    test('atomic write — partial tmp file does not break load', () async {
      // Simulate a crash mid-write by leaving a stray .tmp file.
      final stray = File('${tmpDir.path}/site-1.json.tmp');
      await stray.writeAsString('{ corrupt');
      // load should still return null cleanly rather than throwing.
      expect(await storage.load('site-1'), isNull);
    });
  });

  group('toCalibrationJson', () {
    Map<String, dynamic> decode(String s) =>
        jsonDecode(s) as Map<String, dynamic>;

    test('forwards every override into the server-bound JSON', () {
      const cal = SiteCalibration(
        includeAnnotatedVideo: true,
        enabledTasks: {AnalysisTask.vehicles, AnalysisTask.lpr},
        lprAllowlist: ['12가3456'],
      );
      final json = decode(toCalibrationJson(cal));
      expect(json['tasks_enabled'], contains('lpr'));
      expect(
        (json['lpr'] as Map)['allowlist'],
        ['12가3456'],
      );
      expect(json['output_video'], isTrue);
    });
  });
}
