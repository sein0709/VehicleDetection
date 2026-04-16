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
  });
}
