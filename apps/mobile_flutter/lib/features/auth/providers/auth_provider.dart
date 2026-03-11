import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/features/auth/models/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

export 'package:greyeye_mobile/features/auth/models/auth_state.dart';

AuthUser _mapUser(sb.User user) {
  final meta = user.userMetadata;
  return AuthUser(
    id: user.id,
    email: user.email ?? '',
    name: meta?['name'] as String?,
    avatarUrl: meta?['avatar_url'] as String?,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial) {
    _init();
  }

  final sb.SupabaseClient _client = sb.Supabase.instance.client;
  StreamSubscription<sb.AuthState>? _authSub;

  void _init() {
    final session = _client.auth.currentSession;
    if (session != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: _mapUser(session.user),
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _authSub = _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: _mapUser(session.user),
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
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
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _client.auth.resetPasswordForEmail(email);
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } on sb.AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
