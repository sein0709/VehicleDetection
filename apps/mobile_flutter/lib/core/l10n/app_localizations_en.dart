// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GreyEye';

  @override
  String get appTagline => 'Intelligent Traffic Monitoring';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginEmail => 'Email address';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginInvalidCredentials => 'Invalid email or password';

  @override
  String get loginFieldRequired => 'This field is required';

  @override
  String get loginInvalidEmail => 'Enter a valid email address';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerName => 'Full name';

  @override
  String get registerEmail => 'Email address';

  @override
  String get registerPassword => 'Password';

  @override
  String get registerConfirmPassword => 'Confirm password';

  @override
  String get registerOrganization => 'Organization';

  @override
  String get registerButton => 'Create Account';

  @override
  String get registerPasswordMismatch => 'Passwords do not match';

  @override
  String get registerAlreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get setupTitle => 'Initial Setup';

  @override
  String get setupWelcome => 'Welcome to GreyEye';

  @override
  String get setupAddSite => 'Add your first monitoring site';

  @override
  String get setupComplete => 'Complete Setup';

  @override
  String get navHome => 'Home';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeTitle => 'Dashboard';

  @override
  String get homeSites => 'Sites';

  @override
  String get homeActiveCameras => 'Active Cameras';

  @override
  String get homeTotalVehicles => 'Total Vehicles';

  @override
  String get homeAlertCount => 'Active Alerts';

  @override
  String get homeRecentActivity => 'Recent Activity';

  @override
  String get homeNoSites => 'No monitoring sites configured';

  @override
  String get homeAddSite => 'Add Site';

  @override
  String get siteListTitle => 'Monitoring Sites';

  @override
  String get siteDetailTitle => 'Site Details';

  @override
  String get siteAddTitle => 'Add Site';

  @override
  String get siteEditTitle => 'Edit Site';

  @override
  String get siteName => 'Site name';

  @override
  String get siteAddress => 'Address';

  @override
  String get siteStatus => 'Status';

  @override
  String get siteStatusOnline => 'Online';

  @override
  String get siteStatusOffline => 'Offline';

  @override
  String siteCameraCount(int count) {
    return '$count cameras';
  }

  @override
  String get cameraListTitle => 'Cameras';

  @override
  String get cameraDetailTitle => 'Camera Details';

  @override
  String get cameraAddTitle => 'Add Camera';

  @override
  String get cameraName => 'Camera name';

  @override
  String get cameraStreamUrl => 'Stream URL';

  @override
  String get cameraStatus => 'Status';

  @override
  String get cameraLive => 'Live';

  @override
  String get cameraOffline => 'Offline';

  @override
  String get roiTitle => 'Region of Interest';

  @override
  String get roiDraw => 'Draw ROI';

  @override
  String get roiReset => 'Reset';

  @override
  String get roiSave => 'Save ROI';

  @override
  String get roiInstructions =>
      'Tap to place polygon vertices on the camera view';

  @override
  String get monitorTitle => 'Live Monitor';

  @override
  String get monitorVehicleCount => 'Vehicle Count';

  @override
  String get monitorSpeed => 'Avg Speed';

  @override
  String get monitorOccupancy => 'Occupancy';

  @override
  String get monitorNoFeed => 'No live feed available';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsTimeRange => 'Time Range';

  @override
  String get analyticsToday => 'Today';

  @override
  String get analyticsWeek => 'This Week';

  @override
  String get analyticsMonth => 'This Month';

  @override
  String get analyticsCustom => 'Custom Range';

  @override
  String get analyticsVolumeChart => 'Traffic Volume';

  @override
  String get analyticsSpeedChart => 'Speed Distribution';

  @override
  String get analyticsClassChart => 'Vehicle Classification';

  @override
  String get analyticsExport => 'Export Report';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsEmpty => 'No alerts';

  @override
  String get alertsMarkRead => 'Mark as read';

  @override
  String get alertsMarkAllRead => 'Mark all as read';

  @override
  String get alertsClear => 'Clear';

  @override
  String get alertDetailTitle => 'Alert Detail';

  @override
  String get alertTimestamp => 'Time';

  @override
  String get alertSeverityHigh => 'High';

  @override
  String get alertSeverityMedium => 'Medium';

  @override
  String get alertSeverityLow => 'Low';

  @override
  String get alertTypeIncident => 'Incident';

  @override
  String get alertTypeAnomaly => 'Anomaly';

  @override
  String get alertTypeThreshold => 'Threshold';

  @override
  String get alertRulesTitle => 'Alert Rules';

  @override
  String get alertRuleAdd => 'Add Rule';

  @override
  String get alertRuleEdit => 'Edit Rule';

  @override
  String get alertRuleName => 'Rule name';

  @override
  String get alertRuleCondition => 'Condition';

  @override
  String get alertRuleThreshold => 'Threshold';

  @override
  String get alertRuleEnabled => 'Enabled';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsLogout => 'Sign Out';

  @override
  String get settingsLogoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonNoData => 'No data available';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get errorNetwork => 'Network error. Check your connection.';

  @override
  String get errorTimeout => 'Request timed out. Please try again.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorUnauthorized => 'Session expired. Please sign in again.';

  @override
  String get errorForbidden => 'You do not have permission for this action.';

  @override
  String get errorNotFound => 'Resource not found.';

  @override
  String get setupStepCreateSite => 'Create Site';

  @override
  String get setupStepAddCamera => 'Add Camera';

  @override
  String get setupStepDrawLines => 'Draw Counting Lines';

  @override
  String get setupStepVerify => 'Verify Setup';

  @override
  String get setupStepStart => 'Start Monitoring';

  @override
  String get setupDefaultLineNote =>
      'A default counting line will be created. You can edit it later in the ROI editor.';

  @override
  String get setupGoToDashboard => 'Go to Dashboard';

  @override
  String get setupOpenMonitor => 'Open Live Monitor';

  @override
  String get setupOpenRoiEditor => 'Open Full ROI Editor';

  @override
  String get monitorFlowRate => 'Flow Rate/h';

  @override
  String get monitorActiveTracks => 'Active Tracks';

  @override
  String get monitorCurrentBucket => 'Current Bucket';

  @override
  String get monitorByDirection => 'By Direction';

  @override
  String get monitorByClass => 'By Class';

  @override
  String get monitorInbound => 'Inbound';

  @override
  String get monitorOutbound => 'Outbound';

  @override
  String get roiPresetName => 'Preset Name';

  @override
  String get roiPresetsTitle => 'ROI Presets';

  @override
  String get roiNoPresets => 'No ROI presets configured';

  @override
  String get roiCreatePreset => 'Create Preset';

  @override
  String get roiActive => 'Active';

  @override
  String get roiActivate => 'Activate';

  @override
  String get roiFinishDrawing => 'Finish Drawing';

  @override
  String get exportFormat => 'Export Format';

  @override
  String get exportSelectRange => 'Please select a date range';

  @override
  String get exportStarted => 'Export started';

  @override
  String get exportSelectDateRange => 'Select date range';
}
