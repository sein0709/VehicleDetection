import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/task_calibration_builder.dart';

void main() {
  group('buildCalibrationJson', () {
    Map<String, dynamic> decode(String json) =>
        jsonDecode(json) as Map<String, dynamic>;

    test('tasks_enabled mirrors operator selection exactly', () {
      // Vehicles used to be auto-injected; now it's only present when
      // the operator explicitly enabled it (so a bus-stop scenario can
      // run pedestrians + transit only).
      final empty = decode(buildCalibrationJson(
        enabledTasks: const {},
        outputAnnotatedVideo: false,
      ),);
      expect(empty['tasks_enabled'], isEmpty);

      final pedOnly = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.pedestrians},
        outputAnnotatedVideo: false,
      ),);
      expect(pedOnly['tasks_enabled'], ['pedestrians']);
    });

    test('bus stop scenario: transit + pedestrians, no vehicles', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {
          AnalysisTask.transit,
          AnalysisTask.pedestrians,
        },
        outputAnnotatedVideo: false,
      ),);
      expect(
        json['tasks_enabled'],
        containsAll(['transit', 'pedestrians']),
      );
      expect(json['tasks_enabled'], isNot(contains('vehicles')));
    });

    test('count_lines override emits in/out segment pair', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.vehicles},
        outputAnnotatedVideo: false,
        countLineOverride: const CountLineOverride(
          inLineXY: [[0.10, 0.40], [0.90, 0.45]],
          outLineXY: [[0.05, 0.80], [0.95, 0.85]],
        ),
      ),);
      final cl = json['count_lines'] as Map<String, dynamic>;
      expect(cl['in'], [[0.10, 0.40], [0.90, 0.45]]);
      expect(cl['out'], [[0.05, 0.80], [0.95, 0.85]]);
    });

    test('count_lines absent by default', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.vehicles},
        outputAnnotatedVideo: false,
      ),);
      expect(json.containsKey('count_lines'), isFalse);
    });

    test('pedestrian_zone override emits the polygon as ratios', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.pedestrians},
        outputAnnotatedVideo: false,
        pedestrianZoneOverride: const PedestrianZoneOverride(
          polygonXY: [
            [0.10, 0.40], [0.90, 0.40],
            [0.90, 0.95], [0.10, 0.95],
          ],
        ),
      ),);
      final pz = json['pedestrian_zone'] as Map<String, dynamic>;
      expect(pz['polygon'], [
        [0.10, 0.40], [0.90, 0.40],
        [0.90, 0.95], [0.10, 0.95],
      ],);
    });

    test('pedestrian_zone absent when no override is supplied', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.pedestrians},
        outputAnnotatedVideo: false,
      ),);
      expect(json.containsKey('pedestrian_zone'), isFalse);
    });

    test('pedestrian_zone with fewer than 3 vertices is dropped silently', () {
      // Mirrors the server-side parser: a 2-vertex polygon is invalid
      // and should not be sent.
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.pedestrians},
        outputAnnotatedVideo: false,
        pedestrianZoneOverride: const PedestrianZoneOverride(
          polygonXY: [[0.10, 0.40], [0.90, 0.40]],
        ),
      ),);
      expect(json.containsKey('pedestrian_zone'), isFalse);
    });

    test('speed override forwards arbitrary lines_xy when present', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: const {AnalysisTask.speed},
        outputAnnotatedVideo: false,
        speedOverride: const SpeedOverride(
          sourceQuadXY: [
            [0.10, 0.20], [0.90, 0.20], [0.95, 0.95], [0.05, 0.95],
          ],
          linesYRatio: [0.40, 0.85],
          realWorldWidthM: 3.2,
          realWorldLengthM: 18.0,
          linesXY: [
            [[0.10, 0.40], [0.90, 0.42]],
            [[0.05, 0.85], [0.95, 0.86]],
          ],
        ),
      ),);
      final speed = json['speed'] as Map<String, dynamic>;
      expect(speed['lines_xy'], [
        [[0.10, 0.40], [0.90, 0.42]],
        [[0.05, 0.85], [0.95, 0.86]],
      ]);
    });

    test('output_video flag respected', () {
      final on = decode(buildCalibrationJson(
        enabledTasks: const {},
        outputAnnotatedVideo: true,
      ),);
      final off = decode(buildCalibrationJson(
        enabledTasks: const {},
        outputAnnotatedVideo: false,
      ),);
      expect(on['output_video'], isTrue);
      expect(off.containsKey('output_video'), isFalse);
    });

    test('speed task enables ratio-based source quad', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.speed},
        outputAnnotatedVideo: false,
      ),);
      expect(json['tasks_enabled'], contains('speed'));
      final speed = json['speed'] as Map<String, dynamic>;
      expect(speed['source_quad'] as List, hasLength(4));
      // Every coordinate should be a normalized ratio in [0,1].
      for (final pt in speed['source_quad'] as List<dynamic>) {
        for (final v in pt as List<dynamic>) {
          expect((v as num).toDouble(), inInclusiveRange(0.0, 1.0));
        }
      }
      expect(speed['lines_y_ratio'], hasLength(2));
      expect(speed['real_world_m'], isA<Map<String, dynamic>>());
    });

    test('transit task includes door line as ratios', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit},
        outputAnnotatedVideo: true,
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit['stop_polygon'] as List, hasLength(4));
      expect(transit['doors'] as List, hasLength(1));
      // output_video propagates through to transit when the parent
      // toggle is on, so the head-circle MP4 is also produced.
      expect(transit['output_video'], isTrue);
    });

    test('traffic_light task emits a single default light entry', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.trafficLight},
        outputAnnotatedVideo: false,
      ),);
      final lights = json['traffic_lights'] as List;
      expect(lights, hasLength(1));
      expect((lights[0] as Map)['label'], 'main');
      expect((lights[0] as Map)['roi'] as List, hasLength(4));
    });

    test('lpr task enables with empty allowlist', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.lpr},
        outputAnnotatedVideo: false,
      ),);
      final lpr = json['lpr'] as Map<String, dynamic>;
      expect(lpr['enabled'], isTrue);
      expect(lpr['residential_only'], isTrue);
      expect(lpr['allowlist'], isEmpty);
      expect(lpr['hash_plates'], isFalse);
    });

    test('traffic_light overrides replace the generic default', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.trafficLight},
        outputAnnotatedVideo: false,
        trafficLightOverrides: const [
          TrafficLightOverride(
            label: 'main',
            roi: [0.40, 0.10, 0.08, 0.10],
          ),
          TrafficLightOverride(
            label: 'left_turn',
            roi: [0.55, 0.10, 0.06, 0.10],
          ),
        ],
      ),);
      final lights = json['traffic_lights'] as List;
      expect(lights, hasLength(2));
      expect((lights[0] as Map)['label'], 'main');
      expect((lights[1] as Map)['label'], 'left_turn');
      expect((lights[0] as Map)['roi'], [0.40, 0.10, 0.08, 0.10]);
    });

    test('speed override replaces the generic default', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.speed},
        outputAnnotatedVideo: false,
        speedOverride: const SpeedOverride(
          sourceQuadXY: [
            [0.10, 0.20], [0.90, 0.20], [0.95, 0.95], [0.05, 0.95],
          ],
          linesYRatio: [0.40, 0.85],
          realWorldWidthM: 3.2,
          realWorldLengthM: 18.0,
        ),
      ),);
      final speed = json['speed'] as Map<String, dynamic>;
      expect(speed['source_quad'], [
        [0.10, 0.20], [0.90, 0.20], [0.95, 0.95], [0.05, 0.95],
      ]);
      expect(speed['lines_y_ratio'], [0.40, 0.85]);
      expect((speed['real_world_m'] as Map)['width'], 3.2);
      expect((speed['real_world_m'] as Map)['length'], 18.0);
    });

    test('transit override forwards polygon, door, capacity, bus zone',
        () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit},
        outputAnnotatedVideo: true,
        transitOverride: const TransitOverride(
          stopPolygonXY: [
            [0.05, 0.65], [0.95, 0.65], [0.95, 0.99], [0.05, 0.99],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          busZonePolygonXY: [
            [0.10, 0.50], [0.90, 0.50], [0.90, 0.95], [0.10, 0.95],
          ],
          maxCapacity: 45,
        ),
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit['max_capacity'], 45);
      expect((transit['stop_polygon'] as List), hasLength(4));
      expect(
        ((transit['doors'] as List)[0] as Map)['line'],
        [[0.20, 0.85], [0.80, 0.85]],
      );
      expect(transit['bus_zone_polygon'], hasLength(4));
      expect(transit['output_video'], isTrue);
    });

    test('transit override without bus zone omits the key', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit},
        outputAnnotatedVideo: false,
        transitOverride: const TransitOverride(
          stopPolygonXY: [
            [0.05, 0.65], [0.95, 0.65], [0.95, 0.99], [0.05, 0.99],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          maxCapacity: 30,
        ),
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit.containsKey('bus_zone_polygon'), isFalse);
    });

    test('lpr allowlist is forwarded into calibration', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.lpr},
        outputAnnotatedVideo: false,
        lprAllowlist: const ['12가3456', '34나5678'],
      ),);
      final lpr = json['lpr'] as Map<String, dynamic>;
      expect(lpr['allowlist'], ['12가3456', '34나5678']);
    });

    test('transitAutoMode omits geometry and ships only max_capacity', () {
      // Auto mode is the new default UX: the mobile app collects only
      // the bus capacity, and the server's auto-calibration pre-pass
      // asks the VLM for the polygons. Verifies the wire format.
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit},
        outputAnnotatedVideo: true,
        transitAutoMode: true,
        transitMaxCapacity: 42,
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit['max_capacity'], 42);
      expect(transit.containsKey('stop_polygon'), isFalse);
      expect(transit.containsKey('doors'), isFalse);
      expect(transit.containsKey('bus_zone_polygon'), isFalse);
      expect(transit['output_video'], isTrue);
    });

    test('transitAutoMode wins over a stale transit override', () {
      // The override is from a previous manual-mode session; auto mode
      // should still suppress it so the server runs the VLM pre-pass.
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit},
        outputAnnotatedVideo: false,
        transitAutoMode: true,
        transitMaxCapacity: 30,
        transitOverride: const TransitOverride(
          stopPolygonXY: [
            [0.05, 0.65], [0.95, 0.65], [0.95, 0.99], [0.05, 0.99],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          maxCapacity: 30,
        ),
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit.containsKey('stop_polygon'), isFalse);
    });

    test('lightAutoMode omits roi and ships only the label', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.trafficLight},
        outputAnnotatedVideo: false,
        lightAutoMode: true,
        lightAutoLabel: 'left_turn',
      ),);
      final lights = json['traffic_lights'] as List;
      expect(lights, hasLength(1));
      final entry = lights.first as Map<String, dynamic>;
      expect(entry['label'], 'left_turn');
      expect(entry.containsKey('roi'), isFalse);
    });

    test('manual mode (auto flags off) keeps the legacy editor payload', () {
      // Regression guard: manual-mode users with a populated override
      // must continue to ship the polygons exactly as before.
      final json = decode(buildCalibrationJson(
        enabledTasks: {AnalysisTask.transit, AnalysisTask.trafficLight},
        outputAnnotatedVideo: false,
        transitOverride: const TransitOverride(
          stopPolygonXY: [
            [0.05, 0.65], [0.95, 0.65], [0.95, 0.99], [0.05, 0.99],
          ],
          doorLineXY: [[0.20, 0.85], [0.80, 0.85]],
          maxCapacity: 50,
        ),
        trafficLightOverrides: const [
          TrafficLightOverride(
            label: 'main',
            roi: [0.40, 0.10, 0.08, 0.10],
          ),
        ],
      ),);
      final transit = json['transit'] as Map<String, dynamic>;
      expect(transit['max_capacity'], 50);
      expect(transit.containsKey('stop_polygon'), isTrue);
      final lights = json['traffic_lights'] as List;
      expect((lights[0] as Map)['roi'], [0.40, 0.10, 0.08, 0.10]);
    });

    test('all tasks together produce a complete payload', () {
      final json = decode(buildCalibrationJson(
        enabledTasks: {
          AnalysisTask.vehicles,
          AnalysisTask.pedestrians,
          AnalysisTask.speed,
          AnalysisTask.transit,
          AnalysisTask.trafficLight,
          AnalysisTask.lpr,
        },
        outputAnnotatedVideo: true,
      ),);
      expect(
        json['tasks_enabled'],
        containsAll([
          'vehicles', 'pedestrians', 'speed', 'transit',
          'traffic_light', 'lpr',
        ]),
      );
      expect(
        json.keys,
        containsAll([
          'speed', 'transit', 'traffic_lights', 'lpr', 'output_video',
        ]),
      );
    });
  });
}
