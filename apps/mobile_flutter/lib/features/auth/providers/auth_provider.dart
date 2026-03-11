import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/features/auth/models/auth_state.dart';

export 'package:greyeye_mobile/features/auth/models/auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  String _extractError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        final nestedError = data['error'];
        if (nestedError is Map<String, dynamic>) {
          final message = nestedError['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
        }
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  AuthState _authenticatedState(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>? ?? const {};
    return state.copyWith(
      status: AuthStatus.authenticated,
      user: AuthUser(
        id: user['id'] as String? ?? '',
        email: user['email'] as String? ?? '',
        name: user['name'] as String? ?? '',
      ),
      tokens: AuthTokens(
        accessToken: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? '',
      ),
      errorMessage: null,
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authLogin,
        data: {
          'email': email,
          'password': password,
        },
      );
      state = _authenticatedState(response.data ?? const {});
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? orgName,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authRegister,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'org_name': (orgName != null && orgName.trim().isNotEmpty)
              ? orgName.trim()
              : '$name Organization',
        },
      );
      state = _authenticatedState(response.data ?? const {});
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
    }
  }

  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(
      status: AuthStatus.error,
      errorMessage: 'Password reset is not implemented in the mobile client yet.',
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
