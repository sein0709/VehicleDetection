abstract final class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'GREYEYE_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'GREYEYE_WS_BASE_URL',
    defaultValue: 'ws://localhost:8080',
  );

  static const String authLogin = '/v1/auth/login';
  static const String authRegister = '/v1/auth/register';
  static const String authRefresh = '/v1/auth/refresh';
  static const String authLogout = '/v1/auth/logout';
  static const String usersMe = '/v1/users/me';

  static const String sites = '/v1/sites';
  static String site(String id) => '/v1/sites/$id';
  static String siteCameras(String siteId) => '/v1/sites/$siteId/cameras';

  static String camera(String id) => '/v1/cameras/$id';
  static String cameraStatus(String id) => '/v1/cameras/$id/status';
  static String cameraRoiPresets(String cameraId) =>
      '/v1/cameras/$cameraId/roi-presets';

  static String roiPreset(String id) => '/v1/roi-presets/$id';
  static String activateRoiPreset(String id) => '/v1/roi-presets/$id/activate';

  static const String ingestFrames = '/v1/ingest/frames';
  static const String ingestHeartbeat = '/v1/ingest/heartbeat';

  static const String analytics15m = '/v1/analytics/15m';
  static const String analyticsKpi = '/v1/analytics/kpi';
  static const String analyticsLive = '/v1/analytics/live';
  static const String analyticsLiveWs = '/v1/analytics/live/ws';

  static const String reportsExport = '/v1/reports/export';
  static String reportsExportDownload(String id) => '/v1/reports/export/$id';
  static const String reportsShare = '/v1/reports/share';

  static const String alertRules = '/v1/alerts/rules';
  static String alertRule(String id) => '/v1/alerts/rules/$id';
  static const String alerts = '/v1/alerts';
  static String alertAcknowledge(String id) => '/v1/alerts/$id/acknowledge';
  static String alertAssign(String id) => '/v1/alerts/$id/assign';
  static String alertResolve(String id) => '/v1/alerts/$id/resolve';
}
