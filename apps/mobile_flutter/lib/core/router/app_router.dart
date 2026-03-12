import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/router/shell_scaffold.dart';
import 'package:greyeye_mobile/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:greyeye_mobile/features/analytics/screens/report_export_screen.dart';
import 'package:greyeye_mobile/features/auth/providers/auth_provider.dart';
import 'package:greyeye_mobile/features/auth/screens/login_screen.dart';
import 'package:greyeye_mobile/features/auth/screens/register_screen.dart';
import 'package:greyeye_mobile/features/camera/screens/add_camera_screen.dart';
import 'package:greyeye_mobile/features/camera/screens/camera_list_screen.dart';
import 'package:greyeye_mobile/features/camera/screens/camera_settings_screen.dart';
import 'package:greyeye_mobile/features/monitor/screens/live_monitor_screen.dart';
import 'package:greyeye_mobile/features/onboarding/screens/quick_setup_screen.dart';
import 'package:greyeye_mobile/features/roi/screens/roi_editor_screen.dart';
import 'package:greyeye_mobile/features/roi/screens/roi_preset_manager_screen.dart';
import 'package:greyeye_mobile/features/settings/screens/settings_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/create_edit_site_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/home_screen.dart';
import 'package:greyeye_mobile/features/sites/screens/site_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      if (!ApiConstants.authEnabled) return null;

      final isAuth = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const QuickSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'sites/new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const CreateEditSiteScreen(),
              ),
              GoRoute(
                path: 'sites/:siteId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => SiteDetailScreen(
                  siteId: state.pathParameters['siteId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => CreateEditSiteScreen(
                      siteId: state.pathParameters['siteId'],
                    ),
                  ),
                  GoRoute(
                    path: 'cameras',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => CameraListScreen(
                      siteId: state.pathParameters['siteId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => AddCameraScreen(
                          siteId: state.pathParameters['siteId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/cameras/:cameraId/settings',
        builder: (context, state) => CameraSettingsScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
      GoRoute(
        path: '/cameras/:cameraId/roi',
        builder: (context, state) => RoiEditorScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
      GoRoute(
        path: '/cameras/:cameraId/roi-presets',
        builder: (context, state) => RoiPresetManagerScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
      GoRoute(
        path: '/cameras/:cameraId/monitor',
        builder: (context, state) => LiveMonitorScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
      GoRoute(
        path: '/cameras/:cameraId/analytics',
        builder: (context, state) => AnalyticsDashboardScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
      GoRoute(
        path: '/cameras/:cameraId/export',
        builder: (context, state) => ReportExportScreen(
          cameraId: state.pathParameters['cameraId']!,
        ),
      ),
    ],
  );
});
