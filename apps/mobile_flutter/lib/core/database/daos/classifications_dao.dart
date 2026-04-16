import 'package:drift/drift.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/tables.dart';

part 'classifications_dao.g.dart';

@DriftAccessor(tables: [ManualClassifications])
class ClassificationsDao extends DatabaseAccessor<AppDatabase>
    with _$ClassificationsDaoMixin {
  ClassificationsDao(super.db);

  Future<int> insertClassification(ManualClassificationsCompanion entry) =>
      into(manualClassifications).insert(entry);

  Future<List<ManualClassification>> allClassifications({int? limit}) {
    final query = select(manualClassifications)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Stream<List<ManualClassification>> watchClassifications({int limit = 50}) =>
      (select(manualClassifications)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .watch();

  Future<int> deleteClassification(String id) =>
      (delete(manualClassifications)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAll() => delete(manualClassifications).go();
}
