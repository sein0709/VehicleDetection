import 'package:drift/drift.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/tables.dart';

part 'crossings_dao.g.dart';

@DriftAccessor(tables: [VehicleCrossings, AggVehicleCounts15m])
class CrossingsDao extends DatabaseAccessor<AppDatabase>
    with _$CrossingsDaoMixin {
  CrossingsDao(super.db);

  // --- Raw Crossings ---

  Future<int> insertCrossing(VehicleCrossingsCompanion entry) =>
      into(vehicleCrossings).insert(
        entry,
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> insertCrossingsBatch(
    List<VehicleCrossingsCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAll(
        vehicleCrossings,
        entries,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<List<VehicleCrossing>> crossingsForCamera(
    String cameraId, {
    DateTime? after,
    DateTime? before,
    int? limit,
  }) {
    final query = select(vehicleCrossings)
      ..where((t) {
        var expr = t.cameraId.equals(cameraId);
        if (after != null) {
          expr = expr & t.timestampUtc.isBiggerOrEqualValue(after);
        }
        if (before != null) {
          expr = expr & t.timestampUtc.isSmallerThanValue(before);
        }
        return expr;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.timestampUtc)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Stream<List<VehicleCrossing>> watchRecentCrossings(
    String cameraId, {
    int limit = 50,
  }) =>
      (select(vehicleCrossings)
            ..where((t) => t.cameraId.equals(cameraId))
            ..orderBy([(t) => OrderingTerm.desc(t.timestampUtc)])
            ..limit(limit))
          .watch();

  Future<int> crossingCountForCamera(
    String cameraId, {
    DateTime? after,
    DateTime? before,
  }) async {
    final count = vehicleCrossings.id.count();
    final query = selectOnly(vehicleCrossings)
      ..addColumns([count])
      ..where(vehicleCrossings.cameraId.equals(cameraId));
    if (after != null) {
      query.where(vehicleCrossings.timestampUtc.isBiggerOrEqualValue(after));
    }
    if (before != null) {
      query.where(vehicleCrossings.timestampUtc.isSmallerThanValue(before));
    }
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // --- Aggregated Counts ---

  Future<void> upsertAggBucket(AggVehicleCounts15mCompanion entry) =>
      into(aggVehicleCounts15m).insert(
        entry,
        mode: InsertMode.insertOrReplace,
      );

  Future<List<AggVehicleCount15m>> aggregatesForCamera(
    String cameraId, {
    required DateTime from,
    required DateTime to,
    String? lineId,
  }) {
    final query = select(aggVehicleCounts15m)
      ..where((t) {
        var expr = t.cameraId.equals(cameraId) &
            t.bucketStart.isBiggerOrEqualValue(from) &
            t.bucketStart.isSmallerThanValue(to);
        if (lineId != null) {
          expr = expr & t.lineId.equals(lineId);
        }
        return expr;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.bucketStart)]);
    return query.get();
  }

  Stream<List<AggVehicleCount15m>> watchAggregatesForCamera(
    String cameraId, {
    required DateTime from,
    required DateTime to,
  }) =>
      (select(aggVehicleCounts15m)
            ..where(
              (t) =>
                  t.cameraId.equals(cameraId) &
                  t.bucketStart.isBiggerOrEqualValue(from) &
                  t.bucketStart.isSmallerThanValue(to),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.bucketStart)]))
          .watch();

  /// Rebuild 15-minute aggregate buckets from raw crossings for a time range.
  Future<void> reaggregate(
    String cameraId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final crossings = await crossingsForCamera(cameraId, after: from, before: to);

    final buckets = <(String, DateTime, int, String), AggVehicleCounts15mCompanion>{};

    for (final c in crossings) {
      final bucketStart = _truncateTo15Min(c.timestampUtc);
      final key = (c.lineId, bucketStart, c.class12, c.direction);

      if (buckets.containsKey(key)) {
        final existing = buckets[key]!;
        final newCount = (existing.count.value) + 1;
        final newSumConf = (existing.sumConfidence.value) + c.confidence;
        final speed = c.speedEstimateKmh;
        final newSumSpeed =
            (existing.sumSpeedKmh.value) + (speed ?? 0.0);
        final newMin = speed != null
            ? (existing.minSpeedKmh.value != null
                ? (speed < existing.minSpeedKmh.value! ? speed : existing.minSpeedKmh.value!)
                : speed)
            : existing.minSpeedKmh.value;
        final newMax = speed != null
            ? (existing.maxSpeedKmh.value != null
                ? (speed > existing.maxSpeedKmh.value! ? speed : existing.maxSpeedKmh.value!)
                : speed)
            : existing.maxSpeedKmh.value;

        buckets[key] = AggVehicleCounts15mCompanion(
          id: existing.id,
          cameraId: existing.cameraId,
          lineId: existing.lineId,
          bucketStart: existing.bucketStart,
          class12: existing.class12,
          direction: existing.direction,
          count: Value(newCount),
          sumConfidence: Value(newSumConf),
          sumSpeedKmh: Value(newSumSpeed),
          minSpeedKmh: Value(newMin),
          maxSpeedKmh: Value(newMax),
          lastUpdatedAt: Value(DateTime.now()),
        );
      } else {
        buckets[key] = AggVehicleCounts15mCompanion(
          id: Value('${c.cameraId}_${c.lineId}_${bucketStart.millisecondsSinceEpoch}_${c.class12}_${c.direction}'),
          cameraId: Value(c.cameraId),
          lineId: Value(c.lineId),
          bucketStart: Value(bucketStart),
          class12: Value(c.class12),
          direction: Value(c.direction),
          count: const Value(1),
          sumConfidence: Value(c.confidence),
          sumSpeedKmh: Value(c.speedEstimateKmh ?? 0.0),
          minSpeedKmh: Value(c.speedEstimateKmh),
          maxSpeedKmh: Value(c.speedEstimateKmh),
          lastUpdatedAt: Value(DateTime.now()),
        );
      }
    }

    await batch((b) {
      for (final entry in buckets.values) {
        b.insert(aggVehicleCounts15m, entry, mode: InsertMode.insertOrReplace);
      }
    });
  }

  static DateTime _truncateTo15Min(DateTime dt) {
    final minute = (dt.minute ~/ 15) * 15;
    return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, minute);
  }
}
