import 'package:drift/drift.dart';

class Sites extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get address => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get timezone =>
      text().withDefault(const Constant('Asia/Seoul'))();
  TextColumn get status =>
      text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (status IN ('active', 'archived'))",
      ];
}

class Cameras extends Table {
  TextColumn get id => text()();
  TextColumn get siteId => text().references(Sites, #id)();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get sourceType =>
      text().withDefault(const Constant('smartphone'))();
  TextColumn get settingsJson => text().withDefault(
        const Constant(
          '{"target_fps":10,"resolution":"1920x1080",'
          '"night_mode":false,"classification_mode":"full_12class"}',
        ),
      )();
  TextColumn get status =>
      text().withDefault(const Constant('offline'))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (source_type IN ('smartphone', 'rtsp', 'onvif'))",
        "CHECK (status IN ('online', 'degraded', 'offline', 'archived'))",
      ];
}

class RoiPresets extends Table {
  TextColumn get id => text()();
  TextColumn get cameraId => text().references(Cameras, #id)();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get roiPolygonJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get lanePolylinesJson =>
      text().withDefault(const Constant('[]'))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CountingLines extends Table {
  TextColumn get id => text()();
  TextColumn get presetId => text().references(RoiPresets, #id)();
  TextColumn get cameraId => text().references(Cameras, #id)();
  TextColumn get name => text().withLength(min: 1)();
  RealColumn get startX => real()();
  RealColumn get startY => real()();
  RealColumn get endX => real()();
  RealColumn get endY => real()();
  TextColumn get direction =>
      text().withDefault(const Constant('inbound'))();
  TextColumn get directionVectorJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        "CHECK (direction IN ('inbound', 'outbound', 'bidirectional'))",
      ];
}

class VehicleCrossings extends Table {
  TextColumn get id => text()();
  TextColumn get cameraId => text().references(Cameras, #id)();
  TextColumn get lineId => text().references(CountingLines, #id)();
  TextColumn get trackId => text()();
  IntColumn get crossingSeq =>
      integer().withDefault(const Constant(1))();
  IntColumn get class12 => integer()();
  RealColumn get confidence => real()();
  TextColumn get direction => text()();
  IntColumn get frameIndex => integer()();
  RealColumn get speedEstimateKmh => real().nullable()();
  TextColumn get bboxJson => text().nullable()();
  DateTimeColumn get timestampUtc => dateTime()();
  DateTimeColumn get ingestedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {cameraId, lineId, trackId, crossingSeq},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (class12 BETWEEN 1 AND 12)',
        "CHECK (direction IN ('inbound', 'outbound'))",
      ];
}

@DataClassName('AggVehicleCount15m')
class AggVehicleCounts15m extends Table {
  TextColumn get id => text()();
  TextColumn get cameraId => text().references(Cameras, #id)();
  TextColumn get lineId => text().references(CountingLines, #id)();
  DateTimeColumn get bucketStart => dateTime()();
  IntColumn get class12 => integer()();
  TextColumn get direction => text()();
  IntColumn get count =>
      integer().withDefault(const Constant(0))();
  RealColumn get sumConfidence =>
      real().withDefault(const Constant(0.0))();
  RealColumn get sumSpeedKmh =>
      real().withDefault(const Constant(0.0))();
  RealColumn get minSpeedKmh => real().nullable()();
  RealColumn get maxSpeedKmh => real().nullable()();
  DateTimeColumn get lastUpdatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {cameraId, lineId, bucketStart, class12, direction},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (class12 BETWEEN 1 AND 12)',
        "CHECK (direction IN ('inbound', 'outbound'))",
      ];
}
