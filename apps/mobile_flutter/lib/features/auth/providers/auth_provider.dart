import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/features/auth/models/auth_state.dart';

export 'package:greyeye_mobile/features/auth/models/auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial);

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      // TODO: replace with real API call
      await Future<void>.delayed(const Duration(seconds: 1));
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(
          id: 'usr_001',
          email: email,
          name: email.split('@').first,
        ),
        tokens: const AuthTokens(
          accessToken: 'mock_access',
          refreshToken: 'mock_refresh',
        ),
      );
    } on Exception catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await Future<void>.delayed(const Duration(seconds: 1));
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: AuthUser(id: 'usr_002', email: email, name: name),
        tokens: const AuthTokens(
          accessToken: 'mock_access',
          refreshToken: 'mock_refresh',
        ),
      );
    } on Exception catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future<void>.delayed(const Duration(seconds: 1));
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
