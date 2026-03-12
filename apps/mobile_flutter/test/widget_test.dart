import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/auth/providers/auth_provider.dart';
import 'package:greyeye_mobile/main.dart';

class _FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FakeAuthNotifier()
      : super(const AuthState(status: AuthStatus.unauthenticated));

  @override
  Future<void> login({required String email, required String password}) async {}
  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('app bootstraps', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((_) => _FakeAuthNotifier()),
        ],
        child: const GreyEyeApp(),
      ),
    );

    expect(find.byType(GreyEyeApp), findsOneWidget);
  });
}
