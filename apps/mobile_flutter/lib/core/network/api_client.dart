/// Legacy API client — retained for reference but no longer used.
///
/// All features now use local Drift/SQLite for data and Supabase for auth.
/// This file can be safely deleted once the alerts feature is removed.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
  }) =>
      _dio.post(path, data: data);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
  }) =>
      _dio.patch(path, data: data);

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
  }) =>
      _dio.put(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete(path);
}
