import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sitesDaoProvider = Provider((ref) => ref.watch(databaseProvider).sitesDao);
final camerasDaoProvider = Provider((ref) => ref.watch(databaseProvider).camerasDao);
final roiDaoProvider = Provider((ref) => ref.watch(databaseProvider).roiDao);
final crossingsDaoProvider = Provider((ref) => ref.watch(databaseProvider).crossingsDao);
