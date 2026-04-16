// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SitesTable extends Sites with TableInfo<$SitesTable, Site> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SitesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _timezoneMeta =
      const VerificationMeta('timezone');
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
      'timezone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Asia/Seoul'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        address,
        latitude,
        longitude,
        timezone,
        status,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sites';
  @override
  VerificationContext validateIntegrity(Insertable<Site> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('timezone')) {
      context.handle(_timezoneMeta,
          timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Site map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Site(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      timezone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timezone'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SitesTable createAlias(String alias) {
    return $SitesTable(attachedDatabase, alias);
  }
}

class Site extends DataClass implements Insertable<Site> {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String timezone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Site(
      {required this.id,
      required this.name,
      this.address,
      this.latitude,
      this.longitude,
      required this.timezone,
      required this.status,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['timezone'] = Variable<String>(timezone);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SitesCompanion toCompanion(bool nullToAbsent) {
    return SitesCompanion(
      id: Value(id),
      name: Value(name),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      timezone: Value(timezone),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Site.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Site(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      address: serializer.fromJson<String?>(json['address']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      timezone: serializer.fromJson<String>(json['timezone']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'address': serializer.toJson<String?>(address),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'timezone': serializer.toJson<String>(timezone),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Site copyWith(
          {String? id,
          String? name,
          Value<String?> address = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          String? timezone,
          String? status,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Site(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address.present ? address.value : this.address,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        timezone: timezone ?? this.timezone,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Site copyWithCompanion(SitesCompanion data) {
    return Site(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      address: data.address.present ? data.address.value : this.address,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Site(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timezone: $timezone, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, address, latitude, longitude,
      timezone, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Site &&
          other.id == this.id &&
          other.name == this.name &&
          other.address == this.address &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.timezone == this.timezone &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SitesCompanion extends UpdateCompanion<Site> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> address;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String> timezone;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SitesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.timezone = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SitesCompanion.insert({
    required String id,
    required String name,
    this.address = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.timezone = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Site> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? address,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? timezone,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (timezone != null) 'timezone': timezone,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SitesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? address,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String>? timezone,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SitesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SitesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('address: $address, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('timezone: $timezone, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CamerasTable extends Cameras with TableInfo<$CamerasTable, Camera> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CamerasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _siteIdMeta = const VerificationMeta('siteId');
  @override
  late final GeneratedColumn<String> siteId = GeneratedColumn<String>(
      'site_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sites (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _sourceTypeMeta =
      const VerificationMeta('sourceType');
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
      'source_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('smartphone'));
  static const VerificationMeta _settingsJsonMeta =
      const VerificationMeta('settingsJson');
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
      'settings_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{"target_fps":10,"resolution":"1920x1080",'
          '"night_mode":false,"classification_mode":"full_12class"}'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('offline'));
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        siteId,
        name,
        sourceType,
        settingsJson,
        status,
        lastSeenAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cameras';
  @override
  VerificationContext validateIntegrity(Insertable<Camera> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('site_id')) {
      context.handle(_siteIdMeta,
          siteId.isAcceptableOrUnknown(data['site_id']!, _siteIdMeta));
    } else if (isInserting) {
      context.missing(_siteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
          _sourceTypeMeta,
          sourceType.isAcceptableOrUnknown(
              data['source_type']!, _sourceTypeMeta));
    }
    if (data.containsKey('settings_json')) {
      context.handle(
          _settingsJsonMeta,
          settingsJson.isAcceptableOrUnknown(
              data['settings_json']!, _settingsJsonMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Camera map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Camera(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      siteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}site_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_type'])!,
      settingsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}settings_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CamerasTable createAlias(String alias) {
    return $CamerasTable(attachedDatabase, alias);
  }
}

class Camera extends DataClass implements Insertable<Camera> {
  final String id;
  final String siteId;
  final String name;
  final String sourceType;
  final String settingsJson;
  final String status;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Camera(
      {required this.id,
      required this.siteId,
      required this.name,
      required this.sourceType,
      required this.settingsJson,
      required this.status,
      this.lastSeenAt,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['site_id'] = Variable<String>(siteId);
    map['name'] = Variable<String>(name);
    map['source_type'] = Variable<String>(sourceType);
    map['settings_json'] = Variable<String>(settingsJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CamerasCompanion toCompanion(bool nullToAbsent) {
    return CamerasCompanion(
      id: Value(id),
      siteId: Value(siteId),
      name: Value(name),
      sourceType: Value(sourceType),
      settingsJson: Value(settingsJson),
      status: Value(status),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Camera.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Camera(
      id: serializer.fromJson<String>(json['id']),
      siteId: serializer.fromJson<String>(json['siteId']),
      name: serializer.fromJson<String>(json['name']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
      status: serializer.fromJson<String>(json['status']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'siteId': serializer.toJson<String>(siteId),
      'name': serializer.toJson<String>(name),
      'sourceType': serializer.toJson<String>(sourceType),
      'settingsJson': serializer.toJson<String>(settingsJson),
      'status': serializer.toJson<String>(status),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Camera copyWith(
          {String? id,
          String? siteId,
          String? name,
          String? sourceType,
          String? settingsJson,
          String? status,
          Value<DateTime?> lastSeenAt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Camera(
        id: id ?? this.id,
        siteId: siteId ?? this.siteId,
        name: name ?? this.name,
        sourceType: sourceType ?? this.sourceType,
        settingsJson: settingsJson ?? this.settingsJson,
        status: status ?? this.status,
        lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Camera copyWithCompanion(CamerasCompanion data) {
    return Camera(
      id: data.id.present ? data.id.value : this.id,
      siteId: data.siteId.present ? data.siteId.value : this.siteId,
      name: data.name.present ? data.name.value : this.name,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      status: data.status.present ? data.status.value : this.status,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Camera(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('name: $name, ')
          ..write('sourceType: $sourceType, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('status: $status, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, siteId, name, sourceType, settingsJson,
      status, lastSeenAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Camera &&
          other.id == this.id &&
          other.siteId == this.siteId &&
          other.name == this.name &&
          other.sourceType == this.sourceType &&
          other.settingsJson == this.settingsJson &&
          other.status == this.status &&
          other.lastSeenAt == this.lastSeenAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CamerasCompanion extends UpdateCompanion<Camera> {
  final Value<String> id;
  final Value<String> siteId;
  final Value<String> name;
  final Value<String> sourceType;
  final Value<String> settingsJson;
  final Value<String> status;
  final Value<DateTime?> lastSeenAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CamerasCompanion({
    this.id = const Value.absent(),
    this.siteId = const Value.absent(),
    this.name = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CamerasCompanion.insert({
    required String id,
    required String siteId,
    required String name,
    this.sourceType = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        siteId = Value(siteId),
        name = Value(name);
  static Insertable<Camera> custom({
    Expression<String>? id,
    Expression<String>? siteId,
    Expression<String>? name,
    Expression<String>? sourceType,
    Expression<String>? settingsJson,
    Expression<String>? status,
    Expression<DateTime>? lastSeenAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (siteId != null) 'site_id': siteId,
      if (name != null) 'name': name,
      if (sourceType != null) 'source_type': sourceType,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (status != null) 'status': status,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CamerasCompanion copyWith(
      {Value<String>? id,
      Value<String>? siteId,
      Value<String>? name,
      Value<String>? sourceType,
      Value<String>? settingsJson,
      Value<String>? status,
      Value<DateTime?>? lastSeenAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CamerasCompanion(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      settingsJson: settingsJson ?? this.settingsJson,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (siteId.present) {
      map['site_id'] = Variable<String>(siteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CamerasCompanion(')
          ..write('id: $id, ')
          ..write('siteId: $siteId, ')
          ..write('name: $name, ')
          ..write('sourceType: $sourceType, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('status: $status, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoiPresetsTable extends RoiPresets
    with TableInfo<$RoiPresetsTable, RoiPreset> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoiPresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES cameras (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _roiPolygonJsonMeta =
      const VerificationMeta('roiPolygonJson');
  @override
  late final GeneratedColumn<String> roiPolygonJson = GeneratedColumn<String>(
      'roi_polygon_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _lanePolylinesJsonMeta =
      const VerificationMeta('lanePolylinesJson');
  @override
  late final GeneratedColumn<String> lanePolylinesJson =
      GeneratedColumn<String>('lane_polylines_json', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        cameraId,
        name,
        roiPolygonJson,
        lanePolylinesJson,
        isActive,
        version,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roi_presets';
  @override
  VerificationContext validateIntegrity(Insertable<RoiPreset> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('roi_polygon_json')) {
      context.handle(
          _roiPolygonJsonMeta,
          roiPolygonJson.isAcceptableOrUnknown(
              data['roi_polygon_json']!, _roiPolygonJsonMeta));
    }
    if (data.containsKey('lane_polylines_json')) {
      context.handle(
          _lanePolylinesJsonMeta,
          lanePolylinesJson.isAcceptableOrUnknown(
              data['lane_polylines_json']!, _lanePolylinesJsonMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoiPreset map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoiPreset(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      roiPolygonJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}roi_polygon_json'])!,
      lanePolylinesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}lane_polylines_json'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RoiPresetsTable createAlias(String alias) {
    return $RoiPresetsTable(attachedDatabase, alias);
  }
}

class RoiPreset extends DataClass implements Insertable<RoiPreset> {
  final String id;
  final String cameraId;
  final String name;
  final String roiPolygonJson;
  final String lanePolylinesJson;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  const RoiPreset(
      {required this.id,
      required this.cameraId,
      required this.name,
      required this.roiPolygonJson,
      required this.lanePolylinesJson,
      required this.isActive,
      required this.version,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['camera_id'] = Variable<String>(cameraId);
    map['name'] = Variable<String>(name);
    map['roi_polygon_json'] = Variable<String>(roiPolygonJson);
    map['lane_polylines_json'] = Variable<String>(lanePolylinesJson);
    map['is_active'] = Variable<bool>(isActive);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoiPresetsCompanion toCompanion(bool nullToAbsent) {
    return RoiPresetsCompanion(
      id: Value(id),
      cameraId: Value(cameraId),
      name: Value(name),
      roiPolygonJson: Value(roiPolygonJson),
      lanePolylinesJson: Value(lanePolylinesJson),
      isActive: Value(isActive),
      version: Value(version),
      createdAt: Value(createdAt),
    );
  }

  factory RoiPreset.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoiPreset(
      id: serializer.fromJson<String>(json['id']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      name: serializer.fromJson<String>(json['name']),
      roiPolygonJson: serializer.fromJson<String>(json['roiPolygonJson']),
      lanePolylinesJson: serializer.fromJson<String>(json['lanePolylinesJson']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cameraId': serializer.toJson<String>(cameraId),
      'name': serializer.toJson<String>(name),
      'roiPolygonJson': serializer.toJson<String>(roiPolygonJson),
      'lanePolylinesJson': serializer.toJson<String>(lanePolylinesJson),
      'isActive': serializer.toJson<bool>(isActive),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RoiPreset copyWith(
          {String? id,
          String? cameraId,
          String? name,
          String? roiPolygonJson,
          String? lanePolylinesJson,
          bool? isActive,
          int? version,
          DateTime? createdAt}) =>
      RoiPreset(
        id: id ?? this.id,
        cameraId: cameraId ?? this.cameraId,
        name: name ?? this.name,
        roiPolygonJson: roiPolygonJson ?? this.roiPolygonJson,
        lanePolylinesJson: lanePolylinesJson ?? this.lanePolylinesJson,
        isActive: isActive ?? this.isActive,
        version: version ?? this.version,
        createdAt: createdAt ?? this.createdAt,
      );
  RoiPreset copyWithCompanion(RoiPresetsCompanion data) {
    return RoiPreset(
      id: data.id.present ? data.id.value : this.id,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      name: data.name.present ? data.name.value : this.name,
      roiPolygonJson: data.roiPolygonJson.present
          ? data.roiPolygonJson.value
          : this.roiPolygonJson,
      lanePolylinesJson: data.lanePolylinesJson.present
          ? data.lanePolylinesJson.value
          : this.lanePolylinesJson,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoiPreset(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('name: $name, ')
          ..write('roiPolygonJson: $roiPolygonJson, ')
          ..write('lanePolylinesJson: $lanePolylinesJson, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cameraId, name, roiPolygonJson,
      lanePolylinesJson, isActive, version, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoiPreset &&
          other.id == this.id &&
          other.cameraId == this.cameraId &&
          other.name == this.name &&
          other.roiPolygonJson == this.roiPolygonJson &&
          other.lanePolylinesJson == this.lanePolylinesJson &&
          other.isActive == this.isActive &&
          other.version == this.version &&
          other.createdAt == this.createdAt);
}

class RoiPresetsCompanion extends UpdateCompanion<RoiPreset> {
  final Value<String> id;
  final Value<String> cameraId;
  final Value<String> name;
  final Value<String> roiPolygonJson;
  final Value<String> lanePolylinesJson;
  final Value<bool> isActive;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RoiPresetsCompanion({
    this.id = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.name = const Value.absent(),
    this.roiPolygonJson = const Value.absent(),
    this.lanePolylinesJson = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoiPresetsCompanion.insert({
    required String id,
    required String cameraId,
    required String name,
    this.roiPolygonJson = const Value.absent(),
    this.lanePolylinesJson = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        cameraId = Value(cameraId),
        name = Value(name);
  static Insertable<RoiPreset> custom({
    Expression<String>? id,
    Expression<String>? cameraId,
    Expression<String>? name,
    Expression<String>? roiPolygonJson,
    Expression<String>? lanePolylinesJson,
    Expression<bool>? isActive,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cameraId != null) 'camera_id': cameraId,
      if (name != null) 'name': name,
      if (roiPolygonJson != null) 'roi_polygon_json': roiPolygonJson,
      if (lanePolylinesJson != null) 'lane_polylines_json': lanePolylinesJson,
      if (isActive != null) 'is_active': isActive,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoiPresetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? cameraId,
      Value<String>? name,
      Value<String>? roiPolygonJson,
      Value<String>? lanePolylinesJson,
      Value<bool>? isActive,
      Value<int>? version,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return RoiPresetsCompanion(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      name: name ?? this.name,
      roiPolygonJson: roiPolygonJson ?? this.roiPolygonJson,
      lanePolylinesJson: lanePolylinesJson ?? this.lanePolylinesJson,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (roiPolygonJson.present) {
      map['roi_polygon_json'] = Variable<String>(roiPolygonJson.value);
    }
    if (lanePolylinesJson.present) {
      map['lane_polylines_json'] = Variable<String>(lanePolylinesJson.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoiPresetsCompanion(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('name: $name, ')
          ..write('roiPolygonJson: $roiPolygonJson, ')
          ..write('lanePolylinesJson: $lanePolylinesJson, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CountingLinesTable extends CountingLines
    with TableInfo<$CountingLinesTable, CountingLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountingLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _presetIdMeta =
      const VerificationMeta('presetId');
  @override
  late final GeneratedColumn<String> presetId = GeneratedColumn<String>(
      'preset_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES roi_presets (id)'));
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES cameras (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name =
      GeneratedColumn<String>('name', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(
            minTextLength: 1,
          ),
          type: DriftSqlType.string,
          requiredDuringInsert: true);
  static const VerificationMeta _startXMeta = const VerificationMeta('startX');
  @override
  late final GeneratedColumn<double> startX = GeneratedColumn<double>(
      'start_x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _startYMeta = const VerificationMeta('startY');
  @override
  late final GeneratedColumn<double> startY = GeneratedColumn<double>(
      'start_y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _endXMeta = const VerificationMeta('endX');
  @override
  late final GeneratedColumn<double> endX = GeneratedColumn<double>(
      'end_x', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _endYMeta = const VerificationMeta('endY');
  @override
  late final GeneratedColumn<double> endY = GeneratedColumn<double>(
      'end_y', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('inbound'));
  static const VerificationMeta _directionVectorJsonMeta =
      const VerificationMeta('directionVectorJson');
  @override
  late final GeneratedColumn<String> directionVectorJson =
      GeneratedColumn<String>('direction_vector_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        presetId,
        cameraId,
        name,
        startX,
        startY,
        endX,
        endY,
        direction,
        directionVectorJson,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'counting_lines';
  @override
  VerificationContext validateIntegrity(Insertable<CountingLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('preset_id')) {
      context.handle(_presetIdMeta,
          presetId.isAcceptableOrUnknown(data['preset_id']!, _presetIdMeta));
    } else if (isInserting) {
      context.missing(_presetIdMeta);
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_x')) {
      context.handle(_startXMeta,
          startX.isAcceptableOrUnknown(data['start_x']!, _startXMeta));
    } else if (isInserting) {
      context.missing(_startXMeta);
    }
    if (data.containsKey('start_y')) {
      context.handle(_startYMeta,
          startY.isAcceptableOrUnknown(data['start_y']!, _startYMeta));
    } else if (isInserting) {
      context.missing(_startYMeta);
    }
    if (data.containsKey('end_x')) {
      context.handle(
          _endXMeta, endX.isAcceptableOrUnknown(data['end_x']!, _endXMeta));
    } else if (isInserting) {
      context.missing(_endXMeta);
    }
    if (data.containsKey('end_y')) {
      context.handle(
          _endYMeta, endY.isAcceptableOrUnknown(data['end_y']!, _endYMeta));
    } else if (isInserting) {
      context.missing(_endYMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    }
    if (data.containsKey('direction_vector_json')) {
      context.handle(
          _directionVectorJsonMeta,
          directionVectorJson.isAcceptableOrUnknown(
              data['direction_vector_json']!, _directionVectorJsonMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CountingLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CountingLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      presetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preset_id'])!,
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}start_x'])!,
      startY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}start_y'])!,
      endX: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}end_x'])!,
      endY: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}end_y'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      directionVectorJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}direction_vector_json']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $CountingLinesTable createAlias(String alias) {
    return $CountingLinesTable(attachedDatabase, alias);
  }
}

class CountingLine extends DataClass implements Insertable<CountingLine> {
  final String id;
  final String presetId;
  final String cameraId;
  final String name;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String direction;
  final String? directionVectorJson;
  final int sortOrder;
  const CountingLine(
      {required this.id,
      required this.presetId,
      required this.cameraId,
      required this.name,
      required this.startX,
      required this.startY,
      required this.endX,
      required this.endY,
      required this.direction,
      this.directionVectorJson,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['preset_id'] = Variable<String>(presetId);
    map['camera_id'] = Variable<String>(cameraId);
    map['name'] = Variable<String>(name);
    map['start_x'] = Variable<double>(startX);
    map['start_y'] = Variable<double>(startY);
    map['end_x'] = Variable<double>(endX);
    map['end_y'] = Variable<double>(endY);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || directionVectorJson != null) {
      map['direction_vector_json'] = Variable<String>(directionVectorJson);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CountingLinesCompanion toCompanion(bool nullToAbsent) {
    return CountingLinesCompanion(
      id: Value(id),
      presetId: Value(presetId),
      cameraId: Value(cameraId),
      name: Value(name),
      startX: Value(startX),
      startY: Value(startY),
      endX: Value(endX),
      endY: Value(endY),
      direction: Value(direction),
      directionVectorJson: directionVectorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(directionVectorJson),
      sortOrder: Value(sortOrder),
    );
  }

  factory CountingLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CountingLine(
      id: serializer.fromJson<String>(json['id']),
      presetId: serializer.fromJson<String>(json['presetId']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      name: serializer.fromJson<String>(json['name']),
      startX: serializer.fromJson<double>(json['startX']),
      startY: serializer.fromJson<double>(json['startY']),
      endX: serializer.fromJson<double>(json['endX']),
      endY: serializer.fromJson<double>(json['endY']),
      direction: serializer.fromJson<String>(json['direction']),
      directionVectorJson:
          serializer.fromJson<String?>(json['directionVectorJson']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'presetId': serializer.toJson<String>(presetId),
      'cameraId': serializer.toJson<String>(cameraId),
      'name': serializer.toJson<String>(name),
      'startX': serializer.toJson<double>(startX),
      'startY': serializer.toJson<double>(startY),
      'endX': serializer.toJson<double>(endX),
      'endY': serializer.toJson<double>(endY),
      'direction': serializer.toJson<String>(direction),
      'directionVectorJson': serializer.toJson<String?>(directionVectorJson),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  CountingLine copyWith(
          {String? id,
          String? presetId,
          String? cameraId,
          String? name,
          double? startX,
          double? startY,
          double? endX,
          double? endY,
          String? direction,
          Value<String?> directionVectorJson = const Value.absent(),
          int? sortOrder}) =>
      CountingLine(
        id: id ?? this.id,
        presetId: presetId ?? this.presetId,
        cameraId: cameraId ?? this.cameraId,
        name: name ?? this.name,
        startX: startX ?? this.startX,
        startY: startY ?? this.startY,
        endX: endX ?? this.endX,
        endY: endY ?? this.endY,
        direction: direction ?? this.direction,
        directionVectorJson: directionVectorJson.present
            ? directionVectorJson.value
            : this.directionVectorJson,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  CountingLine copyWithCompanion(CountingLinesCompanion data) {
    return CountingLine(
      id: data.id.present ? data.id.value : this.id,
      presetId: data.presetId.present ? data.presetId.value : this.presetId,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      name: data.name.present ? data.name.value : this.name,
      startX: data.startX.present ? data.startX.value : this.startX,
      startY: data.startY.present ? data.startY.value : this.startY,
      endX: data.endX.present ? data.endX.value : this.endX,
      endY: data.endY.present ? data.endY.value : this.endY,
      direction: data.direction.present ? data.direction.value : this.direction,
      directionVectorJson: data.directionVectorJson.present
          ? data.directionVectorJson.value
          : this.directionVectorJson,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CountingLine(')
          ..write('id: $id, ')
          ..write('presetId: $presetId, ')
          ..write('cameraId: $cameraId, ')
          ..write('name: $name, ')
          ..write('startX: $startX, ')
          ..write('startY: $startY, ')
          ..write('endX: $endX, ')
          ..write('endY: $endY, ')
          ..write('direction: $direction, ')
          ..write('directionVectorJson: $directionVectorJson, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, presetId, cameraId, name, startX, startY,
      endX, endY, direction, directionVectorJson, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountingLine &&
          other.id == this.id &&
          other.presetId == this.presetId &&
          other.cameraId == this.cameraId &&
          other.name == this.name &&
          other.startX == this.startX &&
          other.startY == this.startY &&
          other.endX == this.endX &&
          other.endY == this.endY &&
          other.direction == this.direction &&
          other.directionVectorJson == this.directionVectorJson &&
          other.sortOrder == this.sortOrder);
}

class CountingLinesCompanion extends UpdateCompanion<CountingLine> {
  final Value<String> id;
  final Value<String> presetId;
  final Value<String> cameraId;
  final Value<String> name;
  final Value<double> startX;
  final Value<double> startY;
  final Value<double> endX;
  final Value<double> endY;
  final Value<String> direction;
  final Value<String?> directionVectorJson;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CountingLinesCompanion({
    this.id = const Value.absent(),
    this.presetId = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.name = const Value.absent(),
    this.startX = const Value.absent(),
    this.startY = const Value.absent(),
    this.endX = const Value.absent(),
    this.endY = const Value.absent(),
    this.direction = const Value.absent(),
    this.directionVectorJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountingLinesCompanion.insert({
    required String id,
    required String presetId,
    required String cameraId,
    required String name,
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    this.direction = const Value.absent(),
    this.directionVectorJson = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        presetId = Value(presetId),
        cameraId = Value(cameraId),
        name = Value(name),
        startX = Value(startX),
        startY = Value(startY),
        endX = Value(endX),
        endY = Value(endY);
  static Insertable<CountingLine> custom({
    Expression<String>? id,
    Expression<String>? presetId,
    Expression<String>? cameraId,
    Expression<String>? name,
    Expression<double>? startX,
    Expression<double>? startY,
    Expression<double>? endX,
    Expression<double>? endY,
    Expression<String>? direction,
    Expression<String>? directionVectorJson,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (presetId != null) 'preset_id': presetId,
      if (cameraId != null) 'camera_id': cameraId,
      if (name != null) 'name': name,
      if (startX != null) 'start_x': startX,
      if (startY != null) 'start_y': startY,
      if (endX != null) 'end_x': endX,
      if (endY != null) 'end_y': endY,
      if (direction != null) 'direction': direction,
      if (directionVectorJson != null)
        'direction_vector_json': directionVectorJson,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountingLinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? presetId,
      Value<String>? cameraId,
      Value<String>? name,
      Value<double>? startX,
      Value<double>? startY,
      Value<double>? endX,
      Value<double>? endY,
      Value<String>? direction,
      Value<String?>? directionVectorJson,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return CountingLinesCompanion(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      cameraId: cameraId ?? this.cameraId,
      name: name ?? this.name,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      direction: direction ?? this.direction,
      directionVectorJson: directionVectorJson ?? this.directionVectorJson,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (presetId.present) {
      map['preset_id'] = Variable<String>(presetId.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startX.present) {
      map['start_x'] = Variable<double>(startX.value);
    }
    if (startY.present) {
      map['start_y'] = Variable<double>(startY.value);
    }
    if (endX.present) {
      map['end_x'] = Variable<double>(endX.value);
    }
    if (endY.present) {
      map['end_y'] = Variable<double>(endY.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (directionVectorJson.present) {
      map['direction_vector_json'] =
          Variable<String>(directionVectorJson.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountingLinesCompanion(')
          ..write('id: $id, ')
          ..write('presetId: $presetId, ')
          ..write('cameraId: $cameraId, ')
          ..write('name: $name, ')
          ..write('startX: $startX, ')
          ..write('startY: $startY, ')
          ..write('endX: $endX, ')
          ..write('endY: $endY, ')
          ..write('direction: $direction, ')
          ..write('directionVectorJson: $directionVectorJson, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehicleCrossingsTable extends VehicleCrossings
    with TableInfo<$VehicleCrossingsTable, VehicleCrossing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehicleCrossingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES cameras (id)'));
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
      'line_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES counting_lines (id)'));
  static const VerificationMeta _trackIdMeta =
      const VerificationMeta('trackId');
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
      'track_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _crossingSeqMeta =
      const VerificationMeta('crossingSeq');
  @override
  late final GeneratedColumn<int> crossingSeq = GeneratedColumn<int>(
      'crossing_seq', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _class12Meta =
      const VerificationMeta('class12');
  @override
  late final GeneratedColumn<int> class12 = GeneratedColumn<int>(
      'class12', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _confidenceMeta =
      const VerificationMeta('confidence');
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
      'confidence', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _frameIndexMeta =
      const VerificationMeta('frameIndex');
  @override
  late final GeneratedColumn<int> frameIndex = GeneratedColumn<int>(
      'frame_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _speedEstimateKmhMeta =
      const VerificationMeta('speedEstimateKmh');
  @override
  late final GeneratedColumn<double> speedEstimateKmh = GeneratedColumn<double>(
      'speed_estimate_kmh', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _bboxJsonMeta =
      const VerificationMeta('bboxJson');
  @override
  late final GeneratedColumn<String> bboxJson = GeneratedColumn<String>(
      'bbox_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampUtcMeta =
      const VerificationMeta('timestampUtc');
  @override
  late final GeneratedColumn<DateTime> timestampUtc = GeneratedColumn<DateTime>(
      'timestamp_utc', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _ingestedAtMeta =
      const VerificationMeta('ingestedAt');
  @override
  late final GeneratedColumn<DateTime> ingestedAt = GeneratedColumn<DateTime>(
      'ingested_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _vlmClassCodeMeta =
      const VerificationMeta('vlmClassCode');
  @override
  late final GeneratedColumn<int> vlmClassCode = GeneratedColumn<int>(
      'vlm_class_code', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _vlmConfidenceMeta =
      const VerificationMeta('vlmConfidence');
  @override
  late final GeneratedColumn<double> vlmConfidence = GeneratedColumn<double>(
      'vlm_confidence', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _classificationSourceMeta =
      const VerificationMeta('classificationSource');
  @override
  late final GeneratedColumn<String> classificationSource =
      GeneratedColumn<String>('classification_source', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('local'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        cameraId,
        lineId,
        trackId,
        crossingSeq,
        class12,
        confidence,
        direction,
        frameIndex,
        speedEstimateKmh,
        bboxJson,
        timestampUtc,
        ingestedAt,
        vlmClassCode,
        vlmConfidence,
        classificationSource
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicle_crossings';
  @override
  VerificationContext validateIntegrity(Insertable<VehicleCrossing> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(_lineIdMeta,
          lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta));
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(_trackIdMeta,
          trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta));
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('crossing_seq')) {
      context.handle(
          _crossingSeqMeta,
          crossingSeq.isAcceptableOrUnknown(
              data['crossing_seq']!, _crossingSeqMeta));
    }
    if (data.containsKey('class12')) {
      context.handle(_class12Meta,
          class12.isAcceptableOrUnknown(data['class12']!, _class12Meta));
    } else if (isInserting) {
      context.missing(_class12Meta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
          _confidenceMeta,
          confidence.isAcceptableOrUnknown(
              data['confidence']!, _confidenceMeta));
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('frame_index')) {
      context.handle(
          _frameIndexMeta,
          frameIndex.isAcceptableOrUnknown(
              data['frame_index']!, _frameIndexMeta));
    } else if (isInserting) {
      context.missing(_frameIndexMeta);
    }
    if (data.containsKey('speed_estimate_kmh')) {
      context.handle(
          _speedEstimateKmhMeta,
          speedEstimateKmh.isAcceptableOrUnknown(
              data['speed_estimate_kmh']!, _speedEstimateKmhMeta));
    }
    if (data.containsKey('bbox_json')) {
      context.handle(_bboxJsonMeta,
          bboxJson.isAcceptableOrUnknown(data['bbox_json']!, _bboxJsonMeta));
    }
    if (data.containsKey('timestamp_utc')) {
      context.handle(
          _timestampUtcMeta,
          timestampUtc.isAcceptableOrUnknown(
              data['timestamp_utc']!, _timestampUtcMeta));
    } else if (isInserting) {
      context.missing(_timestampUtcMeta);
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
          _ingestedAtMeta,
          ingestedAt.isAcceptableOrUnknown(
              data['ingested_at']!, _ingestedAtMeta));
    }
    if (data.containsKey('vlm_class_code')) {
      context.handle(
          _vlmClassCodeMeta,
          vlmClassCode.isAcceptableOrUnknown(
              data['vlm_class_code']!, _vlmClassCodeMeta));
    }
    if (data.containsKey('vlm_confidence')) {
      context.handle(
          _vlmConfidenceMeta,
          vlmConfidence.isAcceptableOrUnknown(
              data['vlm_confidence']!, _vlmConfidenceMeta));
    }
    if (data.containsKey('classification_source')) {
      context.handle(
          _classificationSourceMeta,
          classificationSource.isAcceptableOrUnknown(
              data['classification_source']!, _classificationSourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {cameraId, lineId, trackId, crossingSeq},
      ];
  @override
  VehicleCrossing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleCrossing(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_id'])!,
      lineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_id'])!,
      trackId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_id'])!,
      crossingSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}crossing_seq'])!,
      class12: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}class12'])!,
      confidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}confidence'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      frameIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}frame_index'])!,
      speedEstimateKmh: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}speed_estimate_kmh']),
      bboxJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bbox_json']),
      timestampUtc: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}timestamp_utc'])!,
      ingestedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ingested_at'])!,
      vlmClassCode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}vlm_class_code']),
      vlmConfidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}vlm_confidence']),
      classificationSource: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}classification_source'])!,
    );
  }

  @override
  $VehicleCrossingsTable createAlias(String alias) {
    return $VehicleCrossingsTable(attachedDatabase, alias);
  }
}

class VehicleCrossing extends DataClass implements Insertable<VehicleCrossing> {
  final String id;
  final String cameraId;
  final String lineId;
  final String trackId;
  final int crossingSeq;
  final int class12;
  final double confidence;
  final String direction;
  final int frameIndex;
  final double? speedEstimateKmh;
  final String? bboxJson;
  final DateTime timestampUtc;
  final DateTime ingestedAt;
  final int? vlmClassCode;
  final double? vlmConfidence;
  final String classificationSource;
  const VehicleCrossing(
      {required this.id,
      required this.cameraId,
      required this.lineId,
      required this.trackId,
      required this.crossingSeq,
      required this.class12,
      required this.confidence,
      required this.direction,
      required this.frameIndex,
      this.speedEstimateKmh,
      this.bboxJson,
      required this.timestampUtc,
      required this.ingestedAt,
      this.vlmClassCode,
      this.vlmConfidence,
      required this.classificationSource});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['camera_id'] = Variable<String>(cameraId);
    map['line_id'] = Variable<String>(lineId);
    map['track_id'] = Variable<String>(trackId);
    map['crossing_seq'] = Variable<int>(crossingSeq);
    map['class12'] = Variable<int>(class12);
    map['confidence'] = Variable<double>(confidence);
    map['direction'] = Variable<String>(direction);
    map['frame_index'] = Variable<int>(frameIndex);
    if (!nullToAbsent || speedEstimateKmh != null) {
      map['speed_estimate_kmh'] = Variable<double>(speedEstimateKmh);
    }
    if (!nullToAbsent || bboxJson != null) {
      map['bbox_json'] = Variable<String>(bboxJson);
    }
    map['timestamp_utc'] = Variable<DateTime>(timestampUtc);
    map['ingested_at'] = Variable<DateTime>(ingestedAt);
    if (!nullToAbsent || vlmClassCode != null) {
      map['vlm_class_code'] = Variable<int>(vlmClassCode);
    }
    if (!nullToAbsent || vlmConfidence != null) {
      map['vlm_confidence'] = Variable<double>(vlmConfidence);
    }
    map['classification_source'] = Variable<String>(classificationSource);
    return map;
  }

  VehicleCrossingsCompanion toCompanion(bool nullToAbsent) {
    return VehicleCrossingsCompanion(
      id: Value(id),
      cameraId: Value(cameraId),
      lineId: Value(lineId),
      trackId: Value(trackId),
      crossingSeq: Value(crossingSeq),
      class12: Value(class12),
      confidence: Value(confidence),
      direction: Value(direction),
      frameIndex: Value(frameIndex),
      speedEstimateKmh: speedEstimateKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(speedEstimateKmh),
      bboxJson: bboxJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bboxJson),
      timestampUtc: Value(timestampUtc),
      ingestedAt: Value(ingestedAt),
      vlmClassCode: vlmClassCode == null && nullToAbsent
          ? const Value.absent()
          : Value(vlmClassCode),
      vlmConfidence: vlmConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(vlmConfidence),
      classificationSource: Value(classificationSource),
    );
  }

  factory VehicleCrossing.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleCrossing(
      id: serializer.fromJson<String>(json['id']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      crossingSeq: serializer.fromJson<int>(json['crossingSeq']),
      class12: serializer.fromJson<int>(json['class12']),
      confidence: serializer.fromJson<double>(json['confidence']),
      direction: serializer.fromJson<String>(json['direction']),
      frameIndex: serializer.fromJson<int>(json['frameIndex']),
      speedEstimateKmh: serializer.fromJson<double?>(json['speedEstimateKmh']),
      bboxJson: serializer.fromJson<String?>(json['bboxJson']),
      timestampUtc: serializer.fromJson<DateTime>(json['timestampUtc']),
      ingestedAt: serializer.fromJson<DateTime>(json['ingestedAt']),
      vlmClassCode: serializer.fromJson<int?>(json['vlmClassCode']),
      vlmConfidence: serializer.fromJson<double?>(json['vlmConfidence']),
      classificationSource:
          serializer.fromJson<String>(json['classificationSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cameraId': serializer.toJson<String>(cameraId),
      'lineId': serializer.toJson<String>(lineId),
      'trackId': serializer.toJson<String>(trackId),
      'crossingSeq': serializer.toJson<int>(crossingSeq),
      'class12': serializer.toJson<int>(class12),
      'confidence': serializer.toJson<double>(confidence),
      'direction': serializer.toJson<String>(direction),
      'frameIndex': serializer.toJson<int>(frameIndex),
      'speedEstimateKmh': serializer.toJson<double?>(speedEstimateKmh),
      'bboxJson': serializer.toJson<String?>(bboxJson),
      'timestampUtc': serializer.toJson<DateTime>(timestampUtc),
      'ingestedAt': serializer.toJson<DateTime>(ingestedAt),
      'vlmClassCode': serializer.toJson<int?>(vlmClassCode),
      'vlmConfidence': serializer.toJson<double?>(vlmConfidence),
      'classificationSource': serializer.toJson<String>(classificationSource),
    };
  }

  VehicleCrossing copyWith(
          {String? id,
          String? cameraId,
          String? lineId,
          String? trackId,
          int? crossingSeq,
          int? class12,
          double? confidence,
          String? direction,
          int? frameIndex,
          Value<double?> speedEstimateKmh = const Value.absent(),
          Value<String?> bboxJson = const Value.absent(),
          DateTime? timestampUtc,
          DateTime? ingestedAt,
          Value<int?> vlmClassCode = const Value.absent(),
          Value<double?> vlmConfidence = const Value.absent(),
          String? classificationSource}) =>
      VehicleCrossing(
        id: id ?? this.id,
        cameraId: cameraId ?? this.cameraId,
        lineId: lineId ?? this.lineId,
        trackId: trackId ?? this.trackId,
        crossingSeq: crossingSeq ?? this.crossingSeq,
        class12: class12 ?? this.class12,
        confidence: confidence ?? this.confidence,
        direction: direction ?? this.direction,
        frameIndex: frameIndex ?? this.frameIndex,
        speedEstimateKmh: speedEstimateKmh.present
            ? speedEstimateKmh.value
            : this.speedEstimateKmh,
        bboxJson: bboxJson.present ? bboxJson.value : this.bboxJson,
        timestampUtc: timestampUtc ?? this.timestampUtc,
        ingestedAt: ingestedAt ?? this.ingestedAt,
        vlmClassCode:
            vlmClassCode.present ? vlmClassCode.value : this.vlmClassCode,
        vlmConfidence:
            vlmConfidence.present ? vlmConfidence.value : this.vlmConfidence,
        classificationSource: classificationSource ?? this.classificationSource,
      );
  VehicleCrossing copyWithCompanion(VehicleCrossingsCompanion data) {
    return VehicleCrossing(
      id: data.id.present ? data.id.value : this.id,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      crossingSeq:
          data.crossingSeq.present ? data.crossingSeq.value : this.crossingSeq,
      class12: data.class12.present ? data.class12.value : this.class12,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
      direction: data.direction.present ? data.direction.value : this.direction,
      frameIndex:
          data.frameIndex.present ? data.frameIndex.value : this.frameIndex,
      speedEstimateKmh: data.speedEstimateKmh.present
          ? data.speedEstimateKmh.value
          : this.speedEstimateKmh,
      bboxJson: data.bboxJson.present ? data.bboxJson.value : this.bboxJson,
      timestampUtc: data.timestampUtc.present
          ? data.timestampUtc.value
          : this.timestampUtc,
      ingestedAt:
          data.ingestedAt.present ? data.ingestedAt.value : this.ingestedAt,
      vlmClassCode: data.vlmClassCode.present
          ? data.vlmClassCode.value
          : this.vlmClassCode,
      vlmConfidence: data.vlmConfidence.present
          ? data.vlmConfidence.value
          : this.vlmConfidence,
      classificationSource: data.classificationSource.present
          ? data.classificationSource.value
          : this.classificationSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleCrossing(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('lineId: $lineId, ')
          ..write('trackId: $trackId, ')
          ..write('crossingSeq: $crossingSeq, ')
          ..write('class12: $class12, ')
          ..write('confidence: $confidence, ')
          ..write('direction: $direction, ')
          ..write('frameIndex: $frameIndex, ')
          ..write('speedEstimateKmh: $speedEstimateKmh, ')
          ..write('bboxJson: $bboxJson, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('vlmClassCode: $vlmClassCode, ')
          ..write('vlmConfidence: $vlmConfidence, ')
          ..write('classificationSource: $classificationSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      cameraId,
      lineId,
      trackId,
      crossingSeq,
      class12,
      confidence,
      direction,
      frameIndex,
      speedEstimateKmh,
      bboxJson,
      timestampUtc,
      ingestedAt,
      vlmClassCode,
      vlmConfidence,
      classificationSource);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleCrossing &&
          other.id == this.id &&
          other.cameraId == this.cameraId &&
          other.lineId == this.lineId &&
          other.trackId == this.trackId &&
          other.crossingSeq == this.crossingSeq &&
          other.class12 == this.class12 &&
          other.confidence == this.confidence &&
          other.direction == this.direction &&
          other.frameIndex == this.frameIndex &&
          other.speedEstimateKmh == this.speedEstimateKmh &&
          other.bboxJson == this.bboxJson &&
          other.timestampUtc == this.timestampUtc &&
          other.ingestedAt == this.ingestedAt &&
          other.vlmClassCode == this.vlmClassCode &&
          other.vlmConfidence == this.vlmConfidence &&
          other.classificationSource == this.classificationSource);
}

class VehicleCrossingsCompanion extends UpdateCompanion<VehicleCrossing> {
  final Value<String> id;
  final Value<String> cameraId;
  final Value<String> lineId;
  final Value<String> trackId;
  final Value<int> crossingSeq;
  final Value<int> class12;
  final Value<double> confidence;
  final Value<String> direction;
  final Value<int> frameIndex;
  final Value<double?> speedEstimateKmh;
  final Value<String?> bboxJson;
  final Value<DateTime> timestampUtc;
  final Value<DateTime> ingestedAt;
  final Value<int?> vlmClassCode;
  final Value<double?> vlmConfidence;
  final Value<String> classificationSource;
  final Value<int> rowid;
  const VehicleCrossingsCompanion({
    this.id = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.crossingSeq = const Value.absent(),
    this.class12 = const Value.absent(),
    this.confidence = const Value.absent(),
    this.direction = const Value.absent(),
    this.frameIndex = const Value.absent(),
    this.speedEstimateKmh = const Value.absent(),
    this.bboxJson = const Value.absent(),
    this.timestampUtc = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.vlmClassCode = const Value.absent(),
    this.vlmConfidence = const Value.absent(),
    this.classificationSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehicleCrossingsCompanion.insert({
    required String id,
    required String cameraId,
    required String lineId,
    required String trackId,
    this.crossingSeq = const Value.absent(),
    required int class12,
    required double confidence,
    required String direction,
    required int frameIndex,
    this.speedEstimateKmh = const Value.absent(),
    this.bboxJson = const Value.absent(),
    required DateTime timestampUtc,
    this.ingestedAt = const Value.absent(),
    this.vlmClassCode = const Value.absent(),
    this.vlmConfidence = const Value.absent(),
    this.classificationSource = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        cameraId = Value(cameraId),
        lineId = Value(lineId),
        trackId = Value(trackId),
        class12 = Value(class12),
        confidence = Value(confidence),
        direction = Value(direction),
        frameIndex = Value(frameIndex),
        timestampUtc = Value(timestampUtc);
  static Insertable<VehicleCrossing> custom({
    Expression<String>? id,
    Expression<String>? cameraId,
    Expression<String>? lineId,
    Expression<String>? trackId,
    Expression<int>? crossingSeq,
    Expression<int>? class12,
    Expression<double>? confidence,
    Expression<String>? direction,
    Expression<int>? frameIndex,
    Expression<double>? speedEstimateKmh,
    Expression<String>? bboxJson,
    Expression<DateTime>? timestampUtc,
    Expression<DateTime>? ingestedAt,
    Expression<int>? vlmClassCode,
    Expression<double>? vlmConfidence,
    Expression<String>? classificationSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cameraId != null) 'camera_id': cameraId,
      if (lineId != null) 'line_id': lineId,
      if (trackId != null) 'track_id': trackId,
      if (crossingSeq != null) 'crossing_seq': crossingSeq,
      if (class12 != null) 'class12': class12,
      if (confidence != null) 'confidence': confidence,
      if (direction != null) 'direction': direction,
      if (frameIndex != null) 'frame_index': frameIndex,
      if (speedEstimateKmh != null) 'speed_estimate_kmh': speedEstimateKmh,
      if (bboxJson != null) 'bbox_json': bboxJson,
      if (timestampUtc != null) 'timestamp_utc': timestampUtc,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (vlmClassCode != null) 'vlm_class_code': vlmClassCode,
      if (vlmConfidence != null) 'vlm_confidence': vlmConfidence,
      if (classificationSource != null)
        'classification_source': classificationSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehicleCrossingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? cameraId,
      Value<String>? lineId,
      Value<String>? trackId,
      Value<int>? crossingSeq,
      Value<int>? class12,
      Value<double>? confidence,
      Value<String>? direction,
      Value<int>? frameIndex,
      Value<double?>? speedEstimateKmh,
      Value<String?>? bboxJson,
      Value<DateTime>? timestampUtc,
      Value<DateTime>? ingestedAt,
      Value<int?>? vlmClassCode,
      Value<double?>? vlmConfidence,
      Value<String>? classificationSource,
      Value<int>? rowid}) {
    return VehicleCrossingsCompanion(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      lineId: lineId ?? this.lineId,
      trackId: trackId ?? this.trackId,
      crossingSeq: crossingSeq ?? this.crossingSeq,
      class12: class12 ?? this.class12,
      confidence: confidence ?? this.confidence,
      direction: direction ?? this.direction,
      frameIndex: frameIndex ?? this.frameIndex,
      speedEstimateKmh: speedEstimateKmh ?? this.speedEstimateKmh,
      bboxJson: bboxJson ?? this.bboxJson,
      timestampUtc: timestampUtc ?? this.timestampUtc,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      vlmClassCode: vlmClassCode ?? this.vlmClassCode,
      vlmConfidence: vlmConfidence ?? this.vlmConfidence,
      classificationSource: classificationSource ?? this.classificationSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (crossingSeq.present) {
      map['crossing_seq'] = Variable<int>(crossingSeq.value);
    }
    if (class12.present) {
      map['class12'] = Variable<int>(class12.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (frameIndex.present) {
      map['frame_index'] = Variable<int>(frameIndex.value);
    }
    if (speedEstimateKmh.present) {
      map['speed_estimate_kmh'] = Variable<double>(speedEstimateKmh.value);
    }
    if (bboxJson.present) {
      map['bbox_json'] = Variable<String>(bboxJson.value);
    }
    if (timestampUtc.present) {
      map['timestamp_utc'] = Variable<DateTime>(timestampUtc.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<DateTime>(ingestedAt.value);
    }
    if (vlmClassCode.present) {
      map['vlm_class_code'] = Variable<int>(vlmClassCode.value);
    }
    if (vlmConfidence.present) {
      map['vlm_confidence'] = Variable<double>(vlmConfidence.value);
    }
    if (classificationSource.present) {
      map['classification_source'] =
          Variable<String>(classificationSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehicleCrossingsCompanion(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('lineId: $lineId, ')
          ..write('trackId: $trackId, ')
          ..write('crossingSeq: $crossingSeq, ')
          ..write('class12: $class12, ')
          ..write('confidence: $confidence, ')
          ..write('direction: $direction, ')
          ..write('frameIndex: $frameIndex, ')
          ..write('speedEstimateKmh: $speedEstimateKmh, ')
          ..write('bboxJson: $bboxJson, ')
          ..write('timestampUtc: $timestampUtc, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('vlmClassCode: $vlmClassCode, ')
          ..write('vlmConfidence: $vlmConfidence, ')
          ..write('classificationSource: $classificationSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AggVehicleCounts15mTable extends AggVehicleCounts15m
    with TableInfo<$AggVehicleCounts15mTable, AggVehicleCount15m> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AggVehicleCounts15mTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cameraIdMeta =
      const VerificationMeta('cameraId');
  @override
  late final GeneratedColumn<String> cameraId = GeneratedColumn<String>(
      'camera_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES cameras (id)'));
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
      'line_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES counting_lines (id)'));
  static const VerificationMeta _bucketStartMeta =
      const VerificationMeta('bucketStart');
  @override
  late final GeneratedColumn<DateTime> bucketStart = GeneratedColumn<DateTime>(
      'bucket_start', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _class12Meta =
      const VerificationMeta('class12');
  @override
  late final GeneratedColumn<int> class12 = GeneratedColumn<int>(
      'class12', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sumConfidenceMeta =
      const VerificationMeta('sumConfidence');
  @override
  late final GeneratedColumn<double> sumConfidence = GeneratedColumn<double>(
      'sum_confidence', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _sumSpeedKmhMeta =
      const VerificationMeta('sumSpeedKmh');
  @override
  late final GeneratedColumn<double> sumSpeedKmh = GeneratedColumn<double>(
      'sum_speed_kmh', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _minSpeedKmhMeta =
      const VerificationMeta('minSpeedKmh');
  @override
  late final GeneratedColumn<double> minSpeedKmh = GeneratedColumn<double>(
      'min_speed_kmh', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _maxSpeedKmhMeta =
      const VerificationMeta('maxSpeedKmh');
  @override
  late final GeneratedColumn<double> maxSpeedKmh = GeneratedColumn<double>(
      'max_speed_kmh', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _lastUpdatedAtMeta =
      const VerificationMeta('lastUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> lastUpdatedAt =
      GeneratedColumn<DateTime>('last_updated_at', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        cameraId,
        lineId,
        bucketStart,
        class12,
        direction,
        count,
        sumConfidence,
        sumSpeedKmh,
        minSpeedKmh,
        maxSpeedKmh,
        lastUpdatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agg_vehicle_counts15m';
  @override
  VerificationContext validateIntegrity(Insertable<AggVehicleCount15m> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('camera_id')) {
      context.handle(_cameraIdMeta,
          cameraId.isAcceptableOrUnknown(data['camera_id']!, _cameraIdMeta));
    } else if (isInserting) {
      context.missing(_cameraIdMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(_lineIdMeta,
          lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta));
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('bucket_start')) {
      context.handle(
          _bucketStartMeta,
          bucketStart.isAcceptableOrUnknown(
              data['bucket_start']!, _bucketStartMeta));
    } else if (isInserting) {
      context.missing(_bucketStartMeta);
    }
    if (data.containsKey('class12')) {
      context.handle(_class12Meta,
          class12.isAcceptableOrUnknown(data['class12']!, _class12Meta));
    } else if (isInserting) {
      context.missing(_class12Meta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    }
    if (data.containsKey('sum_confidence')) {
      context.handle(
          _sumConfidenceMeta,
          sumConfidence.isAcceptableOrUnknown(
              data['sum_confidence']!, _sumConfidenceMeta));
    }
    if (data.containsKey('sum_speed_kmh')) {
      context.handle(
          _sumSpeedKmhMeta,
          sumSpeedKmh.isAcceptableOrUnknown(
              data['sum_speed_kmh']!, _sumSpeedKmhMeta));
    }
    if (data.containsKey('min_speed_kmh')) {
      context.handle(
          _minSpeedKmhMeta,
          minSpeedKmh.isAcceptableOrUnknown(
              data['min_speed_kmh']!, _minSpeedKmhMeta));
    }
    if (data.containsKey('max_speed_kmh')) {
      context.handle(
          _maxSpeedKmhMeta,
          maxSpeedKmh.isAcceptableOrUnknown(
              data['max_speed_kmh']!, _maxSpeedKmhMeta));
    }
    if (data.containsKey('last_updated_at')) {
      context.handle(
          _lastUpdatedAtMeta,
          lastUpdatedAt.isAcceptableOrUnknown(
              data['last_updated_at']!, _lastUpdatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {cameraId, lineId, bucketStart, class12, direction},
      ];
  @override
  AggVehicleCount15m map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AggVehicleCount15m(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      cameraId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}camera_id'])!,
      lineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}line_id'])!,
      bucketStart: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}bucket_start'])!,
      class12: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}class12'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      sumConfidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sum_confidence'])!,
      sumSpeedKmh: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sum_speed_kmh'])!,
      minSpeedKmh: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}min_speed_kmh']),
      maxSpeedKmh: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}max_speed_kmh']),
      lastUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_updated_at'])!,
    );
  }

  @override
  $AggVehicleCounts15mTable createAlias(String alias) {
    return $AggVehicleCounts15mTable(attachedDatabase, alias);
  }
}

class AggVehicleCount15m extends DataClass
    implements Insertable<AggVehicleCount15m> {
  final String id;
  final String cameraId;
  final String lineId;
  final DateTime bucketStart;
  final int class12;
  final String direction;
  final int count;
  final double sumConfidence;
  final double sumSpeedKmh;
  final double? minSpeedKmh;
  final double? maxSpeedKmh;
  final DateTime lastUpdatedAt;
  const AggVehicleCount15m(
      {required this.id,
      required this.cameraId,
      required this.lineId,
      required this.bucketStart,
      required this.class12,
      required this.direction,
      required this.count,
      required this.sumConfidence,
      required this.sumSpeedKmh,
      this.minSpeedKmh,
      this.maxSpeedKmh,
      required this.lastUpdatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['camera_id'] = Variable<String>(cameraId);
    map['line_id'] = Variable<String>(lineId);
    map['bucket_start'] = Variable<DateTime>(bucketStart);
    map['class12'] = Variable<int>(class12);
    map['direction'] = Variable<String>(direction);
    map['count'] = Variable<int>(count);
    map['sum_confidence'] = Variable<double>(sumConfidence);
    map['sum_speed_kmh'] = Variable<double>(sumSpeedKmh);
    if (!nullToAbsent || minSpeedKmh != null) {
      map['min_speed_kmh'] = Variable<double>(minSpeedKmh);
    }
    if (!nullToAbsent || maxSpeedKmh != null) {
      map['max_speed_kmh'] = Variable<double>(maxSpeedKmh);
    }
    map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt);
    return map;
  }

  AggVehicleCounts15mCompanion toCompanion(bool nullToAbsent) {
    return AggVehicleCounts15mCompanion(
      id: Value(id),
      cameraId: Value(cameraId),
      lineId: Value(lineId),
      bucketStart: Value(bucketStart),
      class12: Value(class12),
      direction: Value(direction),
      count: Value(count),
      sumConfidence: Value(sumConfidence),
      sumSpeedKmh: Value(sumSpeedKmh),
      minSpeedKmh: minSpeedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(minSpeedKmh),
      maxSpeedKmh: maxSpeedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(maxSpeedKmh),
      lastUpdatedAt: Value(lastUpdatedAt),
    );
  }

  factory AggVehicleCount15m.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AggVehicleCount15m(
      id: serializer.fromJson<String>(json['id']),
      cameraId: serializer.fromJson<String>(json['cameraId']),
      lineId: serializer.fromJson<String>(json['lineId']),
      bucketStart: serializer.fromJson<DateTime>(json['bucketStart']),
      class12: serializer.fromJson<int>(json['class12']),
      direction: serializer.fromJson<String>(json['direction']),
      count: serializer.fromJson<int>(json['count']),
      sumConfidence: serializer.fromJson<double>(json['sumConfidence']),
      sumSpeedKmh: serializer.fromJson<double>(json['sumSpeedKmh']),
      minSpeedKmh: serializer.fromJson<double?>(json['minSpeedKmh']),
      maxSpeedKmh: serializer.fromJson<double?>(json['maxSpeedKmh']),
      lastUpdatedAt: serializer.fromJson<DateTime>(json['lastUpdatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cameraId': serializer.toJson<String>(cameraId),
      'lineId': serializer.toJson<String>(lineId),
      'bucketStart': serializer.toJson<DateTime>(bucketStart),
      'class12': serializer.toJson<int>(class12),
      'direction': serializer.toJson<String>(direction),
      'count': serializer.toJson<int>(count),
      'sumConfidence': serializer.toJson<double>(sumConfidence),
      'sumSpeedKmh': serializer.toJson<double>(sumSpeedKmh),
      'minSpeedKmh': serializer.toJson<double?>(minSpeedKmh),
      'maxSpeedKmh': serializer.toJson<double?>(maxSpeedKmh),
      'lastUpdatedAt': serializer.toJson<DateTime>(lastUpdatedAt),
    };
  }

  AggVehicleCount15m copyWith(
          {String? id,
          String? cameraId,
          String? lineId,
          DateTime? bucketStart,
          int? class12,
          String? direction,
          int? count,
          double? sumConfidence,
          double? sumSpeedKmh,
          Value<double?> minSpeedKmh = const Value.absent(),
          Value<double?> maxSpeedKmh = const Value.absent(),
          DateTime? lastUpdatedAt}) =>
      AggVehicleCount15m(
        id: id ?? this.id,
        cameraId: cameraId ?? this.cameraId,
        lineId: lineId ?? this.lineId,
        bucketStart: bucketStart ?? this.bucketStart,
        class12: class12 ?? this.class12,
        direction: direction ?? this.direction,
        count: count ?? this.count,
        sumConfidence: sumConfidence ?? this.sumConfidence,
        sumSpeedKmh: sumSpeedKmh ?? this.sumSpeedKmh,
        minSpeedKmh: minSpeedKmh.present ? minSpeedKmh.value : this.minSpeedKmh,
        maxSpeedKmh: maxSpeedKmh.present ? maxSpeedKmh.value : this.maxSpeedKmh,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      );
  AggVehicleCount15m copyWithCompanion(AggVehicleCounts15mCompanion data) {
    return AggVehicleCount15m(
      id: data.id.present ? data.id.value : this.id,
      cameraId: data.cameraId.present ? data.cameraId.value : this.cameraId,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      bucketStart:
          data.bucketStart.present ? data.bucketStart.value : this.bucketStart,
      class12: data.class12.present ? data.class12.value : this.class12,
      direction: data.direction.present ? data.direction.value : this.direction,
      count: data.count.present ? data.count.value : this.count,
      sumConfidence: data.sumConfidence.present
          ? data.sumConfidence.value
          : this.sumConfidence,
      sumSpeedKmh:
          data.sumSpeedKmh.present ? data.sumSpeedKmh.value : this.sumSpeedKmh,
      minSpeedKmh:
          data.minSpeedKmh.present ? data.minSpeedKmh.value : this.minSpeedKmh,
      maxSpeedKmh:
          data.maxSpeedKmh.present ? data.maxSpeedKmh.value : this.maxSpeedKmh,
      lastUpdatedAt: data.lastUpdatedAt.present
          ? data.lastUpdatedAt.value
          : this.lastUpdatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AggVehicleCount15m(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('lineId: $lineId, ')
          ..write('bucketStart: $bucketStart, ')
          ..write('class12: $class12, ')
          ..write('direction: $direction, ')
          ..write('count: $count, ')
          ..write('sumConfidence: $sumConfidence, ')
          ..write('sumSpeedKmh: $sumSpeedKmh, ')
          ..write('minSpeedKmh: $minSpeedKmh, ')
          ..write('maxSpeedKmh: $maxSpeedKmh, ')
          ..write('lastUpdatedAt: $lastUpdatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      cameraId,
      lineId,
      bucketStart,
      class12,
      direction,
      count,
      sumConfidence,
      sumSpeedKmh,
      minSpeedKmh,
      maxSpeedKmh,
      lastUpdatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AggVehicleCount15m &&
          other.id == this.id &&
          other.cameraId == this.cameraId &&
          other.lineId == this.lineId &&
          other.bucketStart == this.bucketStart &&
          other.class12 == this.class12 &&
          other.direction == this.direction &&
          other.count == this.count &&
          other.sumConfidence == this.sumConfidence &&
          other.sumSpeedKmh == this.sumSpeedKmh &&
          other.minSpeedKmh == this.minSpeedKmh &&
          other.maxSpeedKmh == this.maxSpeedKmh &&
          other.lastUpdatedAt == this.lastUpdatedAt);
}

class AggVehicleCounts15mCompanion extends UpdateCompanion<AggVehicleCount15m> {
  final Value<String> id;
  final Value<String> cameraId;
  final Value<String> lineId;
  final Value<DateTime> bucketStart;
  final Value<int> class12;
  final Value<String> direction;
  final Value<int> count;
  final Value<double> sumConfidence;
  final Value<double> sumSpeedKmh;
  final Value<double?> minSpeedKmh;
  final Value<double?> maxSpeedKmh;
  final Value<DateTime> lastUpdatedAt;
  final Value<int> rowid;
  const AggVehicleCounts15mCompanion({
    this.id = const Value.absent(),
    this.cameraId = const Value.absent(),
    this.lineId = const Value.absent(),
    this.bucketStart = const Value.absent(),
    this.class12 = const Value.absent(),
    this.direction = const Value.absent(),
    this.count = const Value.absent(),
    this.sumConfidence = const Value.absent(),
    this.sumSpeedKmh = const Value.absent(),
    this.minSpeedKmh = const Value.absent(),
    this.maxSpeedKmh = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AggVehicleCounts15mCompanion.insert({
    required String id,
    required String cameraId,
    required String lineId,
    required DateTime bucketStart,
    required int class12,
    required String direction,
    this.count = const Value.absent(),
    this.sumConfidence = const Value.absent(),
    this.sumSpeedKmh = const Value.absent(),
    this.minSpeedKmh = const Value.absent(),
    this.maxSpeedKmh = const Value.absent(),
    this.lastUpdatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        cameraId = Value(cameraId),
        lineId = Value(lineId),
        bucketStart = Value(bucketStart),
        class12 = Value(class12),
        direction = Value(direction);
  static Insertable<AggVehicleCount15m> custom({
    Expression<String>? id,
    Expression<String>? cameraId,
    Expression<String>? lineId,
    Expression<DateTime>? bucketStart,
    Expression<int>? class12,
    Expression<String>? direction,
    Expression<int>? count,
    Expression<double>? sumConfidence,
    Expression<double>? sumSpeedKmh,
    Expression<double>? minSpeedKmh,
    Expression<double>? maxSpeedKmh,
    Expression<DateTime>? lastUpdatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cameraId != null) 'camera_id': cameraId,
      if (lineId != null) 'line_id': lineId,
      if (bucketStart != null) 'bucket_start': bucketStart,
      if (class12 != null) 'class12': class12,
      if (direction != null) 'direction': direction,
      if (count != null) 'count': count,
      if (sumConfidence != null) 'sum_confidence': sumConfidence,
      if (sumSpeedKmh != null) 'sum_speed_kmh': sumSpeedKmh,
      if (minSpeedKmh != null) 'min_speed_kmh': minSpeedKmh,
      if (maxSpeedKmh != null) 'max_speed_kmh': maxSpeedKmh,
      if (lastUpdatedAt != null) 'last_updated_at': lastUpdatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AggVehicleCounts15mCompanion copyWith(
      {Value<String>? id,
      Value<String>? cameraId,
      Value<String>? lineId,
      Value<DateTime>? bucketStart,
      Value<int>? class12,
      Value<String>? direction,
      Value<int>? count,
      Value<double>? sumConfidence,
      Value<double>? sumSpeedKmh,
      Value<double?>? minSpeedKmh,
      Value<double?>? maxSpeedKmh,
      Value<DateTime>? lastUpdatedAt,
      Value<int>? rowid}) {
    return AggVehicleCounts15mCompanion(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      lineId: lineId ?? this.lineId,
      bucketStart: bucketStart ?? this.bucketStart,
      class12: class12 ?? this.class12,
      direction: direction ?? this.direction,
      count: count ?? this.count,
      sumConfidence: sumConfidence ?? this.sumConfidence,
      sumSpeedKmh: sumSpeedKmh ?? this.sumSpeedKmh,
      minSpeedKmh: minSpeedKmh ?? this.minSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cameraId.present) {
      map['camera_id'] = Variable<String>(cameraId.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (bucketStart.present) {
      map['bucket_start'] = Variable<DateTime>(bucketStart.value);
    }
    if (class12.present) {
      map['class12'] = Variable<int>(class12.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (sumConfidence.present) {
      map['sum_confidence'] = Variable<double>(sumConfidence.value);
    }
    if (sumSpeedKmh.present) {
      map['sum_speed_kmh'] = Variable<double>(sumSpeedKmh.value);
    }
    if (minSpeedKmh.present) {
      map['min_speed_kmh'] = Variable<double>(minSpeedKmh.value);
    }
    if (maxSpeedKmh.present) {
      map['max_speed_kmh'] = Variable<double>(maxSpeedKmh.value);
    }
    if (lastUpdatedAt.present) {
      map['last_updated_at'] = Variable<DateTime>(lastUpdatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AggVehicleCounts15mCompanion(')
          ..write('id: $id, ')
          ..write('cameraId: $cameraId, ')
          ..write('lineId: $lineId, ')
          ..write('bucketStart: $bucketStart, ')
          ..write('class12: $class12, ')
          ..write('direction: $direction, ')
          ..write('count: $count, ')
          ..write('sumConfidence: $sumConfidence, ')
          ..write('sumSpeedKmh: $sumSpeedKmh, ')
          ..write('minSpeedKmh: $minSpeedKmh, ')
          ..write('maxSpeedKmh: $maxSpeedKmh, ')
          ..write('lastUpdatedAt: $lastUpdatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ManualClassificationsTable extends ManualClassifications
    with TableInfo<$ManualClassificationsTable, ManualClassification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManualClassificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stage1ClassMeta =
      const VerificationMeta('stage1Class');
  @override
  late final GeneratedColumn<int> stage1Class = GeneratedColumn<int>(
      'stage1_class', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _stage1ConfidenceMeta =
      const VerificationMeta('stage1Confidence');
  @override
  late final GeneratedColumn<double> stage1Confidence = GeneratedColumn<double>(
      'stage1_confidence', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _wheelCountMeta =
      const VerificationMeta('wheelCount');
  @override
  late final GeneratedColumn<int> wheelCount = GeneratedColumn<int>(
      'wheel_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _jointCountMeta =
      const VerificationMeta('jointCount');
  @override
  late final GeneratedColumn<int> jointCount = GeneratedColumn<int>(
      'joint_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _axleCountMeta =
      const VerificationMeta('axleCount');
  @override
  late final GeneratedColumn<int> axleCount = GeneratedColumn<int>(
      'axle_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _hasTrailerMeta =
      const VerificationMeta('hasTrailer');
  @override
  late final GeneratedColumn<bool> hasTrailer = GeneratedColumn<bool>(
      'has_trailer', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("has_trailer" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _finalClass12Meta =
      const VerificationMeta('finalClass12');
  @override
  late final GeneratedColumn<int> finalClass12 = GeneratedColumn<int>(
      'final_class12', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _finalConfidenceMeta =
      const VerificationMeta('finalConfidence');
  @override
  late final GeneratedColumn<double> finalConfidence = GeneratedColumn<double>(
      'final_confidence', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _bboxJsonMeta =
      const VerificationMeta('bboxJson');
  @override
  late final GeneratedColumn<String> bboxJson = GeneratedColumn<String>(
      'bbox_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        imagePath,
        stage1Class,
        stage1Confidence,
        wheelCount,
        jointCount,
        axleCount,
        hasTrailer,
        finalClass12,
        finalConfidence,
        bboxJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manual_classifications';
  @override
  VerificationContext validateIntegrity(
      Insertable<ManualClassification> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('stage1_class')) {
      context.handle(
          _stage1ClassMeta,
          stage1Class.isAcceptableOrUnknown(
              data['stage1_class']!, _stage1ClassMeta));
    } else if (isInserting) {
      context.missing(_stage1ClassMeta);
    }
    if (data.containsKey('stage1_confidence')) {
      context.handle(
          _stage1ConfidenceMeta,
          stage1Confidence.isAcceptableOrUnknown(
              data['stage1_confidence']!, _stage1ConfidenceMeta));
    } else if (isInserting) {
      context.missing(_stage1ConfidenceMeta);
    }
    if (data.containsKey('wheel_count')) {
      context.handle(
          _wheelCountMeta,
          wheelCount.isAcceptableOrUnknown(
              data['wheel_count']!, _wheelCountMeta));
    }
    if (data.containsKey('joint_count')) {
      context.handle(
          _jointCountMeta,
          jointCount.isAcceptableOrUnknown(
              data['joint_count']!, _jointCountMeta));
    }
    if (data.containsKey('axle_count')) {
      context.handle(_axleCountMeta,
          axleCount.isAcceptableOrUnknown(data['axle_count']!, _axleCountMeta));
    }
    if (data.containsKey('has_trailer')) {
      context.handle(
          _hasTrailerMeta,
          hasTrailer.isAcceptableOrUnknown(
              data['has_trailer']!, _hasTrailerMeta));
    }
    if (data.containsKey('final_class12')) {
      context.handle(
          _finalClass12Meta,
          finalClass12.isAcceptableOrUnknown(
              data['final_class12']!, _finalClass12Meta));
    } else if (isInserting) {
      context.missing(_finalClass12Meta);
    }
    if (data.containsKey('final_confidence')) {
      context.handle(
          _finalConfidenceMeta,
          finalConfidence.isAcceptableOrUnknown(
              data['final_confidence']!, _finalConfidenceMeta));
    } else if (isInserting) {
      context.missing(_finalConfidenceMeta);
    }
    if (data.containsKey('bbox_json')) {
      context.handle(_bboxJsonMeta,
          bboxJson.isAcceptableOrUnknown(data['bbox_json']!, _bboxJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ManualClassification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManualClassification(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      stage1Class: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stage1_class'])!,
      stage1Confidence: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}stage1_confidence'])!,
      wheelCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}wheel_count'])!,
      jointCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}joint_count'])!,
      axleCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}axle_count'])!,
      hasTrailer: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}has_trailer'])!,
      finalClass12: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}final_class12'])!,
      finalConfidence: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}final_confidence'])!,
      bboxJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bbox_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ManualClassificationsTable createAlias(String alias) {
    return $ManualClassificationsTable(attachedDatabase, alias);
  }
}

class ManualClassification extends DataClass
    implements Insertable<ManualClassification> {
  final String id;
  final String imagePath;
  final int stage1Class;
  final double stage1Confidence;
  final int wheelCount;
  final int jointCount;
  final int axleCount;
  final bool hasTrailer;
  final int finalClass12;
  final double finalConfidence;
  final String? bboxJson;
  final DateTime createdAt;
  const ManualClassification(
      {required this.id,
      required this.imagePath,
      required this.stage1Class,
      required this.stage1Confidence,
      required this.wheelCount,
      required this.jointCount,
      required this.axleCount,
      required this.hasTrailer,
      required this.finalClass12,
      required this.finalConfidence,
      this.bboxJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['image_path'] = Variable<String>(imagePath);
    map['stage1_class'] = Variable<int>(stage1Class);
    map['stage1_confidence'] = Variable<double>(stage1Confidence);
    map['wheel_count'] = Variable<int>(wheelCount);
    map['joint_count'] = Variable<int>(jointCount);
    map['axle_count'] = Variable<int>(axleCount);
    map['has_trailer'] = Variable<bool>(hasTrailer);
    map['final_class12'] = Variable<int>(finalClass12);
    map['final_confidence'] = Variable<double>(finalConfidence);
    if (!nullToAbsent || bboxJson != null) {
      map['bbox_json'] = Variable<String>(bboxJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ManualClassificationsCompanion toCompanion(bool nullToAbsent) {
    return ManualClassificationsCompanion(
      id: Value(id),
      imagePath: Value(imagePath),
      stage1Class: Value(stage1Class),
      stage1Confidence: Value(stage1Confidence),
      wheelCount: Value(wheelCount),
      jointCount: Value(jointCount),
      axleCount: Value(axleCount),
      hasTrailer: Value(hasTrailer),
      finalClass12: Value(finalClass12),
      finalConfidence: Value(finalConfidence),
      bboxJson: bboxJson == null && nullToAbsent
          ? const Value.absent()
          : Value(bboxJson),
      createdAt: Value(createdAt),
    );
  }

  factory ManualClassification.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManualClassification(
      id: serializer.fromJson<String>(json['id']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      stage1Class: serializer.fromJson<int>(json['stage1Class']),
      stage1Confidence: serializer.fromJson<double>(json['stage1Confidence']),
      wheelCount: serializer.fromJson<int>(json['wheelCount']),
      jointCount: serializer.fromJson<int>(json['jointCount']),
      axleCount: serializer.fromJson<int>(json['axleCount']),
      hasTrailer: serializer.fromJson<bool>(json['hasTrailer']),
      finalClass12: serializer.fromJson<int>(json['finalClass12']),
      finalConfidence: serializer.fromJson<double>(json['finalConfidence']),
      bboxJson: serializer.fromJson<String?>(json['bboxJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'imagePath': serializer.toJson<String>(imagePath),
      'stage1Class': serializer.toJson<int>(stage1Class),
      'stage1Confidence': serializer.toJson<double>(stage1Confidence),
      'wheelCount': serializer.toJson<int>(wheelCount),
      'jointCount': serializer.toJson<int>(jointCount),
      'axleCount': serializer.toJson<int>(axleCount),
      'hasTrailer': serializer.toJson<bool>(hasTrailer),
      'finalClass12': serializer.toJson<int>(finalClass12),
      'finalConfidence': serializer.toJson<double>(finalConfidence),
      'bboxJson': serializer.toJson<String?>(bboxJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ManualClassification copyWith(
          {String? id,
          String? imagePath,
          int? stage1Class,
          double? stage1Confidence,
          int? wheelCount,
          int? jointCount,
          int? axleCount,
          bool? hasTrailer,
          int? finalClass12,
          double? finalConfidence,
          Value<String?> bboxJson = const Value.absent(),
          DateTime? createdAt}) =>
      ManualClassification(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        stage1Class: stage1Class ?? this.stage1Class,
        stage1Confidence: stage1Confidence ?? this.stage1Confidence,
        wheelCount: wheelCount ?? this.wheelCount,
        jointCount: jointCount ?? this.jointCount,
        axleCount: axleCount ?? this.axleCount,
        hasTrailer: hasTrailer ?? this.hasTrailer,
        finalClass12: finalClass12 ?? this.finalClass12,
        finalConfidence: finalConfidence ?? this.finalConfidence,
        bboxJson: bboxJson.present ? bboxJson.value : this.bboxJson,
        createdAt: createdAt ?? this.createdAt,
      );
  ManualClassification copyWithCompanion(ManualClassificationsCompanion data) {
    return ManualClassification(
      id: data.id.present ? data.id.value : this.id,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      stage1Class:
          data.stage1Class.present ? data.stage1Class.value : this.stage1Class,
      stage1Confidence: data.stage1Confidence.present
          ? data.stage1Confidence.value
          : this.stage1Confidence,
      wheelCount:
          data.wheelCount.present ? data.wheelCount.value : this.wheelCount,
      jointCount:
          data.jointCount.present ? data.jointCount.value : this.jointCount,
      axleCount: data.axleCount.present ? data.axleCount.value : this.axleCount,
      hasTrailer:
          data.hasTrailer.present ? data.hasTrailer.value : this.hasTrailer,
      finalClass12: data.finalClass12.present
          ? data.finalClass12.value
          : this.finalClass12,
      finalConfidence: data.finalConfidence.present
          ? data.finalConfidence.value
          : this.finalConfidence,
      bboxJson: data.bboxJson.present ? data.bboxJson.value : this.bboxJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManualClassification(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('stage1Class: $stage1Class, ')
          ..write('stage1Confidence: $stage1Confidence, ')
          ..write('wheelCount: $wheelCount, ')
          ..write('jointCount: $jointCount, ')
          ..write('axleCount: $axleCount, ')
          ..write('hasTrailer: $hasTrailer, ')
          ..write('finalClass12: $finalClass12, ')
          ..write('finalConfidence: $finalConfidence, ')
          ..write('bboxJson: $bboxJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      imagePath,
      stage1Class,
      stage1Confidence,
      wheelCount,
      jointCount,
      axleCount,
      hasTrailer,
      finalClass12,
      finalConfidence,
      bboxJson,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManualClassification &&
          other.id == this.id &&
          other.imagePath == this.imagePath &&
          other.stage1Class == this.stage1Class &&
          other.stage1Confidence == this.stage1Confidence &&
          other.wheelCount == this.wheelCount &&
          other.jointCount == this.jointCount &&
          other.axleCount == this.axleCount &&
          other.hasTrailer == this.hasTrailer &&
          other.finalClass12 == this.finalClass12 &&
          other.finalConfidence == this.finalConfidence &&
          other.bboxJson == this.bboxJson &&
          other.createdAt == this.createdAt);
}

class ManualClassificationsCompanion
    extends UpdateCompanion<ManualClassification> {
  final Value<String> id;
  final Value<String> imagePath;
  final Value<int> stage1Class;
  final Value<double> stage1Confidence;
  final Value<int> wheelCount;
  final Value<int> jointCount;
  final Value<int> axleCount;
  final Value<bool> hasTrailer;
  final Value<int> finalClass12;
  final Value<double> finalConfidence;
  final Value<String?> bboxJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ManualClassificationsCompanion({
    this.id = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.stage1Class = const Value.absent(),
    this.stage1Confidence = const Value.absent(),
    this.wheelCount = const Value.absent(),
    this.jointCount = const Value.absent(),
    this.axleCount = const Value.absent(),
    this.hasTrailer = const Value.absent(),
    this.finalClass12 = const Value.absent(),
    this.finalConfidence = const Value.absent(),
    this.bboxJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ManualClassificationsCompanion.insert({
    required String id,
    required String imagePath,
    required int stage1Class,
    required double stage1Confidence,
    this.wheelCount = const Value.absent(),
    this.jointCount = const Value.absent(),
    this.axleCount = const Value.absent(),
    this.hasTrailer = const Value.absent(),
    required int finalClass12,
    required double finalConfidence,
    this.bboxJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        imagePath = Value(imagePath),
        stage1Class = Value(stage1Class),
        stage1Confidence = Value(stage1Confidence),
        finalClass12 = Value(finalClass12),
        finalConfidence = Value(finalConfidence);
  static Insertable<ManualClassification> custom({
    Expression<String>? id,
    Expression<String>? imagePath,
    Expression<int>? stage1Class,
    Expression<double>? stage1Confidence,
    Expression<int>? wheelCount,
    Expression<int>? jointCount,
    Expression<int>? axleCount,
    Expression<bool>? hasTrailer,
    Expression<int>? finalClass12,
    Expression<double>? finalConfidence,
    Expression<String>? bboxJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imagePath != null) 'image_path': imagePath,
      if (stage1Class != null) 'stage1_class': stage1Class,
      if (stage1Confidence != null) 'stage1_confidence': stage1Confidence,
      if (wheelCount != null) 'wheel_count': wheelCount,
      if (jointCount != null) 'joint_count': jointCount,
      if (axleCount != null) 'axle_count': axleCount,
      if (hasTrailer != null) 'has_trailer': hasTrailer,
      if (finalClass12 != null) 'final_class12': finalClass12,
      if (finalConfidence != null) 'final_confidence': finalConfidence,
      if (bboxJson != null) 'bbox_json': bboxJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ManualClassificationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? imagePath,
      Value<int>? stage1Class,
      Value<double>? stage1Confidence,
      Value<int>? wheelCount,
      Value<int>? jointCount,
      Value<int>? axleCount,
      Value<bool>? hasTrailer,
      Value<int>? finalClass12,
      Value<double>? finalConfidence,
      Value<String?>? bboxJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ManualClassificationsCompanion(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      stage1Class: stage1Class ?? this.stage1Class,
      stage1Confidence: stage1Confidence ?? this.stage1Confidence,
      wheelCount: wheelCount ?? this.wheelCount,
      jointCount: jointCount ?? this.jointCount,
      axleCount: axleCount ?? this.axleCount,
      hasTrailer: hasTrailer ?? this.hasTrailer,
      finalClass12: finalClass12 ?? this.finalClass12,
      finalConfidence: finalConfidence ?? this.finalConfidence,
      bboxJson: bboxJson ?? this.bboxJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (stage1Class.present) {
      map['stage1_class'] = Variable<int>(stage1Class.value);
    }
    if (stage1Confidence.present) {
      map['stage1_confidence'] = Variable<double>(stage1Confidence.value);
    }
    if (wheelCount.present) {
      map['wheel_count'] = Variable<int>(wheelCount.value);
    }
    if (jointCount.present) {
      map['joint_count'] = Variable<int>(jointCount.value);
    }
    if (axleCount.present) {
      map['axle_count'] = Variable<int>(axleCount.value);
    }
    if (hasTrailer.present) {
      map['has_trailer'] = Variable<bool>(hasTrailer.value);
    }
    if (finalClass12.present) {
      map['final_class12'] = Variable<int>(finalClass12.value);
    }
    if (finalConfidence.present) {
      map['final_confidence'] = Variable<double>(finalConfidence.value);
    }
    if (bboxJson.present) {
      map['bbox_json'] = Variable<String>(bboxJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManualClassificationsCompanion(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('stage1Class: $stage1Class, ')
          ..write('stage1Confidence: $stage1Confidence, ')
          ..write('wheelCount: $wheelCount, ')
          ..write('jointCount: $jointCount, ')
          ..write('axleCount: $axleCount, ')
          ..write('hasTrailer: $hasTrailer, ')
          ..write('finalClass12: $finalClass12, ')
          ..write('finalConfidence: $finalConfidence, ')
          ..write('bboxJson: $bboxJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SitesTable sites = $SitesTable(this);
  late final $CamerasTable cameras = $CamerasTable(this);
  late final $RoiPresetsTable roiPresets = $RoiPresetsTable(this);
  late final $CountingLinesTable countingLines = $CountingLinesTable(this);
  late final $VehicleCrossingsTable vehicleCrossings =
      $VehicleCrossingsTable(this);
  late final $AggVehicleCounts15mTable aggVehicleCounts15m =
      $AggVehicleCounts15mTable(this);
  late final $ManualClassificationsTable manualClassifications =
      $ManualClassificationsTable(this);
  late final SitesDao sitesDao = SitesDao(this as AppDatabase);
  late final CamerasDao camerasDao = CamerasDao(this as AppDatabase);
  late final RoiDao roiDao = RoiDao(this as AppDatabase);
  late final CrossingsDao crossingsDao = CrossingsDao(this as AppDatabase);
  late final ClassificationsDao classificationsDao =
      ClassificationsDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        sites,
        cameras,
        roiPresets,
        countingLines,
        vehicleCrossings,
        aggVehicleCounts15m,
        manualClassifications
      ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$SitesTableCreateCompanionBuilder = SitesCompanion Function({
  required String id,
  required String name,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String> timezone,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SitesTableUpdateCompanionBuilder = SitesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> address,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String> timezone,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$SitesTableReferences
    extends BaseReferences<_$AppDatabase, $SitesTable, Site> {
  $$SitesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CamerasTable, List<Camera>> _camerasRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.cameras,
          aliasName: $_aliasNameGenerator(db.sites.id, db.cameras.siteId));

  $$CamerasTableProcessedTableManager get camerasRefs {
    final manager = $$CamerasTableTableManager($_db, $_db.cameras)
        .filter((f) => f.siteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_camerasRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SitesTableFilterComposer extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timezone => $composableBuilder(
      column: $table.timezone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> camerasRefs(
      Expression<bool> Function($$CamerasTableFilterComposer f) f) {
    final $$CamerasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.siteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableFilterComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SitesTableOrderingComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timezone => $composableBuilder(
      column: $table.timezone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SitesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SitesTable> {
  $$SitesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> camerasRefs<T extends Object>(
      Expression<T> Function($$CamerasTableAnnotationComposer a) f) {
    final $$CamerasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.siteId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableAnnotationComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SitesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SitesTable,
    Site,
    $$SitesTableFilterComposer,
    $$SitesTableOrderingComposer,
    $$SitesTableAnnotationComposer,
    $$SitesTableCreateCompanionBuilder,
    $$SitesTableUpdateCompanionBuilder,
    (Site, $$SitesTableReferences),
    Site,
    PrefetchHooks Function({bool camerasRefs})> {
  $$SitesTableTableManager(_$AppDatabase db, $SitesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SitesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SitesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SitesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String> timezone = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SitesCompanion(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> address = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String> timezone = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SitesCompanion.insert(
            id: id,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            timezone: timezone,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SitesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({camerasRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (camerasRefs) db.cameras],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (camerasRefs)
                    await $_getPrefetchedData<Site, $SitesTable, Camera>(
                        currentTable: table,
                        referencedTable:
                            $$SitesTableReferences._camerasRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SitesTableReferences(db, table, p0).camerasRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.siteId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SitesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SitesTable,
    Site,
    $$SitesTableFilterComposer,
    $$SitesTableOrderingComposer,
    $$SitesTableAnnotationComposer,
    $$SitesTableCreateCompanionBuilder,
    $$SitesTableUpdateCompanionBuilder,
    (Site, $$SitesTableReferences),
    Site,
    PrefetchHooks Function({bool camerasRefs})>;
typedef $$CamerasTableCreateCompanionBuilder = CamerasCompanion Function({
  required String id,
  required String siteId,
  required String name,
  Value<String> sourceType,
  Value<String> settingsJson,
  Value<String> status,
  Value<DateTime?> lastSeenAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$CamerasTableUpdateCompanionBuilder = CamerasCompanion Function({
  Value<String> id,
  Value<String> siteId,
  Value<String> name,
  Value<String> sourceType,
  Value<String> settingsJson,
  Value<String> status,
  Value<DateTime?> lastSeenAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$CamerasTableReferences
    extends BaseReferences<_$AppDatabase, $CamerasTable, Camera> {
  $$CamerasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SitesTable _siteIdTable(_$AppDatabase db) => db.sites
      .createAlias($_aliasNameGenerator(db.cameras.siteId, db.sites.id));

  $$SitesTableProcessedTableManager get siteId {
    final $_column = $_itemColumn<String>('site_id')!;

    final manager = $$SitesTableTableManager($_db, $_db.sites)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_siteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RoiPresetsTable, List<RoiPreset>>
      _roiPresetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.roiPresets,
              aliasName:
                  $_aliasNameGenerator(db.cameras.id, db.roiPresets.cameraId));

  $$RoiPresetsTableProcessedTableManager get roiPresetsRefs {
    final manager = $$RoiPresetsTableTableManager($_db, $_db.roiPresets)
        .filter((f) => f.cameraId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_roiPresetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CountingLinesTable, List<CountingLine>>
      _countingLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.countingLines,
              aliasName: $_aliasNameGenerator(
                  db.cameras.id, db.countingLines.cameraId));

  $$CountingLinesTableProcessedTableManager get countingLinesRefs {
    final manager = $$CountingLinesTableTableManager($_db, $_db.countingLines)
        .filter((f) => f.cameraId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_countingLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$VehicleCrossingsTable, List<VehicleCrossing>>
      _vehicleCrossingsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.vehicleCrossings,
              aliasName: $_aliasNameGenerator(
                  db.cameras.id, db.vehicleCrossings.cameraId));

  $$VehicleCrossingsTableProcessedTableManager get vehicleCrossingsRefs {
    final manager = $$VehicleCrossingsTableTableManager(
            $_db, $_db.vehicleCrossings)
        .filter((f) => f.cameraId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_vehicleCrossingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AggVehicleCounts15mTable,
      List<AggVehicleCount15m>> _aggVehicleCounts15mRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.aggVehicleCounts15m,
          aliasName: $_aliasNameGenerator(
              db.cameras.id, db.aggVehicleCounts15m.cameraId));

  $$AggVehicleCounts15mTableProcessedTableManager get aggVehicleCounts15mRefs {
    final manager = $$AggVehicleCounts15mTableTableManager(
            $_db, $_db.aggVehicleCounts15m)
        .filter((f) => f.cameraId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_aggVehicleCounts15mRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CamerasTableFilterComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$SitesTableFilterComposer get siteId {
    final $$SitesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.siteId,
        referencedTable: $db.sites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SitesTableFilterComposer(
              $db: $db,
              $table: $db.sites,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> roiPresetsRefs(
      Expression<bool> Function($$RoiPresetsTableFilterComposer f) f) {
    final $$RoiPresetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.roiPresets,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoiPresetsTableFilterComposer(
              $db: $db,
              $table: $db.roiPresets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> countingLinesRefs(
      Expression<bool> Function($$CountingLinesTableFilterComposer f) f) {
    final $$CountingLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableFilterComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> vehicleCrossingsRefs(
      Expression<bool> Function($$VehicleCrossingsTableFilterComposer f) f) {
    final $$VehicleCrossingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vehicleCrossings,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VehicleCrossingsTableFilterComposer(
              $db: $db,
              $table: $db.vehicleCrossings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> aggVehicleCounts15mRefs(
      Expression<bool> Function($$AggVehicleCounts15mTableFilterComposer f) f) {
    final $$AggVehicleCounts15mTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aggVehicleCounts15m,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AggVehicleCounts15mTableFilterComposer(
              $db: $db,
              $table: $db.aggVehicleCounts15m,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CamerasTableOrderingComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$SitesTableOrderingComposer get siteId {
    final $$SitesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.siteId,
        referencedTable: $db.sites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SitesTableOrderingComposer(
              $db: $db,
              $table: $db.sites,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CamerasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CamerasTable> {
  $$CamerasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SitesTableAnnotationComposer get siteId {
    final $$SitesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.siteId,
        referencedTable: $db.sites,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SitesTableAnnotationComposer(
              $db: $db,
              $table: $db.sites,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> roiPresetsRefs<T extends Object>(
      Expression<T> Function($$RoiPresetsTableAnnotationComposer a) f) {
    final $$RoiPresetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.roiPresets,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoiPresetsTableAnnotationComposer(
              $db: $db,
              $table: $db.roiPresets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> countingLinesRefs<T extends Object>(
      Expression<T> Function($$CountingLinesTableAnnotationComposer a) f) {
    final $$CountingLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> vehicleCrossingsRefs<T extends Object>(
      Expression<T> Function($$VehicleCrossingsTableAnnotationComposer a) f) {
    final $$VehicleCrossingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vehicleCrossings,
        getReferencedColumn: (t) => t.cameraId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VehicleCrossingsTableAnnotationComposer(
              $db: $db,
              $table: $db.vehicleCrossings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> aggVehicleCounts15mRefs<T extends Object>(
      Expression<T> Function($$AggVehicleCounts15mTableAnnotationComposer a)
          f) {
    final $$AggVehicleCounts15mTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.aggVehicleCounts15m,
            getReferencedColumn: (t) => t.cameraId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AggVehicleCounts15mTableAnnotationComposer(
                  $db: $db,
                  $table: $db.aggVehicleCounts15m,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$CamerasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CamerasTable,
    Camera,
    $$CamerasTableFilterComposer,
    $$CamerasTableOrderingComposer,
    $$CamerasTableAnnotationComposer,
    $$CamerasTableCreateCompanionBuilder,
    $$CamerasTableUpdateCompanionBuilder,
    (Camera, $$CamerasTableReferences),
    Camera,
    PrefetchHooks Function(
        {bool siteId,
        bool roiPresetsRefs,
        bool countingLinesRefs,
        bool vehicleCrossingsRefs,
        bool aggVehicleCounts15mRefs})> {
  $$CamerasTableTableManager(_$AppDatabase db, $CamerasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CamerasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CamerasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CamerasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> siteId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> sourceType = const Value.absent(),
            Value<String> settingsJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CamerasCompanion(
            id: id,
            siteId: siteId,
            name: name,
            sourceType: sourceType,
            settingsJson: settingsJson,
            status: status,
            lastSeenAt: lastSeenAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String siteId,
            required String name,
            Value<String> sourceType = const Value.absent(),
            Value<String> settingsJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CamerasCompanion.insert(
            id: id,
            siteId: siteId,
            name: name,
            sourceType: sourceType,
            settingsJson: settingsJson,
            status: status,
            lastSeenAt: lastSeenAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$CamerasTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {siteId = false,
              roiPresetsRefs = false,
              countingLinesRefs = false,
              vehicleCrossingsRefs = false,
              aggVehicleCounts15mRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (roiPresetsRefs) db.roiPresets,
                if (countingLinesRefs) db.countingLines,
                if (vehicleCrossingsRefs) db.vehicleCrossings,
                if (aggVehicleCounts15mRefs) db.aggVehicleCounts15m
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (siteId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.siteId,
                    referencedTable: $$CamerasTableReferences._siteIdTable(db),
                    referencedColumn:
                        $$CamerasTableReferences._siteIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roiPresetsRefs)
                    await $_getPrefetchedData<Camera, $CamerasTable, RoiPreset>(
                        currentTable: table,
                        referencedTable:
                            $$CamerasTableReferences._roiPresetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CamerasTableReferences(db, table, p0)
                                .roiPresetsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.cameraId == item.id),
                        typedResults: items),
                  if (countingLinesRefs)
                    await $_getPrefetchedData<Camera, $CamerasTable,
                            CountingLine>(
                        currentTable: table,
                        referencedTable: $$CamerasTableReferences
                            ._countingLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CamerasTableReferences(db, table, p0)
                                .countingLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.cameraId == item.id),
                        typedResults: items),
                  if (vehicleCrossingsRefs)
                    await $_getPrefetchedData<Camera, $CamerasTable,
                            VehicleCrossing>(
                        currentTable: table,
                        referencedTable: $$CamerasTableReferences
                            ._vehicleCrossingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CamerasTableReferences(db, table, p0)
                                .vehicleCrossingsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.cameraId == item.id),
                        typedResults: items),
                  if (aggVehicleCounts15mRefs)
                    await $_getPrefetchedData<Camera, $CamerasTable,
                            AggVehicleCount15m>(
                        currentTable: table,
                        referencedTable: $$CamerasTableReferences
                            ._aggVehicleCounts15mRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CamerasTableReferences(db, table, p0)
                                .aggVehicleCounts15mRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.cameraId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CamerasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CamerasTable,
    Camera,
    $$CamerasTableFilterComposer,
    $$CamerasTableOrderingComposer,
    $$CamerasTableAnnotationComposer,
    $$CamerasTableCreateCompanionBuilder,
    $$CamerasTableUpdateCompanionBuilder,
    (Camera, $$CamerasTableReferences),
    Camera,
    PrefetchHooks Function(
        {bool siteId,
        bool roiPresetsRefs,
        bool countingLinesRefs,
        bool vehicleCrossingsRefs,
        bool aggVehicleCounts15mRefs})>;
typedef $$RoiPresetsTableCreateCompanionBuilder = RoiPresetsCompanion Function({
  required String id,
  required String cameraId,
  required String name,
  Value<String> roiPolygonJson,
  Value<String> lanePolylinesJson,
  Value<bool> isActive,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$RoiPresetsTableUpdateCompanionBuilder = RoiPresetsCompanion Function({
  Value<String> id,
  Value<String> cameraId,
  Value<String> name,
  Value<String> roiPolygonJson,
  Value<String> lanePolylinesJson,
  Value<bool> isActive,
  Value<int> version,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RoiPresetsTableReferences
    extends BaseReferences<_$AppDatabase, $RoiPresetsTable, RoiPreset> {
  $$RoiPresetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CamerasTable _cameraIdTable(_$AppDatabase db) => db.cameras
      .createAlias($_aliasNameGenerator(db.roiPresets.cameraId, db.cameras.id));

  $$CamerasTableProcessedTableManager get cameraId {
    final $_column = $_itemColumn<String>('camera_id')!;

    final manager = $$CamerasTableTableManager($_db, $_db.cameras)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cameraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$CountingLinesTable, List<CountingLine>>
      _countingLinesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.countingLines,
              aliasName: $_aliasNameGenerator(
                  db.roiPresets.id, db.countingLines.presetId));

  $$CountingLinesTableProcessedTableManager get countingLinesRefs {
    final manager = $$CountingLinesTableTableManager($_db, $_db.countingLines)
        .filter((f) => f.presetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_countingLinesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoiPresetsTableFilterComposer
    extends Composer<_$AppDatabase, $RoiPresetsTable> {
  $$RoiPresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get roiPolygonJson => $composableBuilder(
      column: $table.roiPolygonJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lanePolylinesJson => $composableBuilder(
      column: $table.lanePolylinesJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$CamerasTableFilterComposer get cameraId {
    final $$CamerasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableFilterComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> countingLinesRefs(
      Expression<bool> Function($$CountingLinesTableFilterComposer f) f) {
    final $$CountingLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.presetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableFilterComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoiPresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $RoiPresetsTable> {
  $$RoiPresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get roiPolygonJson => $composableBuilder(
      column: $table.roiPolygonJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lanePolylinesJson => $composableBuilder(
      column: $table.lanePolylinesJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$CamerasTableOrderingComposer get cameraId {
    final $$CamerasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableOrderingComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RoiPresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoiPresetsTable> {
  $$RoiPresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get roiPolygonJson => $composableBuilder(
      column: $table.roiPolygonJson, builder: (column) => column);

  GeneratedColumn<String> get lanePolylinesJson => $composableBuilder(
      column: $table.lanePolylinesJson, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CamerasTableAnnotationComposer get cameraId {
    final $$CamerasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableAnnotationComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> countingLinesRefs<T extends Object>(
      Expression<T> Function($$CountingLinesTableAnnotationComposer a) f) {
    final $$CountingLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.presetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoiPresetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoiPresetsTable,
    RoiPreset,
    $$RoiPresetsTableFilterComposer,
    $$RoiPresetsTableOrderingComposer,
    $$RoiPresetsTableAnnotationComposer,
    $$RoiPresetsTableCreateCompanionBuilder,
    $$RoiPresetsTableUpdateCompanionBuilder,
    (RoiPreset, $$RoiPresetsTableReferences),
    RoiPreset,
    PrefetchHooks Function({bool cameraId, bool countingLinesRefs})> {
  $$RoiPresetsTableTableManager(_$AppDatabase db, $RoiPresetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoiPresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoiPresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoiPresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> cameraId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> roiPolygonJson = const Value.absent(),
            Value<String> lanePolylinesJson = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoiPresetsCompanion(
            id: id,
            cameraId: cameraId,
            name: name,
            roiPolygonJson: roiPolygonJson,
            lanePolylinesJson: lanePolylinesJson,
            isActive: isActive,
            version: version,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String cameraId,
            required String name,
            Value<String> roiPolygonJson = const Value.absent(),
            Value<String> lanePolylinesJson = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoiPresetsCompanion.insert(
            id: id,
            cameraId: cameraId,
            name: name,
            roiPolygonJson: roiPolygonJson,
            lanePolylinesJson: lanePolylinesJson,
            isActive: isActive,
            version: version,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RoiPresetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {cameraId = false, countingLinesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (countingLinesRefs) db.countingLines
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (cameraId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.cameraId,
                    referencedTable:
                        $$RoiPresetsTableReferences._cameraIdTable(db),
                    referencedColumn:
                        $$RoiPresetsTableReferences._cameraIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (countingLinesRefs)
                    await $_getPrefetchedData<RoiPreset, $RoiPresetsTable,
                            CountingLine>(
                        currentTable: table,
                        referencedTable: $$RoiPresetsTableReferences
                            ._countingLinesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RoiPresetsTableReferences(db, table, p0)
                                .countingLinesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.presetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RoiPresetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoiPresetsTable,
    RoiPreset,
    $$RoiPresetsTableFilterComposer,
    $$RoiPresetsTableOrderingComposer,
    $$RoiPresetsTableAnnotationComposer,
    $$RoiPresetsTableCreateCompanionBuilder,
    $$RoiPresetsTableUpdateCompanionBuilder,
    (RoiPreset, $$RoiPresetsTableReferences),
    RoiPreset,
    PrefetchHooks Function({bool cameraId, bool countingLinesRefs})>;
typedef $$CountingLinesTableCreateCompanionBuilder = CountingLinesCompanion
    Function({
  required String id,
  required String presetId,
  required String cameraId,
  required String name,
  required double startX,
  required double startY,
  required double endX,
  required double endY,
  Value<String> direction,
  Value<String?> directionVectorJson,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$CountingLinesTableUpdateCompanionBuilder = CountingLinesCompanion
    Function({
  Value<String> id,
  Value<String> presetId,
  Value<String> cameraId,
  Value<String> name,
  Value<double> startX,
  Value<double> startY,
  Value<double> endX,
  Value<double> endY,
  Value<String> direction,
  Value<String?> directionVectorJson,
  Value<int> sortOrder,
  Value<int> rowid,
});

final class $$CountingLinesTableReferences
    extends BaseReferences<_$AppDatabase, $CountingLinesTable, CountingLine> {
  $$CountingLinesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $RoiPresetsTable _presetIdTable(_$AppDatabase db) =>
      db.roiPresets.createAlias(
          $_aliasNameGenerator(db.countingLines.presetId, db.roiPresets.id));

  $$RoiPresetsTableProcessedTableManager get presetId {
    final $_column = $_itemColumn<String>('preset_id')!;

    final manager = $$RoiPresetsTableTableManager($_db, $_db.roiPresets)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_presetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $CamerasTable _cameraIdTable(_$AppDatabase db) =>
      db.cameras.createAlias(
          $_aliasNameGenerator(db.countingLines.cameraId, db.cameras.id));

  $$CamerasTableProcessedTableManager get cameraId {
    final $_column = $_itemColumn<String>('camera_id')!;

    final manager = $$CamerasTableTableManager($_db, $_db.cameras)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cameraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$VehicleCrossingsTable, List<VehicleCrossing>>
      _vehicleCrossingsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.vehicleCrossings,
              aliasName: $_aliasNameGenerator(
                  db.countingLines.id, db.vehicleCrossings.lineId));

  $$VehicleCrossingsTableProcessedTableManager get vehicleCrossingsRefs {
    final manager =
        $$VehicleCrossingsTableTableManager($_db, $_db.vehicleCrossings)
            .filter((f) => f.lineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_vehicleCrossingsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AggVehicleCounts15mTable,
      List<AggVehicleCount15m>> _aggVehicleCounts15mRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.aggVehicleCounts15m,
          aliasName: $_aliasNameGenerator(
              db.countingLines.id, db.aggVehicleCounts15m.lineId));

  $$AggVehicleCounts15mTableProcessedTableManager get aggVehicleCounts15mRefs {
    final manager =
        $$AggVehicleCounts15mTableTableManager($_db, $_db.aggVehicleCounts15m)
            .filter((f) => f.lineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_aggVehicleCounts15mRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$CountingLinesTableFilterComposer
    extends Composer<_$AppDatabase, $CountingLinesTable> {
  $$CountingLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get startX => $composableBuilder(
      column: $table.startX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get startY => $composableBuilder(
      column: $table.startY, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get endX => $composableBuilder(
      column: $table.endX, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get endY => $composableBuilder(
      column: $table.endY, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directionVectorJson => $composableBuilder(
      column: $table.directionVectorJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  $$RoiPresetsTableFilterComposer get presetId {
    final $$RoiPresetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.presetId,
        referencedTable: $db.roiPresets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoiPresetsTableFilterComposer(
              $db: $db,
              $table: $db.roiPresets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CamerasTableFilterComposer get cameraId {
    final $$CamerasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableFilterComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> vehicleCrossingsRefs(
      Expression<bool> Function($$VehicleCrossingsTableFilterComposer f) f) {
    final $$VehicleCrossingsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vehicleCrossings,
        getReferencedColumn: (t) => t.lineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VehicleCrossingsTableFilterComposer(
              $db: $db,
              $table: $db.vehicleCrossings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> aggVehicleCounts15mRefs(
      Expression<bool> Function($$AggVehicleCounts15mTableFilterComposer f) f) {
    final $$AggVehicleCounts15mTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.aggVehicleCounts15m,
        getReferencedColumn: (t) => t.lineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AggVehicleCounts15mTableFilterComposer(
              $db: $db,
              $table: $db.aggVehicleCounts15m,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$CountingLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $CountingLinesTable> {
  $$CountingLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get startX => $composableBuilder(
      column: $table.startX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get startY => $composableBuilder(
      column: $table.startY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get endX => $composableBuilder(
      column: $table.endX, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get endY => $composableBuilder(
      column: $table.endY, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directionVectorJson => $composableBuilder(
      column: $table.directionVectorJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  $$RoiPresetsTableOrderingComposer get presetId {
    final $$RoiPresetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.presetId,
        referencedTable: $db.roiPresets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoiPresetsTableOrderingComposer(
              $db: $db,
              $table: $db.roiPresets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CamerasTableOrderingComposer get cameraId {
    final $$CamerasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableOrderingComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CountingLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountingLinesTable> {
  $$CountingLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get startX =>
      $composableBuilder(column: $table.startX, builder: (column) => column);

  GeneratedColumn<double> get startY =>
      $composableBuilder(column: $table.startY, builder: (column) => column);

  GeneratedColumn<double> get endX =>
      $composableBuilder(column: $table.endX, builder: (column) => column);

  GeneratedColumn<double> get endY =>
      $composableBuilder(column: $table.endY, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get directionVectorJson => $composableBuilder(
      column: $table.directionVectorJson, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$RoiPresetsTableAnnotationComposer get presetId {
    final $$RoiPresetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.presetId,
        referencedTable: $db.roiPresets,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoiPresetsTableAnnotationComposer(
              $db: $db,
              $table: $db.roiPresets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CamerasTableAnnotationComposer get cameraId {
    final $$CamerasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableAnnotationComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> vehicleCrossingsRefs<T extends Object>(
      Expression<T> Function($$VehicleCrossingsTableAnnotationComposer a) f) {
    final $$VehicleCrossingsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.vehicleCrossings,
        getReferencedColumn: (t) => t.lineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$VehicleCrossingsTableAnnotationComposer(
              $db: $db,
              $table: $db.vehicleCrossings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> aggVehicleCounts15mRefs<T extends Object>(
      Expression<T> Function($$AggVehicleCounts15mTableAnnotationComposer a)
          f) {
    final $$AggVehicleCounts15mTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.aggVehicleCounts15m,
            getReferencedColumn: (t) => t.lineId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$AggVehicleCounts15mTableAnnotationComposer(
                  $db: $db,
                  $table: $db.aggVehicleCounts15m,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$CountingLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CountingLinesTable,
    CountingLine,
    $$CountingLinesTableFilterComposer,
    $$CountingLinesTableOrderingComposer,
    $$CountingLinesTableAnnotationComposer,
    $$CountingLinesTableCreateCompanionBuilder,
    $$CountingLinesTableUpdateCompanionBuilder,
    (CountingLine, $$CountingLinesTableReferences),
    CountingLine,
    PrefetchHooks Function(
        {bool presetId,
        bool cameraId,
        bool vehicleCrossingsRefs,
        bool aggVehicleCounts15mRefs})> {
  $$CountingLinesTableTableManager(_$AppDatabase db, $CountingLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountingLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountingLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountingLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> presetId = const Value.absent(),
            Value<String> cameraId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> startX = const Value.absent(),
            Value<double> startY = const Value.absent(),
            Value<double> endX = const Value.absent(),
            Value<double> endY = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<String?> directionVectorJson = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CountingLinesCompanion(
            id: id,
            presetId: presetId,
            cameraId: cameraId,
            name: name,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            direction: direction,
            directionVectorJson: directionVectorJson,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String presetId,
            required String cameraId,
            required String name,
            required double startX,
            required double startY,
            required double endX,
            required double endY,
            Value<String> direction = const Value.absent(),
            Value<String?> directionVectorJson = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CountingLinesCompanion.insert(
            id: id,
            presetId: presetId,
            cameraId: cameraId,
            name: name,
            startX: startX,
            startY: startY,
            endX: endX,
            endY: endY,
            direction: direction,
            directionVectorJson: directionVectorJson,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CountingLinesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {presetId = false,
              cameraId = false,
              vehicleCrossingsRefs = false,
              aggVehicleCounts15mRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (vehicleCrossingsRefs) db.vehicleCrossings,
                if (aggVehicleCounts15mRefs) db.aggVehicleCounts15m
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (presetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.presetId,
                    referencedTable:
                        $$CountingLinesTableReferences._presetIdTable(db),
                    referencedColumn:
                        $$CountingLinesTableReferences._presetIdTable(db).id,
                  ) as T;
                }
                if (cameraId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.cameraId,
                    referencedTable:
                        $$CountingLinesTableReferences._cameraIdTable(db),
                    referencedColumn:
                        $$CountingLinesTableReferences._cameraIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (vehicleCrossingsRefs)
                    await $_getPrefetchedData<CountingLine, $CountingLinesTable,
                            VehicleCrossing>(
                        currentTable: table,
                        referencedTable: $$CountingLinesTableReferences
                            ._vehicleCrossingsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CountingLinesTableReferences(db, table, p0)
                                .vehicleCrossingsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.lineId == item.id),
                        typedResults: items),
                  if (aggVehicleCounts15mRefs)
                    await $_getPrefetchedData<CountingLine, $CountingLinesTable,
                            AggVehicleCount15m>(
                        currentTable: table,
                        referencedTable: $$CountingLinesTableReferences
                            ._aggVehicleCounts15mRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$CountingLinesTableReferences(db, table, p0)
                                .aggVehicleCounts15mRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.lineId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$CountingLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CountingLinesTable,
    CountingLine,
    $$CountingLinesTableFilterComposer,
    $$CountingLinesTableOrderingComposer,
    $$CountingLinesTableAnnotationComposer,
    $$CountingLinesTableCreateCompanionBuilder,
    $$CountingLinesTableUpdateCompanionBuilder,
    (CountingLine, $$CountingLinesTableReferences),
    CountingLine,
    PrefetchHooks Function(
        {bool presetId,
        bool cameraId,
        bool vehicleCrossingsRefs,
        bool aggVehicleCounts15mRefs})>;
typedef $$VehicleCrossingsTableCreateCompanionBuilder
    = VehicleCrossingsCompanion Function({
  required String id,
  required String cameraId,
  required String lineId,
  required String trackId,
  Value<int> crossingSeq,
  required int class12,
  required double confidence,
  required String direction,
  required int frameIndex,
  Value<double?> speedEstimateKmh,
  Value<String?> bboxJson,
  required DateTime timestampUtc,
  Value<DateTime> ingestedAt,
  Value<int?> vlmClassCode,
  Value<double?> vlmConfidence,
  Value<String> classificationSource,
  Value<int> rowid,
});
typedef $$VehicleCrossingsTableUpdateCompanionBuilder
    = VehicleCrossingsCompanion Function({
  Value<String> id,
  Value<String> cameraId,
  Value<String> lineId,
  Value<String> trackId,
  Value<int> crossingSeq,
  Value<int> class12,
  Value<double> confidence,
  Value<String> direction,
  Value<int> frameIndex,
  Value<double?> speedEstimateKmh,
  Value<String?> bboxJson,
  Value<DateTime> timestampUtc,
  Value<DateTime> ingestedAt,
  Value<int?> vlmClassCode,
  Value<double?> vlmConfidence,
  Value<String> classificationSource,
  Value<int> rowid,
});

final class $$VehicleCrossingsTableReferences extends BaseReferences<
    _$AppDatabase, $VehicleCrossingsTable, VehicleCrossing> {
  $$VehicleCrossingsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CamerasTable _cameraIdTable(_$AppDatabase db) =>
      db.cameras.createAlias(
          $_aliasNameGenerator(db.vehicleCrossings.cameraId, db.cameras.id));

  $$CamerasTableProcessedTableManager get cameraId {
    final $_column = $_itemColumn<String>('camera_id')!;

    final manager = $$CamerasTableTableManager($_db, $_db.cameras)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cameraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $CountingLinesTable _lineIdTable(_$AppDatabase db) =>
      db.countingLines.createAlias($_aliasNameGenerator(
          db.vehicleCrossings.lineId, db.countingLines.id));

  $$CountingLinesTableProcessedTableManager get lineId {
    final $_column = $_itemColumn<String>('line_id')!;

    final manager = $$CountingLinesTableTableManager($_db, $_db.countingLines)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$VehicleCrossingsTableFilterComposer
    extends Composer<_$AppDatabase, $VehicleCrossingsTable> {
  $$VehicleCrossingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get crossingSeq => $composableBuilder(
      column: $table.crossingSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get class12 => $composableBuilder(
      column: $table.class12, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get frameIndex => $composableBuilder(
      column: $table.frameIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speedEstimateKmh => $composableBuilder(
      column: $table.speedEstimateKmh,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bboxJson => $composableBuilder(
      column: $table.bboxJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get ingestedAt => $composableBuilder(
      column: $table.ingestedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vlmClassCode => $composableBuilder(
      column: $table.vlmClassCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get vlmConfidence => $composableBuilder(
      column: $table.vlmConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get classificationSource => $composableBuilder(
      column: $table.classificationSource,
      builder: (column) => ColumnFilters(column));

  $$CamerasTableFilterComposer get cameraId {
    final $$CamerasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableFilterComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableFilterComposer get lineId {
    final $$CountingLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableFilterComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VehicleCrossingsTableOrderingComposer
    extends Composer<_$AppDatabase, $VehicleCrossingsTable> {
  $$VehicleCrossingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trackId => $composableBuilder(
      column: $table.trackId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get crossingSeq => $composableBuilder(
      column: $table.crossingSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get class12 => $composableBuilder(
      column: $table.class12, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get frameIndex => $composableBuilder(
      column: $table.frameIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speedEstimateKmh => $composableBuilder(
      column: $table.speedEstimateKmh,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bboxJson => $composableBuilder(
      column: $table.bboxJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get ingestedAt => $composableBuilder(
      column: $table.ingestedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vlmClassCode => $composableBuilder(
      column: $table.vlmClassCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get vlmConfidence => $composableBuilder(
      column: $table.vlmConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get classificationSource => $composableBuilder(
      column: $table.classificationSource,
      builder: (column) => ColumnOrderings(column));

  $$CamerasTableOrderingComposer get cameraId {
    final $$CamerasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableOrderingComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableOrderingComposer get lineId {
    final $$CountingLinesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableOrderingComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VehicleCrossingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehicleCrossingsTable> {
  $$VehicleCrossingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<int> get crossingSeq => $composableBuilder(
      column: $table.crossingSeq, builder: (column) => column);

  GeneratedColumn<int> get class12 =>
      $composableBuilder(column: $table.class12, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get frameIndex => $composableBuilder(
      column: $table.frameIndex, builder: (column) => column);

  GeneratedColumn<double> get speedEstimateKmh => $composableBuilder(
      column: $table.speedEstimateKmh, builder: (column) => column);

  GeneratedColumn<String> get bboxJson =>
      $composableBuilder(column: $table.bboxJson, builder: (column) => column);

  GeneratedColumn<DateTime> get timestampUtc => $composableBuilder(
      column: $table.timestampUtc, builder: (column) => column);

  GeneratedColumn<DateTime> get ingestedAt => $composableBuilder(
      column: $table.ingestedAt, builder: (column) => column);

  GeneratedColumn<int> get vlmClassCode => $composableBuilder(
      column: $table.vlmClassCode, builder: (column) => column);

  GeneratedColumn<double> get vlmConfidence => $composableBuilder(
      column: $table.vlmConfidence, builder: (column) => column);

  GeneratedColumn<String> get classificationSource => $composableBuilder(
      column: $table.classificationSource, builder: (column) => column);

  $$CamerasTableAnnotationComposer get cameraId {
    final $$CamerasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableAnnotationComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableAnnotationComposer get lineId {
    final $$CountingLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$VehicleCrossingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $VehicleCrossingsTable,
    VehicleCrossing,
    $$VehicleCrossingsTableFilterComposer,
    $$VehicleCrossingsTableOrderingComposer,
    $$VehicleCrossingsTableAnnotationComposer,
    $$VehicleCrossingsTableCreateCompanionBuilder,
    $$VehicleCrossingsTableUpdateCompanionBuilder,
    (VehicleCrossing, $$VehicleCrossingsTableReferences),
    VehicleCrossing,
    PrefetchHooks Function({bool cameraId, bool lineId})> {
  $$VehicleCrossingsTableTableManager(
      _$AppDatabase db, $VehicleCrossingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehicleCrossingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehicleCrossingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehicleCrossingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> cameraId = const Value.absent(),
            Value<String> lineId = const Value.absent(),
            Value<String> trackId = const Value.absent(),
            Value<int> crossingSeq = const Value.absent(),
            Value<int> class12 = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<int> frameIndex = const Value.absent(),
            Value<double?> speedEstimateKmh = const Value.absent(),
            Value<String?> bboxJson = const Value.absent(),
            Value<DateTime> timestampUtc = const Value.absent(),
            Value<DateTime> ingestedAt = const Value.absent(),
            Value<int?> vlmClassCode = const Value.absent(),
            Value<double?> vlmConfidence = const Value.absent(),
            Value<String> classificationSource = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VehicleCrossingsCompanion(
            id: id,
            cameraId: cameraId,
            lineId: lineId,
            trackId: trackId,
            crossingSeq: crossingSeq,
            class12: class12,
            confidence: confidence,
            direction: direction,
            frameIndex: frameIndex,
            speedEstimateKmh: speedEstimateKmh,
            bboxJson: bboxJson,
            timestampUtc: timestampUtc,
            ingestedAt: ingestedAt,
            vlmClassCode: vlmClassCode,
            vlmConfidence: vlmConfidence,
            classificationSource: classificationSource,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String cameraId,
            required String lineId,
            required String trackId,
            Value<int> crossingSeq = const Value.absent(),
            required int class12,
            required double confidence,
            required String direction,
            required int frameIndex,
            Value<double?> speedEstimateKmh = const Value.absent(),
            Value<String?> bboxJson = const Value.absent(),
            required DateTime timestampUtc,
            Value<DateTime> ingestedAt = const Value.absent(),
            Value<int?> vlmClassCode = const Value.absent(),
            Value<double?> vlmConfidence = const Value.absent(),
            Value<String> classificationSource = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              VehicleCrossingsCompanion.insert(
            id: id,
            cameraId: cameraId,
            lineId: lineId,
            trackId: trackId,
            crossingSeq: crossingSeq,
            class12: class12,
            confidence: confidence,
            direction: direction,
            frameIndex: frameIndex,
            speedEstimateKmh: speedEstimateKmh,
            bboxJson: bboxJson,
            timestampUtc: timestampUtc,
            ingestedAt: ingestedAt,
            vlmClassCode: vlmClassCode,
            vlmConfidence: vlmConfidence,
            classificationSource: classificationSource,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$VehicleCrossingsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({cameraId = false, lineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (cameraId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.cameraId,
                    referencedTable:
                        $$VehicleCrossingsTableReferences._cameraIdTable(db),
                    referencedColumn:
                        $$VehicleCrossingsTableReferences._cameraIdTable(db).id,
                  ) as T;
                }
                if (lineId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.lineId,
                    referencedTable:
                        $$VehicleCrossingsTableReferences._lineIdTable(db),
                    referencedColumn:
                        $$VehicleCrossingsTableReferences._lineIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$VehicleCrossingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $VehicleCrossingsTable,
    VehicleCrossing,
    $$VehicleCrossingsTableFilterComposer,
    $$VehicleCrossingsTableOrderingComposer,
    $$VehicleCrossingsTableAnnotationComposer,
    $$VehicleCrossingsTableCreateCompanionBuilder,
    $$VehicleCrossingsTableUpdateCompanionBuilder,
    (VehicleCrossing, $$VehicleCrossingsTableReferences),
    VehicleCrossing,
    PrefetchHooks Function({bool cameraId, bool lineId})>;
typedef $$AggVehicleCounts15mTableCreateCompanionBuilder
    = AggVehicleCounts15mCompanion Function({
  required String id,
  required String cameraId,
  required String lineId,
  required DateTime bucketStart,
  required int class12,
  required String direction,
  Value<int> count,
  Value<double> sumConfidence,
  Value<double> sumSpeedKmh,
  Value<double?> minSpeedKmh,
  Value<double?> maxSpeedKmh,
  Value<DateTime> lastUpdatedAt,
  Value<int> rowid,
});
typedef $$AggVehicleCounts15mTableUpdateCompanionBuilder
    = AggVehicleCounts15mCompanion Function({
  Value<String> id,
  Value<String> cameraId,
  Value<String> lineId,
  Value<DateTime> bucketStart,
  Value<int> class12,
  Value<String> direction,
  Value<int> count,
  Value<double> sumConfidence,
  Value<double> sumSpeedKmh,
  Value<double?> minSpeedKmh,
  Value<double?> maxSpeedKmh,
  Value<DateTime> lastUpdatedAt,
  Value<int> rowid,
});

final class $$AggVehicleCounts15mTableReferences extends BaseReferences<
    _$AppDatabase, $AggVehicleCounts15mTable, AggVehicleCount15m> {
  $$AggVehicleCounts15mTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $CamerasTable _cameraIdTable(_$AppDatabase db) =>
      db.cameras.createAlias(
          $_aliasNameGenerator(db.aggVehicleCounts15m.cameraId, db.cameras.id));

  $$CamerasTableProcessedTableManager get cameraId {
    final $_column = $_itemColumn<String>('camera_id')!;

    final manager = $$CamerasTableTableManager($_db, $_db.cameras)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cameraIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $CountingLinesTable _lineIdTable(_$AppDatabase db) =>
      db.countingLines.createAlias($_aliasNameGenerator(
          db.aggVehicleCounts15m.lineId, db.countingLines.id));

  $$CountingLinesTableProcessedTableManager get lineId {
    final $_column = $_itemColumn<String>('line_id')!;

    final manager = $$CountingLinesTableTableManager($_db, $_db.countingLines)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AggVehicleCounts15mTableFilterComposer
    extends Composer<_$AppDatabase, $AggVehicleCounts15mTable> {
  $$AggVehicleCounts15mTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get bucketStart => $composableBuilder(
      column: $table.bucketStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get class12 => $composableBuilder(
      column: $table.class12, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sumConfidence => $composableBuilder(
      column: $table.sumConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sumSpeedKmh => $composableBuilder(
      column: $table.sumSpeedKmh, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get minSpeedKmh => $composableBuilder(
      column: $table.minSpeedKmh, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get maxSpeedKmh => $composableBuilder(
      column: $table.maxSpeedKmh, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt, builder: (column) => ColumnFilters(column));

  $$CamerasTableFilterComposer get cameraId {
    final $$CamerasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableFilterComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableFilterComposer get lineId {
    final $$CountingLinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableFilterComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AggVehicleCounts15mTableOrderingComposer
    extends Composer<_$AppDatabase, $AggVehicleCounts15mTable> {
  $$AggVehicleCounts15mTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get bucketStart => $composableBuilder(
      column: $table.bucketStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get class12 => $composableBuilder(
      column: $table.class12, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sumConfidence => $composableBuilder(
      column: $table.sumConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sumSpeedKmh => $composableBuilder(
      column: $table.sumSpeedKmh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get minSpeedKmh => $composableBuilder(
      column: $table.minSpeedKmh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get maxSpeedKmh => $composableBuilder(
      column: $table.maxSpeedKmh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  $$CamerasTableOrderingComposer get cameraId {
    final $$CamerasTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableOrderingComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableOrderingComposer get lineId {
    final $$CountingLinesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableOrderingComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AggVehicleCounts15mTableAnnotationComposer
    extends Composer<_$AppDatabase, $AggVehicleCounts15mTable> {
  $$AggVehicleCounts15mTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get bucketStart => $composableBuilder(
      column: $table.bucketStart, builder: (column) => column);

  GeneratedColumn<int> get class12 =>
      $composableBuilder(column: $table.class12, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<double> get sumConfidence => $composableBuilder(
      column: $table.sumConfidence, builder: (column) => column);

  GeneratedColumn<double> get sumSpeedKmh => $composableBuilder(
      column: $table.sumSpeedKmh, builder: (column) => column);

  GeneratedColumn<double> get minSpeedKmh => $composableBuilder(
      column: $table.minSpeedKmh, builder: (column) => column);

  GeneratedColumn<double> get maxSpeedKmh => $composableBuilder(
      column: $table.maxSpeedKmh, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdatedAt => $composableBuilder(
      column: $table.lastUpdatedAt, builder: (column) => column);

  $$CamerasTableAnnotationComposer get cameraId {
    final $$CamerasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.cameraId,
        referencedTable: $db.cameras,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CamerasTableAnnotationComposer(
              $db: $db,
              $table: $db.cameras,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$CountingLinesTableAnnotationComposer get lineId {
    final $$CountingLinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.lineId,
        referencedTable: $db.countingLines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CountingLinesTableAnnotationComposer(
              $db: $db,
              $table: $db.countingLines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AggVehicleCounts15mTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AggVehicleCounts15mTable,
    AggVehicleCount15m,
    $$AggVehicleCounts15mTableFilterComposer,
    $$AggVehicleCounts15mTableOrderingComposer,
    $$AggVehicleCounts15mTableAnnotationComposer,
    $$AggVehicleCounts15mTableCreateCompanionBuilder,
    $$AggVehicleCounts15mTableUpdateCompanionBuilder,
    (AggVehicleCount15m, $$AggVehicleCounts15mTableReferences),
    AggVehicleCount15m,
    PrefetchHooks Function({bool cameraId, bool lineId})> {
  $$AggVehicleCounts15mTableTableManager(
      _$AppDatabase db, $AggVehicleCounts15mTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AggVehicleCounts15mTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AggVehicleCounts15mTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AggVehicleCounts15mTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> cameraId = const Value.absent(),
            Value<String> lineId = const Value.absent(),
            Value<DateTime> bucketStart = const Value.absent(),
            Value<int> class12 = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<double> sumConfidence = const Value.absent(),
            Value<double> sumSpeedKmh = const Value.absent(),
            Value<double?> minSpeedKmh = const Value.absent(),
            Value<double?> maxSpeedKmh = const Value.absent(),
            Value<DateTime> lastUpdatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AggVehicleCounts15mCompanion(
            id: id,
            cameraId: cameraId,
            lineId: lineId,
            bucketStart: bucketStart,
            class12: class12,
            direction: direction,
            count: count,
            sumConfidence: sumConfidence,
            sumSpeedKmh: sumSpeedKmh,
            minSpeedKmh: minSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            lastUpdatedAt: lastUpdatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String cameraId,
            required String lineId,
            required DateTime bucketStart,
            required int class12,
            required String direction,
            Value<int> count = const Value.absent(),
            Value<double> sumConfidence = const Value.absent(),
            Value<double> sumSpeedKmh = const Value.absent(),
            Value<double?> minSpeedKmh = const Value.absent(),
            Value<double?> maxSpeedKmh = const Value.absent(),
            Value<DateTime> lastUpdatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AggVehicleCounts15mCompanion.insert(
            id: id,
            cameraId: cameraId,
            lineId: lineId,
            bucketStart: bucketStart,
            class12: class12,
            direction: direction,
            count: count,
            sumConfidence: sumConfidence,
            sumSpeedKmh: sumSpeedKmh,
            minSpeedKmh: minSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            lastUpdatedAt: lastUpdatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AggVehicleCounts15mTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({cameraId = false, lineId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (cameraId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.cameraId,
                    referencedTable:
                        $$AggVehicleCounts15mTableReferences._cameraIdTable(db),
                    referencedColumn: $$AggVehicleCounts15mTableReferences
                        ._cameraIdTable(db)
                        .id,
                  ) as T;
                }
                if (lineId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.lineId,
                    referencedTable:
                        $$AggVehicleCounts15mTableReferences._lineIdTable(db),
                    referencedColumn: $$AggVehicleCounts15mTableReferences
                        ._lineIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AggVehicleCounts15mTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AggVehicleCounts15mTable,
    AggVehicleCount15m,
    $$AggVehicleCounts15mTableFilterComposer,
    $$AggVehicleCounts15mTableOrderingComposer,
    $$AggVehicleCounts15mTableAnnotationComposer,
    $$AggVehicleCounts15mTableCreateCompanionBuilder,
    $$AggVehicleCounts15mTableUpdateCompanionBuilder,
    (AggVehicleCount15m, $$AggVehicleCounts15mTableReferences),
    AggVehicleCount15m,
    PrefetchHooks Function({bool cameraId, bool lineId})>;
typedef $$ManualClassificationsTableCreateCompanionBuilder
    = ManualClassificationsCompanion Function({
  required String id,
  required String imagePath,
  required int stage1Class,
  required double stage1Confidence,
  Value<int> wheelCount,
  Value<int> jointCount,
  Value<int> axleCount,
  Value<bool> hasTrailer,
  required int finalClass12,
  required double finalConfidence,
  Value<String?> bboxJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ManualClassificationsTableUpdateCompanionBuilder
    = ManualClassificationsCompanion Function({
  Value<String> id,
  Value<String> imagePath,
  Value<int> stage1Class,
  Value<double> stage1Confidence,
  Value<int> wheelCount,
  Value<int> jointCount,
  Value<int> axleCount,
  Value<bool> hasTrailer,
  Value<int> finalClass12,
  Value<double> finalConfidence,
  Value<String?> bboxJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ManualClassificationsTableFilterComposer
    extends Composer<_$AppDatabase, $ManualClassificationsTable> {
  $$ManualClassificationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stage1Class => $composableBuilder(
      column: $table.stage1Class, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stage1Confidence => $composableBuilder(
      column: $table.stage1Confidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wheelCount => $composableBuilder(
      column: $table.wheelCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get jointCount => $composableBuilder(
      column: $table.jointCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get axleCount => $composableBuilder(
      column: $table.axleCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasTrailer => $composableBuilder(
      column: $table.hasTrailer, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get finalClass12 => $composableBuilder(
      column: $table.finalClass12, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get finalConfidence => $composableBuilder(
      column: $table.finalConfidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bboxJson => $composableBuilder(
      column: $table.bboxJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ManualClassificationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ManualClassificationsTable> {
  $$ManualClassificationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stage1Class => $composableBuilder(
      column: $table.stage1Class, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stage1Confidence => $composableBuilder(
      column: $table.stage1Confidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wheelCount => $composableBuilder(
      column: $table.wheelCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get jointCount => $composableBuilder(
      column: $table.jointCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get axleCount => $composableBuilder(
      column: $table.axleCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasTrailer => $composableBuilder(
      column: $table.hasTrailer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get finalClass12 => $composableBuilder(
      column: $table.finalClass12,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get finalConfidence => $composableBuilder(
      column: $table.finalConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bboxJson => $composableBuilder(
      column: $table.bboxJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ManualClassificationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ManualClassificationsTable> {
  $$ManualClassificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get stage1Class => $composableBuilder(
      column: $table.stage1Class, builder: (column) => column);

  GeneratedColumn<double> get stage1Confidence => $composableBuilder(
      column: $table.stage1Confidence, builder: (column) => column);

  GeneratedColumn<int> get wheelCount => $composableBuilder(
      column: $table.wheelCount, builder: (column) => column);

  GeneratedColumn<int> get jointCount => $composableBuilder(
      column: $table.jointCount, builder: (column) => column);

  GeneratedColumn<int> get axleCount =>
      $composableBuilder(column: $table.axleCount, builder: (column) => column);

  GeneratedColumn<bool> get hasTrailer => $composableBuilder(
      column: $table.hasTrailer, builder: (column) => column);

  GeneratedColumn<int> get finalClass12 => $composableBuilder(
      column: $table.finalClass12, builder: (column) => column);

  GeneratedColumn<double> get finalConfidence => $composableBuilder(
      column: $table.finalConfidence, builder: (column) => column);

  GeneratedColumn<String> get bboxJson =>
      $composableBuilder(column: $table.bboxJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ManualClassificationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ManualClassificationsTable,
    ManualClassification,
    $$ManualClassificationsTableFilterComposer,
    $$ManualClassificationsTableOrderingComposer,
    $$ManualClassificationsTableAnnotationComposer,
    $$ManualClassificationsTableCreateCompanionBuilder,
    $$ManualClassificationsTableUpdateCompanionBuilder,
    (
      ManualClassification,
      BaseReferences<_$AppDatabase, $ManualClassificationsTable,
          ManualClassification>
    ),
    ManualClassification,
    PrefetchHooks Function()> {
  $$ManualClassificationsTableTableManager(
      _$AppDatabase db, $ManualClassificationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ManualClassificationsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ManualClassificationsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ManualClassificationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<int> stage1Class = const Value.absent(),
            Value<double> stage1Confidence = const Value.absent(),
            Value<int> wheelCount = const Value.absent(),
            Value<int> jointCount = const Value.absent(),
            Value<int> axleCount = const Value.absent(),
            Value<bool> hasTrailer = const Value.absent(),
            Value<int> finalClass12 = const Value.absent(),
            Value<double> finalConfidence = const Value.absent(),
            Value<String?> bboxJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ManualClassificationsCompanion(
            id: id,
            imagePath: imagePath,
            stage1Class: stage1Class,
            stage1Confidence: stage1Confidence,
            wheelCount: wheelCount,
            jointCount: jointCount,
            axleCount: axleCount,
            hasTrailer: hasTrailer,
            finalClass12: finalClass12,
            finalConfidence: finalConfidence,
            bboxJson: bboxJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String imagePath,
            required int stage1Class,
            required double stage1Confidence,
            Value<int> wheelCount = const Value.absent(),
            Value<int> jointCount = const Value.absent(),
            Value<int> axleCount = const Value.absent(),
            Value<bool> hasTrailer = const Value.absent(),
            required int finalClass12,
            required double finalConfidence,
            Value<String?> bboxJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ManualClassificationsCompanion.insert(
            id: id,
            imagePath: imagePath,
            stage1Class: stage1Class,
            stage1Confidence: stage1Confidence,
            wheelCount: wheelCount,
            jointCount: jointCount,
            axleCount: axleCount,
            hasTrailer: hasTrailer,
            finalClass12: finalClass12,
            finalConfidence: finalConfidence,
            bboxJson: bboxJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ManualClassificationsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ManualClassificationsTable,
        ManualClassification,
        $$ManualClassificationsTableFilterComposer,
        $$ManualClassificationsTableOrderingComposer,
        $$ManualClassificationsTableAnnotationComposer,
        $$ManualClassificationsTableCreateCompanionBuilder,
        $$ManualClassificationsTableUpdateCompanionBuilder,
        (
          ManualClassification,
          BaseReferences<_$AppDatabase, $ManualClassificationsTable,
              ManualClassification>
        ),
        ManualClassification,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SitesTableTableManager get sites =>
      $$SitesTableTableManager(_db, _db.sites);
  $$CamerasTableTableManager get cameras =>
      $$CamerasTableTableManager(_db, _db.cameras);
  $$RoiPresetsTableTableManager get roiPresets =>
      $$RoiPresetsTableTableManager(_db, _db.roiPresets);
  $$CountingLinesTableTableManager get countingLines =>
      $$CountingLinesTableTableManager(_db, _db.countingLines);
  $$VehicleCrossingsTableTableManager get vehicleCrossings =>
      $$VehicleCrossingsTableTableManager(_db, _db.vehicleCrossings);
  $$AggVehicleCounts15mTableTableManager get aggVehicleCounts15m =>
      $$AggVehicleCounts15mTableTableManager(_db, _db.aggVehicleCounts15m);
  $$ManualClassificationsTableTableManager get manualClassifications =>
      $$ManualClassificationsTableTableManager(_db, _db.manualClassifications);
}
