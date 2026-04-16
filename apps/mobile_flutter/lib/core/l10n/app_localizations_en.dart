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
  String get loginEnterEmailFirst => 'Enter your email address first';

  @override
  String get loginResetEmailSent =>
      'Password reset email sent. Check your inbox.';

  @override
  String get loginOfflineModeActive => 'Offline mode is active';

  @override
  String get loginOfflineModeDescription =>
      'Supabase is not configured, so authentication is skipped and the local dashboard is available immediately.';

  @override
  String get loginOpenDashboard => 'Open dashboard';

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
  String get registerAuthDisabled => 'Authentication is disabled';

  @override
  String get registerAuthDisabledDescription =>
      'Configure Supabase environment variables to enable account creation. The local dashboard is still available without it.';

  @override
  String get setupTitle => 'Initial Setup';

  @override
  String get setupWelcome => 'Welcome to GreyEye';

  @override
  String get setupAddSite => 'Add your first monitoring site';

  @override
  String get setupComplete => 'Complete Setup';

  @override
  String get setupNext => 'Next';

  @override
  String get setupAddCameraPrompt => 'Add your first camera to this site.';

  @override
  String get setupDefaultLineNote =>
      'A default counting line will be created. You can edit it later in the ROI editor.';

  @override
  String get setupDefaultLinePreview => 'Default counting line preview';

  @override
  String get setupCreateAndContinue => 'Create & Continue';

  @override
  String get setupVerifySite => 'Site';

  @override
  String get setupVerifyCamera => 'Camera';

  @override
  String get setupVerifyCountingLine => 'Counting Line';

  @override
  String get setupDefaultHorizontal => 'Default (horizontal)';

  @override
  String get setupActivateAndStart => 'Activate & Start';

  @override
  String get setupReadyMessage =>
      'Your monitoring site is ready. Start capturing traffic data.';

  @override
  String get setupGoToDashboard => 'Go to Dashboard';

  @override
  String get setupOpenMonitor => 'Open Live Monitor';

  @override
  String get setupOpenRoiEditor => 'Open Full ROI Editor';

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
  String get navHome => 'Home';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navSettings => 'Settings';

  @override
  String get navClassify => 'Classify';

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
  String get siteAnalyzeVideo => 'Analyze Local Video';

  @override
  String get siteAnalyzeVideoDesc => 'Upload a video to count vehicles';

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
  String get cameraSourceType => 'Source Type';

  @override
  String get cameraTargetFps => 'Target FPS';

  @override
  String get cameraResolution => 'Resolution';

  @override
  String get cameraClassificationMode => 'Classification Mode';

  @override
  String get cameraNightMode => 'Night Mode';

  @override
  String get cameraSource => 'Source';

  @override
  String get cameraSourceSmartphone => 'Smartphone';

  @override
  String get cameraSourceRtsp => 'RTSP';

  @override
  String get cameraSourceOnvif => 'ONVIF';

  @override
  String get classificationFull12 => 'Full 12-Class';

  @override
  String get classificationCoarse => 'Coarse (Car/Bus/Truck/Trailer)';

  @override
  String get classificationDisabled => 'Disabled';

  @override
  String get nightModeOn => 'On';

  @override
  String get nightModeOff => 'Off';

  @override
  String get menuLiveMonitor => 'Live Monitor';

  @override
  String get menuRoiEditor => 'ROI Editor';

  @override
  String get menuAnalytics => 'Analytics';

  @override
  String get menuSettings => 'Settings';

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
  String get roiPresetSaved => 'ROI preset saved';

  @override
  String get roiSegmentRoi => 'ROI';

  @override
  String get roiSegmentLine => 'Line';

  @override
  String get roiSegmentLane => 'Lane';

  @override
  String get roiSummaryNone => 'None';

  @override
  String get roiSummarySet => 'Set';

  @override
  String get roiSummaryLines => 'Lines';

  @override
  String get roiSummaryLanes => 'Lanes';

  @override
  String get roiFailedToLoad => 'Failed to load presets';

  @override
  String roiLinesCount(int count, int laneCount) {
    return '$count lines · $laneCount lanes';
  }

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
  String get monitorInitializing => 'Initializing camera & ML models...';

  @override
  String get monitorSimulated => 'Simulated traffic';

  @override
  String get monitorLive => 'Live inference';

  @override
  String monitorTracksAndCrossings(int trackCount, int crossingCount) {
    return '$trackCount tracks · $crossingCount crossings';
  }

  @override
  String get monitorWaitingForData => 'Waiting for data...';

  @override
  String monitorRefiningCrossings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'crossings',
      one: 'crossing',
    );
    return 'Refining $count $_temp0...';
  }

  @override
  String get monitorCloudVlm => 'Cloud VLM';

  @override
  String monitorRefining(int count) {
    return 'refining $count';
  }

  @override
  String get monitorIdle => 'idle';

  @override
  String get monitorSentToVlm => 'Sent to VLM';

  @override
  String get monitorRefined => 'Refined';

  @override
  String get monitorFallbacks => 'Fallbacks';

  @override
  String get monitorAvgLatency => 'Avg latency';

  @override
  String get monitorNoApiKey => 'No API key configured';

  @override
  String get monitorPipelineFull12 => 'Live 12-class (two-stage) inference';

  @override
  String get monitorPipelineCoarse => 'Live coarse vehicle classification';

  @override
  String get monitorPipelineHybrid => 'Live hybrid cloud classification';

  @override
  String get monitorPipelineDetectionOnly => 'Live detection only';

  @override
  String get monitorCameraPermissionDenied =>
      'Camera permission denied. Running simulated traffic mode.';

  @override
  String monitorCameraError(String error) {
    return 'Camera error: $error. Running simulated traffic mode.';
  }

  @override
  String get monitorCameraUnavailable =>
      'Camera access is unavailable. Running simulated traffic mode.';

  @override
  String monitorClassificationUnavailable12(String error) {
    return '12-class classification unavailable: $error';
  }

  @override
  String monitorClassificationUnavailableCoarse(String error) {
    return 'Coarse classification unavailable: $error';
  }

  @override
  String monitorClassificationUnavailableHybrid(String error) {
    return 'Hybrid cloud classification unavailable: $error';
  }

  @override
  String monitorClassificationUnavailableDisabled(String error) {
    return 'Live inference unavailable: $error';
  }

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
  String get analyticsBuckets => 'Buckets';

  @override
  String get analyticsClasses => 'Classes';

  @override
  String get analyticsDemoDataLoaded => 'Demo data loaded.';

  @override
  String get analyticsDataAlreadyPresent => 'Data already present.';

  @override
  String get analyticsLoadDemoData => 'Load Demo Data';

  @override
  String analyticsVehiclesTooltip(String time, int count) {
    return '$time\n$count vehicles';
  }

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
  String get alertStatusTriggered => 'Triggered';

  @override
  String get alertStatusAcknowledged => 'Ack';

  @override
  String get alertStatusAssigned => 'Assigned';

  @override
  String get alertStatusResolved => 'Resolved';

  @override
  String get alertStatusSuppressed => 'Suppressed';

  @override
  String get alertSeverity => 'Severity';

  @override
  String get alertStatus => 'Status';

  @override
  String get alertCondition => 'Condition';

  @override
  String get alertSite => 'Site';

  @override
  String get alertCamera => 'Camera';

  @override
  String get alertMessage => 'Message';

  @override
  String get alertAssignedTo => 'Assigned To';

  @override
  String get alertResolve => 'Resolve';

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
  String get alertRuleAddTitle => 'Add Alert Rule';

  @override
  String get alertRuleNameLabel => 'Rule Name';

  @override
  String get alertConditionLabel => 'Condition';

  @override
  String get alertThresholdLabel => 'Threshold';

  @override
  String get alertSeverityLabel => 'Severity';

  @override
  String get alertCondCongestion => 'Congestion';

  @override
  String get alertCondSpeedDrop => 'Speed Drop';

  @override
  String get alertCondStopped => 'Stopped Vehicle';

  @override
  String get alertCondHeavy => 'Heavy Vehicle Share';

  @override
  String get alertCondCameraOffline => 'Camera Offline';

  @override
  String get alertCondCountAnomaly => 'Count Anomaly';

  @override
  String get alertNoRules => 'No alert rules configured';

  @override
  String get alertRuleCreate => 'Create';

  @override
  String alertRuleSubtitle(String conditionType, String threshold) {
    return '$conditionType · threshold: $threshold';
  }

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
  String get settingsQuickSetup => 'Quick Setup';

  @override
  String get settingsQuickSetupDesc => 'Run the setup wizard again';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsClearData => 'Clear All Local Data';

  @override
  String get settingsClearDataDesc =>
      'Remove all sites, cameras, and crossings';

  @override
  String get settingsClearDataConfirmTitle => 'Clear All Data?';

  @override
  String get settingsClearDataConfirmBody =>
      'This will permanently delete all local sites, cameras, ROI presets, and crossing data. This cannot be undone.';

  @override
  String get settingsCleared => 'All data cleared';

  @override
  String get settingsClearButton => 'Clear';

  @override
  String get settingsCloudClassification => 'Cloud Classification';

  @override
  String get settingsVlmProvider => 'VLM Provider';

  @override
  String get settingsNotConfigured => 'Not configured';

  @override
  String get settingsProviderGemini => 'Google Gemini';

  @override
  String get settingsProviderOpenai => 'OpenAI';

  @override
  String get settingsProvider => 'Provider';

  @override
  String get settingsAuth => 'Authentication';

  @override
  String get settingsApiKey => 'API Key';

  @override
  String get settingsApiKeySecure =>
      'Stored securely on device. Never sent to our servers.';

  @override
  String get settingsModelName => 'Model Name';

  @override
  String get settingsConfidenceThreshold => 'Confidence Threshold';

  @override
  String get settingsConfidenceDescription =>
      'Skip VLM when local classifier confidence exceeds this value. Lower = more VLM calls.';

  @override
  String get settingsBatching => 'Batching';

  @override
  String get settingsBatchingDescription =>
      'Accumulate crops before sending to reduce API calls.';

  @override
  String get settingsBatchSize => 'Batch Size';

  @override
  String get settingsBatchTimeout => 'Batch Timeout';

  @override
  String get settingsRequestTimeout => 'Request Timeout';

  @override
  String get settingsMaxRetries => 'Max Retries';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsResetDefaults => 'Reset to Defaults';

  @override
  String get settingsResetConfirmTitle => 'Reset VLM Settings?';

  @override
  String get settingsResetConfirmBody =>
      'This will clear your API key and reset all cloud classification settings to their defaults.';

  @override
  String get settingsResetButton => 'Reset';

  @override
  String get settingsGemini => 'Gemini';

  @override
  String get settingsOpenai => 'OpenAI';

  @override
  String get classifyTitle => 'Classify Vehicle';

  @override
  String get classifyVehicle => 'Classify a Vehicle';

  @override
  String get classifyDescription =>
      'Take a photo or pick from gallery to identify the vehicle type using two-stage AI classification.';

  @override
  String get classifyCamera => 'Camera';

  @override
  String get classifyGallery => 'Gallery';

  @override
  String get classifyNewPhoto => 'New Photo';

  @override
  String get classifyLoadingModels => 'Loading ML models...';

  @override
  String get classifyClassifying => 'Classifying vehicle...';

  @override
  String get classifyNoVehicles => 'No vehicles detected in this image.';

  @override
  String get classifyFailed => 'Classification Failed';

  @override
  String get classifyUnknownError => 'Unknown error';

  @override
  String get classifyTryAgain => 'Try Again';

  @override
  String get classifySaved => 'Classification saved';

  @override
  String get classifySaveTooltip => 'Save classification';

  @override
  String get classifyStage1 => 'Stage 1 (Coarse)';

  @override
  String get classifyWheels => 'Wheels Detected';

  @override
  String get classifyJoints => 'Joints Detected';

  @override
  String get classifyAxles => 'Estimated Axles';

  @override
  String get classifyTrailer => 'Trailer';

  @override
  String get classifyFinalClass => 'Final Class';

  @override
  String get classifyConfidence => 'Confidence';

  @override
  String get classifyYes => 'Yes';

  @override
  String get classifyNo => 'No';

  @override
  String get classifyUnknown => 'Unknown';

  @override
  String get videoAnalysisTitle => 'Video Analysis';

  @override
  String get videoAnalysisCloud => 'Cloud Video Analysis';

  @override
  String get videoAnalysisDescription =>
      'Record or choose a video (max 5 minutes) to run cloud-based vehicle detection and counting.';

  @override
  String get videoAnalysisGallery => 'Choose from Gallery';

  @override
  String get videoAnalysisRecord => 'Record Video';

  @override
  String get videoAnalysisUploading => 'Uploading and analyzing…';

  @override
  String get videoAnalysisUploadingHint =>
      'This may take several minutes depending on video length.';

  @override
  String get videoAnalysisProcessing => 'Analyzing video on server…';

  @override
  String get videoAnalysisProcessingHint =>
      'The video has been uploaded. The server is processing it now. This may take several minutes depending on video length.';

  @override
  String get videoAnalysisTotalCounted => 'Total vehicles counted';

  @override
  String get videoAnalysisBreakdown => 'Breakdown by Class';

  @override
  String get videoAnalysisExportCsv => 'Export CSV';

  @override
  String get videoAnalysisRetry => 'Retry';

  @override
  String get reportTitle => 'GreyEye Traffic Report';

  @override
  String reportCamera(String cameraId) {
    return 'Camera: $cameraId';
  }

  @override
  String reportPeriod(String period) {
    return 'Period: $period';
  }

  @override
  String get reportNA => 'N/A';

  @override
  String reportTotalCrossings(int count) {
    return 'Total crossings: $count';
  }

  @override
  String get reportByClass => 'By Vehicle Class';

  @override
  String get reportByDirection => 'By Direction';

  @override
  String get reportRawCrossings => 'Raw Crossings (first 200)';

  @override
  String get reportHeaderClass => 'Class';

  @override
  String get reportHeaderCount => 'Count';

  @override
  String get reportHeaderDirection => 'Direction';

  @override
  String get reportHeaderTime => 'Time';

  @override
  String get reportHeaderDir => 'Dir';

  @override
  String get reportHeaderConf => 'Conf';

  @override
  String exportExported(int count) {
    return 'Exported $count crossings';
  }

  @override
  String get exportFormat => 'Export Format';

  @override
  String get exportSelectRange => 'Please select a date range';

  @override
  String get exportStarted => 'Export started';

  @override
  String get exportSelectDateRange => 'Select date range';

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
}
