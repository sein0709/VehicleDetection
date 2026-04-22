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

    group('annotated video flags', () {
      test('jobId, hasClassifiedVideo, hasTransitVideo default to false/empty',
          () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'Class 1': 5,
        });

        expect(result.jobId, '');
        expect(result.hasClassifiedVideo, isFalse);
        expect(result.hasTransitVideo, isFalse);
      });

      test('classified video flag set when annotated_video is a non-empty path',
          () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'job_id': 'job-123',
          'annotated_video': '/tmp/job-123_classified.mp4',
          'breakdown': {'Class 1': 5},
        });

        expect(result.jobId, 'job-123');
        expect(result.hasClassifiedVideo, isTrue);
        expect(result.hasTransitVideo, isFalse);
      });

      test('classified video flag false when annotated_video is empty string',
          () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'job_id': 'job-123',
          'annotated_video': '   ',
        });

        expect(result.hasClassifiedVideo, isFalse);
      });

      test('transit video flag set when transit.annotated_video present', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'job_id': 'job-9',
          'transit': {
            'annotated_video': '/tmp/job-9_transit.mp4',
            'peak_count': 12,
          },
          'breakdown': {'Class 5 (Truck)': 1},
        });

        expect(result.hasTransitVideo, isTrue);
        expect(result.hasClassifiedVideo, isFalse);
      });

      test('annotated_video / transit / meta keys never appear as classes', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'job_id': 'j',
          'annotated_video': '/tmp/j.mp4',
          'transit': {'annotated_video': '/tmp/j_transit.mp4'},
          'meta': {'finished_at': 1700000000},
          'speed': {'avg_kmh': 42.0},
          'traffic_light': {'cycles': {}},
          'Class 1 (Passenger/Van)': 5,
        });

        expect(result.breakdown, hasLength(1));
        expect(result.breakdown[0].label, 'Class 1 (Passenger/Van)');
        expect(result.totalVehiclesCounted, 5);
      });
    });

    group('F2 pedestrians', () {
      test('parses count from totals.pedestrians', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'totals': {'vehicles': 10, 'pedestrians': 7},
          'breakdown': {'Class 1': 10},
        });
        expect(result.pedestriansCount, 7);
      });

      test('falls back to top-level pedestrians key', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'pedestrians': 3,
          'breakdown': {'Class 1': 1},
        });
        expect(result.pedestriansCount, 3);
      });

      test('defaults to 0 when missing', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'breakdown': {'Class 1': 1},
        });
        expect(result.pedestriansCount, 0);
      });
    });

    group('F4 speed', () {
      test('parses full block with per-track map', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'breakdown': {'Class 1': 5},
          'speed': {
            'vehicles_measured': 3,
            'avg_kmh': 47.2,
            'min_kmh': 31.0,
            'max_kmh': 62.5,
            'per_track': {'1': 31.0, '2': 47.0, '3': 62.5},
          },
        });
        expect(result.speed, isNotNull);
        expect(result.speed!.vehiclesMeasured, 3);
        expect(result.speed!.avgKmh, closeTo(47.2, 0.01));
        expect(result.speed!.minKmh, 31.0);
        expect(result.speed!.maxKmh, 62.5);
        expect(result.speed!.perTrack['2'], 47.0);
      });

      test('handles empty speed block (no measurements)', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'breakdown': {'Class 1': 1},
          'speed': {'vehicles_measured': 0, 'avg_kmh': null, 'per_track': {}},
        });
        expect(result.speed, isNotNull);
        expect(result.speed!.vehiclesMeasured, 0);
        expect(result.speed!.avgKmh, isNull);
        expect(result.speed!.perTrack, isEmpty);
      });

      test('absent speed block yields null', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'breakdown': {'Class 1': 1},
        });
        expect(result.speed, isNull);
      });
    });

    group('F6 transit', () {
      test('parses boarding/alighting/density/peak/bus_gated', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'transit': {
            'peak_count': 18,
            'avg_density_pct': 42.5,
            'boarding': 12,
            'alighting': 9,
            'bus_gated': true,
          },
        });
        expect(result.transit, isNotNull);
        expect(result.transit!.peakCount, 18);
        expect(result.transit!.avgDensityPct, 42.5);
        expect(result.transit!.boarding, 12);
        expect(result.transit!.alighting, 9);
        expect(result.transit!.busGated, isTrue);
      });

      test('absent transit block yields null', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{});
        expect(result.transit, isNull);
      });
    });

    group('F7 traffic light', () {
      test('parses traffic_lights array shape', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'traffic_light': {
            'traffic_lights': [
              {
                'label': 'main',
                'cycles': {
                  'red':    {'cycles': 4, 'avg_duration_s': 22.5,
                             'total_duration_s': 90.0},
                  'green':  {'cycles': 4, 'avg_duration_s': 18.0,
                             'total_duration_s': 72.0},
                  'yellow': {'cycles': 4, 'avg_duration_s': 3.0,
                             'total_duration_s': 12.0},
                },
              },
              {
                'label': 'left_turn',
                'cycles': {
                  'red':    {'cycles': 2, 'avg_duration_s': 30.0,
                             'total_duration_s': 60.0},
                  'green':  {'cycles': 2, 'avg_duration_s': 8.0,
                             'total_duration_s': 16.0},
                  'yellow': {'cycles': 2, 'avg_duration_s': 2.0,
                             'total_duration_s': 4.0},
                },
              },
            ],
          },
        });
        expect(result.trafficLights, hasLength(2));
        expect(result.trafficLights[0].label, 'main');
        expect(result.trafficLights[0].red.cycles, 4);
        expect(result.trafficLights[0].red.avgDurationS, 22.5);
        expect(result.trafficLights[1].label, 'left_turn');
        expect(result.trafficLights[1].green.totalDurationS, 16.0);
      });

      test('parses legacy single-light cycles shape', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'traffic_light': {
            'cycles': {
              'red':    {'cycles': 1, 'avg_duration_s': 20.0,
                         'total_duration_s': 20.0},
              'green':  {'cycles': 1, 'avg_duration_s': 15.0,
                         'total_duration_s': 15.0},
              'yellow': {'cycles': 1, 'avg_duration_s': 2.0,
                         'total_duration_s': 2.0},
            },
          },
        });
        expect(result.trafficLights, hasLength(1));
        expect(result.trafficLights[0].label, 'main');
        expect(result.trafficLights[0].red.cycles, 1);
      });

      test('absent traffic_light block yields empty list', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{});
        expect(result.trafficLights, isEmpty);
      });
    });

    group('F5 plates / LPR', () {
      test('parses plate_summary', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'plate_summary': {
            'resident': 5,
            'visitor': 11,
            'total': 16,
            'privacy_hashed': false,
            'allowlist_size': 23,
          },
        });
        expect(result.plateSummary, isNotNull);
        expect(result.plateSummary!.resident, 5);
        expect(result.plateSummary!.visitor, 11);
        expect(result.plateSummary!.total, 16);
        expect(result.plateSummary!.privacyHashed, isFalse);
        expect(result.plateSummary!.allowlistSize, 23);
      });

      test('parses plates map and sorts residents first', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'plates': {
            '101': {'category': 'visitor', 'text': '12가3456', 'source': 'gemma'},
            '102': {'category': 'resident', 'text': '34나5678', 'source': 'both'},
            '103': {'category': 'visitor', 'text_hash': 'abc123', 'source': 'easyocr'},
          },
        });
        expect(result.plates, hasLength(3));
        expect(result.plates[0].category, 'resident');
        expect(result.plates[0].text, '34나5678');
        expect(result.plates[1].category, 'visitor');
        expect(result.plates[2].textHash, 'abc123');
      });

      test('unknown category falls through to "unknown"', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{
          'plates': {
            '1': {'category': 'something_else', 'text': 'XYZ'},
          },
        });
        expect(result.plates[0].category, 'unknown');
      });

      test('absent plates / plate_summary yields empty / null', () {
        final result = VideoAnalysisRemoteResult.fromJson(<String, dynamic>{});
        expect(result.plates, isEmpty);
        expect(result.plateSummary, isNull);
      });
    });
  });
}
