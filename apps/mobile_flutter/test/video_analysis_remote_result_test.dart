import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/models/video_analysis_remote_result.dart';

void main() {
  group('VideoAnalysisRemoteResult.fromJson', () {
    group('flat map (RunPod sample response)', () {
      test('parses class→count entries and sums total', () {
        final json = <String, dynamic>{
          'Class 1 (Passenger/Van)': 119,
          'Class 2 (SUV/Pickup)': 45,
          'Class 3 (Bus)': 7,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 171);
        expect(result.breakdown, hasLength(3));
        expect(result.breakdown[0].label, 'Class 1 (Passenger/Van)');
        expect(result.breakdown[0].count, 119);
        expect(result.breakdown[1].label, 'Class 2 (SUV/Pickup)');
        expect(result.breakdown[1].count, 45);
        expect(result.breakdown[2].label, 'Class 3 (Bus)');
        expect(result.breakdown[2].count, 7);
      });

      test('uses explicit total_vehicles_counted when present', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 200,
          'Class 1 (Passenger/Van)': 119,
          'Class 2 (SUV/Pickup)': 45,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 200);
        expect(result.breakdown, hasLength(2));
      });

      test('skips metadata keys', () {
        final json = <String, dynamic>{
          'status': 'ok',
          'message': 'done',
          'request_id': 'abc-123',
          'Class 5 (Truck)': 30,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 30);
        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Class 5 (Truck)');
      });

      test('skips non-numeric values', () {
        final json = <String, dynamic>{
          'Class 1': 10,
          'Class 2': 'not-a-number',
          'Class 3': null,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 10);
        expect(result.breakdown, hasLength(1));
      });

      test('skips negative values', () {
        final json = <String, dynamic>{
          'Class 1': 10,
          'Class 2': -5,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.breakdown, hasLength(1));
        expect(result.totalVehiclesCounted, 10);
      });
    });

    group('structured breakdown (map)', () {
      test('parses breakdown map and uses explicit total', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 50,
          'breakdown': {
            'Sedan': 30,
            'Truck': 20,
          },
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 50);
        expect(result.breakdown, hasLength(2));
        expect(result.breakdown[0].label, 'Sedan');
        expect(result.breakdown[0].count, 30);
        expect(result.breakdown[1].label, 'Truck');
        expect(result.breakdown[1].count, 20);
      });

      test('sums breakdown map when total is missing', () {
        final json = <String, dynamic>{
          'breakdown': {
            'Sedan': 30,
            'Truck': 20,
          },
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 50);
      });
    });

    group('structured breakdown (list of objects)', () {
      test('parses list with label/count keys', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 75,
          'breakdown': [
            {'label': 'Bus', 'count': 25},
            {'label': 'Car', 'count': 50},
          ],
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 75);
        expect(result.breakdown, hasLength(2));
        expect(result.breakdown[0].label, 'Car');
        expect(result.breakdown[0].count, 50);
        expect(result.breakdown[1].label, 'Bus');
        expect(result.breakdown[1].count, 25);
      });

      test('accepts alternative key names (name, value)', () {
        final json = <String, dynamic>{
          'breakdown': [
            {'name': 'Motorcycle', 'value': 12},
            {'name': 'Van', 'value': 8},
          ],
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 20);
        expect(result.breakdown[0].label, 'Motorcycle');
        expect(result.breakdown[0].count, 12);
      });

      test('skips list entries missing label or count', () {
        final json = <String, dynamic>{
          'breakdown': [
            {'label': 'Car', 'count': 10},
            {'count': 5},
            {'label': 'Truck'},
            {'unrelated': 'data'},
          ],
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Car');
      });
    });

    group('sorting', () {
      test('sorts by count descending, ties by label ascending', () {
        final json = <String, dynamic>{
          'Zebra': 10,
          'Alpha': 10,
          'Middle': 5,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.breakdown[0].label, 'Alpha');
        expect(result.breakdown[1].label, 'Zebra');
        expect(result.breakdown[2].label, 'Middle');
      });
    });

    group('edge cases', () {
      test('empty JSON produces zero total and empty breakdown', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{});

        expect(result.totalVehiclesCounted, 0);
        expect(result.breakdown, isEmpty);
      });

      test('double values are rounded to int', () {
        final json = <String, dynamic>{
          'Class A': 10.6,
          'Class B': 3.2,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.breakdown[0].count, 11);
        expect(result.breakdown[1].count, 3);
        expect(result.totalVehiclesCounted, 14);
      });

      test('total_vehicles_counted as double is accepted', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 99.0,
          'Car': 99,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 99);
      });

      test('only metadata keys produces zero total', () {
        final json = <String, dynamic>{
          'status': 'ok',
          'message': 'analysis complete',
          'timestamp': '2026-04-16T00:00:00Z',
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 0);
        expect(result.breakdown, isEmpty);
      });
    });

    group('two-wheeler breakdown', () {
      test('parses two_wheeler_breakdown when present', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 10,
          'breakdown': {'Class 1 (Passenger/Van)': 10},
          'two_wheeler_breakdown': {
            'Bicycle': 3,
            'Motorcycle': 5,
            'Personal Mobility': 2,
          },
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.twoWheelerBreakdown, hasLength(3));
        // Sorted by count desc; ties by label asc
        expect(result.twoWheelerBreakdown[0].label, 'Motorcycle');
        expect(result.twoWheelerBreakdown[0].count, 5);
        expect(result.twoWheelerBreakdown[1].label, 'Bicycle');
        expect(result.twoWheelerBreakdown[1].count, 3);
        expect(result.twoWheelerBreakdown[2].label, 'Personal Mobility');
        expect(result.twoWheelerBreakdown[2].count, 2);

        // Vehicle breakdown is unaffected
        expect(result.totalVehiclesCounted, 10);
        expect(result.breakdown, hasLength(1));
      });

      test('absent two_wheeler_breakdown yields empty list', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 10,
          'breakdown': {'Class 1 (Passenger/Van)': 10},
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.twoWheelerBreakdown, isEmpty);
        expect(result.totalVehiclesCounted, 10);
      });

      test('two_wheeler_breakdown does not leak into vehicle breakdown', () {
        // Regression guard: the vehicle breakdown must not pick up 2-wheeler
        // keys by accident if someone flattens the response.
        final json = <String, dynamic>{
          'total_vehicles_counted': 10,
          'breakdown': {'Class 1 (Passenger/Van)': 10},
          'two_wheeler_breakdown': {'Bicycle': 3, 'Motorcycle': 5},
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        final labels = result.breakdown.map((e) => e.label).toList();
        expect(labels, everyElement(startsWith('Class ')));
        expect(labels.contains('Bicycle'), isFalse);
        expect(labels.contains('Motorcycle'), isFalse);
      });

      test('empty two_wheeler_breakdown map yields empty list', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 10,
          'breakdown': {'Class 1': 10},
          'two_wheeler_breakdown': <String, int>{},
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);
        expect(result.twoWheelerBreakdown, isEmpty);
      });
    });

    group('defensive filtering (regressions)', () {
      // Reproduces the 2026-04-20 incident: the backend returned
      // {"finished_at": 1776681446.123, ...} and the mobile UI displayed
      // "1,776,681,446 vehicles" because finished_at was treated as a class.
      test('finished_at is excluded from flat-map breakdown', () {
        final json = <String, dynamic>{
          'status': 'success',
          'job_id': 'abc',
          'finished_at': 1776681446.123,
          'Class 1 (Passenger/Van)': 5,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 5);
        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Class 1 (Passenger/Van)');
        expect(
          result.breakdown.any((e) => e.label == 'finished_at'),
          isFalse,
          reason: 'finished_at must never appear as a vehicle class',
        );
      });

      test('all temporal-suffix keys are excluded from flat-map breakdown', () {
        final json = <String, dynamic>{
          'created_at': 1700000000,
          'updated_at': 1700000001,
          'started_at': 1700000002,
          'processed_at': 1700000003,
          'duration_ms': 5000,
          'capture_time': 1700000004,
          'render_timestamp': 1700000005,
          'gpu_ns': 1234567890,
          'frame_us': 1234,
          'data_epoch': 1700000006,
          'Class 5 (Truck)': 30,
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 30);
        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Class 5 (Truck)');
      });

      test('per-class count above sanity ceiling is dropped', () {
        // Even if a future field name slips past the suffix filter, any
        // value above the ceiling is implausible for a 5-min video and
        // is treated as a leaked timestamp / monotonic counter.
        final json = <String, dynamic>{
          'Class 1': 10,
          'OddField': 1776681446,  // looks like an epoch timestamp
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 10);
        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Class 1');
      });

      test('absurd explicit total is rejected, falls back to breakdown sum', () {
        final json = <String, dynamic>{
          'total_vehicles_counted': 1776681446,
          'breakdown': {
            'Class 1': 5,
            'Class 2': 3,
          },
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        expect(result.totalVehiclesCounted, 8);
        expect(result.breakdown, hasLength(2));
      });

      test('exact incident response shape renders correct counts', () {
        // Verbatim shape produced by the broken server.py before the
        // server-side fix — mobile parser must still recover.
        final json = <String, dynamic>{
          'status': 'success',
          'job_id': 'abc-123',
          'finished_at': 1776681446.123,
          'totals': {
            'vehicles': 12,
            'pedestrians': 3,
            'bicycles': 0,
            'motorcycles': 1,
          },
          'vehicle_breakdown': {
            'Class 1 (Passenger/Van)': 7,
            'Class 2 (Bus)': 2,
            'Class 6 (4-Axle Truck)': 3,
          },
          'meta': {
            'frames_total': 9000,
            'frames_sampled': 3000,
            'fps': 30.0,
            'elapsed_s': 425.1,
          },
        };

        final result = VideoAnalysisRemoteResult.fromJson(json);

        // No `breakdown` key in this shape, so flat-map fallback runs.
        // The nested totals/vehicle_breakdown/meta values are non-numeric
        // (Maps), so _coerceNonNegativeInt rejects them. finished_at is
        // explicitly excluded. Result: empty breakdown, zero total.
        // (Server-side fix adds legacy `breakdown` + `total_vehicles_counted`
        // aliases so the structured path runs instead — this test pins the
        // graceful-degradation behaviour for the pre-fix shape.)
        expect(result.totalVehiclesCounted, 0);
        expect(result.breakdown, isEmpty);
        expect(result.totalVehiclesCounted, lessThan(1000000),
            reason: 'finished_at must never leak into the displayed total');
      });
    });
  });
}
