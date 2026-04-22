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
  String get videoAnalysisPickFileTitle => 'Choose a video file (MP4 or DAV)';

  @override
  String get videoAnalysisStartAnalysis => 'Start analysis';

  @override
  String get videoAnalysisChooseDifferentFile => 'Choose a different file';

  @override
  String videoAnalysisStagedFile(String filename) {
    return 'Selected: $filename';
  }

  @override
  String get videoAnalysisStagedHint =>
      'Review the tasks below, then tap Start to upload and analyze.';

  @override
  String get videoAnalysisBusStopPreset => 'Bus stop preset';

  @override
  String get videoAnalysisBusStopPresetHint =>
      'One-tap setup for a bus stop: disables vehicle counting, enables transit (boarding / alighting) and pedestrians.';

  @override
  String get videoAnalysisBusStopApplied =>
      'Bus stop preset applied — vehicle counting is off.';

  @override
  String get videoAnalysisCountLineConfigure => 'Configure count lines';

  @override
  String get videoAnalysisCountLineConfigured => 'IN/OUT lines set';

  @override
  String get videoAnalysisDavNotSupported =>
      'DAV files cannot be uploaded for analysis. Open the Speed, Transit, or Traffic-light editor to use this file as a calibration backdrop, or transcode it to MP4 first.';

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
  String get videoAnalysisExportCsv => 'Export XLSX';

  @override
  String get videoAnalysisRetry => 'Retry';

  @override
  String get videoAnalysisIncludeAnnotatedVideo => 'Generate annotated video';

  @override
  String get videoAnalysisIncludeAnnotatedVideoHint =>
      'Adds a labeled MP4 you can download after analysis. Increases processing time.';

  @override
  String get videoAnalysisDownloadVideo => 'Download annotated video';

  @override
  String get videoAnalysisDownloadTransitVideo =>
      'Download transit overlay video';

  @override
  String get videoAnalysisDownloadingVideo => 'Downloading annotated video…';

  @override
  String get videoAnalysisDownloadCanceled => 'Download canceled.';

  @override
  String videoAnalysisDownloadSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get videoAnalysisTasksTitle => 'Tasks to run';

  @override
  String get videoAnalysisTasksHint =>
      'Each task needs site calibration to produce useful numbers. Defaults assume a centered road in the lower half of the frame.';

  @override
  String get videoAnalysisTaskVehicles =>
      'Vehicles (counting + classification)';

  @override
  String get videoAnalysisTaskPedestrians => 'Pedestrians (people crossing)';

  @override
  String get videoAnalysisTaskSpeed => 'Speed (two-line measurement)';

  @override
  String get videoAnalysisTaskTransit =>
      'Transit (boarding / alighting / density)';

  @override
  String get videoAnalysisTaskTrafficLight => 'Traffic-light timing';

  @override
  String get videoAnalysisTaskLpr => 'License plates (resident vs visitor)';

  @override
  String get videoAnalysisPedestrianTitle => 'Pedestrians';

  @override
  String videoAnalysisPedestrianCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pedestrians counted',
      one: '1 pedestrian counted',
      zero: 'No pedestrians counted',
    );
    return '$_temp0';
  }

  @override
  String get videoAnalysisPedestrianDetectorOff =>
      'Pedestrian detector is off — set ENABLE_PEDESTRIAN_DETECTOR=1 on the server.';

  @override
  String get videoAnalysisSpeedTitle => 'Speed';

  @override
  String get videoAnalysisSpeedNoMeasurements =>
      'No vehicles crossed both speed lines.';

  @override
  String get videoAnalysisSpeedAvg => 'Average';

  @override
  String get videoAnalysisSpeedMin => 'Min';

  @override
  String get videoAnalysisSpeedMax => 'Max';

  @override
  String videoAnalysisSpeedKmh(String value) {
    return '$value km/h';
  }

  @override
  String videoAnalysisSpeedMeasured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicles measured',
      one: '1 vehicle measured',
    );
    return '$_temp0';
  }

  @override
  String get videoAnalysisSpeedPerTrack => 'Per-vehicle speeds';

  @override
  String videoAnalysisSpeedTrackRow(String trackId) {
    return 'Track $trackId';
  }

  @override
  String get videoAnalysisTransitTitle => 'Public transit';

  @override
  String get videoAnalysisTransitBoarding => 'Boarding';

  @override
  String get videoAnalysisTransitAlighting => 'Alighting';

  @override
  String get videoAnalysisTransitPeak => 'Peak inside stop';

  @override
  String get videoAnalysisTransitDensity => 'Avg density';

  @override
  String videoAnalysisTransitDensityValue(String value) {
    return '$value%';
  }

  @override
  String get videoAnalysisTransitBusGated => 'Counts gated to bus presence.';

  @override
  String get videoAnalysisTransitNotGated =>
      'All door-line crossings counted (no bus-zone gate).';

  @override
  String videoAnalysisTransitVlmArrivals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bus arrivals',
      one: '1 bus arrival',
    );
    return 'VLM headcount across $_temp0.';
  }

  @override
  String get videoAnalysisTransitFallback =>
      'VLM unavailable — fell back to door-line counts (less accurate).';

  @override
  String platesClassifyFailed(String message) {
    return 'Plate classification could not be saved: $message';
  }

  @override
  String platesSiteTotals(int resident, int visitor) {
    return 'This site (all-time): $resident resident / $visitor visitor';
  }

  @override
  String get platesClassificationPending =>
      'Classification pending — connect to Supabase to compute resident vs visitor.';

  @override
  String get lightHelpTitle => 'How does traffic-light timing work?';

  @override
  String get lightHelpBody =>
      '1) The pipeline samples the colour inside a bounding box around the lamp housing every few frames.\n2) Auto mode asks the AI to find that box for you on a representative keyframe — no manual drawing required.\n3) The pipeline then logs every red/yellow/green transition and reports cycle counts plus average duration per state.\n\nFirst time? Keep Auto mode on, tap \"Preview ROI\" to confirm the AI got the lamp location right, then run the analysis. If the preview looks wrong, switch to Manual.';

  @override
  String get lightPreviewButton => 'Preview ROI';

  @override
  String get lightPreviewConfirm => 'Looks good';

  @override
  String get lightPreviewManual => 'Adjust manually';

  @override
  String get lightPreviewNoVideo =>
      'Pick a video first to preview the traffic-light ROI.';

  @override
  String get lightPreviewExtractFailed =>
      'Could not extract a keyframe from this video.';

  @override
  String get lightPreviewVlmUnavailable =>
      'The AI is offline right now — switch to Manual mode to draw the ROI yourself.';

  @override
  String get lightPreviewEmpty =>
      'The AI didn\'t find any traffic light in this frame. Try Manual mode.';

  @override
  String get lightPreviewTitle => 'AI proposed ROI';

  @override
  String lightPreviewSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lights detected',
      one: '1 light detected',
    );
    return '$_temp0';
  }

  @override
  String lightPreviewLowConfidence(String pct) {
    return 'Low confidence ($pct%) — review carefully.';
  }

  @override
  String get videoAnalysisTrafficLightTitle => 'Traffic-light timing';

  @override
  String videoAnalysisTrafficLightLabel(String label) {
    return 'Light: $label';
  }

  @override
  String get videoAnalysisTrafficLightCycles => 'Cycles';

  @override
  String get videoAnalysisTrafficLightAvgDuration => 'Avg';

  @override
  String get videoAnalysisTrafficLightTotalDuration => 'Total';

  @override
  String videoAnalysisTrafficLightSeconds(String value) {
    return '${value}s';
  }

  @override
  String get videoAnalysisTrafficLightRed => 'Red';

  @override
  String get videoAnalysisTrafficLightGreen => 'Green';

  @override
  String get videoAnalysisTrafficLightYellow => 'Yellow';

  @override
  String get videoAnalysisLprTitle => 'License plates';

  @override
  String get videoAnalysisLprResident => 'Resident';

  @override
  String get videoAnalysisLprVisitor => 'Visitor';

  @override
  String videoAnalysisLprAllowlistSize(int count) {
    return 'Allowlist: $count plate(s)';
  }

  @override
  String get videoAnalysisLprPrivacyHashed =>
      'Plate text stored as SHA-256 prefix (privacy mode).';

  @override
  String get videoAnalysisLprPlatePrefix => 'Plate';

  @override
  String get videoAnalysisLprHashPrefix => 'Hash';

  @override
  String get videoAnalysisConfigure => 'Configure';

  @override
  String get videoAnalysisConfigureNoVideo =>
      'Pick a video first to enable per-task configuration.';

  @override
  String videoAnalysisRoiConfigured(
      String label, String width, String height, String position) {
    return 'ROI set: $label ($width×$height, $position)';
  }

  @override
  String get roiEditorTitle => 'Traffic-light ROI';

  @override
  String get roiEditorLabel => 'Light label (e.g. main, left_turn)';

  @override
  String get roiEditorReset => 'Clear';

  @override
  String get roiEditorSave => 'Save';

  @override
  String get roiEditorCancel => 'Cancel';

  @override
  String get roiEditorPickStill => 'Pick a still image instead';

  @override
  String get roiEditorPickBackdrop => 'Choose backdrop file';

  @override
  String get roiEditorPickBackdropTitle => 'Pick MP4, DAV, or still image';

  @override
  String get roiEditorNoBackdrop =>
      'No backdrop loaded yet. Pick an MP4, DAV, or still image of the scene to start drawing.';

  @override
  String get roiEditorFrameLoadFailed =>
      'Couldn\'t extract a frame from the video. Pick a still image of the same scene.';

  @override
  String get roiEditorRoiTooSmall =>
      'ROI is too small. Pick two corners further apart.';

  @override
  String get roiEditorHintTopLeft =>
      'Tap the TOP-LEFT corner of the signal head.';

  @override
  String get roiEditorHintBottomRight =>
      'Tap the BOTTOM-RIGHT corner of the signal head.';

  @override
  String get roiEditorHintRefine =>
      'Tap to refine either corner. Press Save when ready.';

  @override
  String get lprAllowlistTitle => 'Resident plates';

  @override
  String get lprAllowlistEmpty =>
      'No resident plates yet. Add the first one below.';

  @override
  String get lprAllowlistHint =>
      'Korean format: NNga NNNN (e.g. 12가 3456). Spaces are stripped automatically.';

  @override
  String get lprAllowlistAddHint => 'Plate (e.g. 12가 3456)';

  @override
  String get lprAllowlistAdd => 'Add';

  @override
  String get lprAllowlistInvalid =>
      'Plate doesn\'t match the Korean format (NN(N)가 NNNN).';

  @override
  String get lprAllowlistDuplicate => 'That plate is already on the allowlist.';

  @override
  String get lprAllowlistRemove => 'Remove';

  @override
  String lprAllowlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plates',
      one: '1 plate',
      zero: 'No plates',
    );
    return '$_temp0';
  }

  @override
  String get lprAllowlistConfigure => 'Manage allowlist';

  @override
  String get speedEditorTitle => 'Speed lines & quad';

  @override
  String get speedEditorResetQuad => 'Clear quad';

  @override
  String speedEditorModeQuad(int count) {
    return 'Quad ($count/4)';
  }

  @override
  String get speedEditorModeLine1 => 'Line 1';

  @override
  String get speedEditorModeLine2 => 'Line 2';

  @override
  String get speedEditorWidthM => 'Width (m)';

  @override
  String get speedEditorLengthM => 'Length (m)';

  @override
  String speedEditorHintQuad(int remaining) {
    return 'Tap $remaining more corner(s) of a known real-world rectangle (e.g. lane markings).';
  }

  @override
  String get speedEditorHintQuadDone =>
      'Quad complete. Tap again to start over, or switch to Line 1 / Line 2.';

  @override
  String get speedEditorHintLine1Start =>
      'Tap the START point of Line 1 (entry).';

  @override
  String get speedEditorHintLine1End => 'Tap the END point of Line 1 (entry).';

  @override
  String get speedEditorHintLine1Done => 'Line 1 set. Tap again to redraw.';

  @override
  String get speedEditorHintLine2Start =>
      'Tap the START point of Line 2 (exit).';

  @override
  String get speedEditorHintLine2End => 'Tap the END point of Line 2 (exit).';

  @override
  String get speedEditorHintLine2Done => 'Line 2 set. Tap again to redraw.';

  @override
  String get speedEditorSnapHorizontal => 'Snap lines to horizontal';

  @override
  String get speedEditorSnapHorizontalHint =>
      'Forces both lines to be perfectly horizontal — old behavior; uncheck for arbitrary lines.';

  @override
  String get speedEditorQuadIncomplete =>
      'Tap all 4 quad corners before saving.';

  @override
  String get speedEditorLinesIncomplete =>
      'Both speed lines need 2 endpoints each before saving.';

  @override
  String get speedEditorLinesTooClose =>
      'Lines must be at least 5% of frame height apart.';

  @override
  String get speedEditorBadMetres =>
      'Width and length must be positive numbers in metres.';

  @override
  String get countLineEditorTitle => 'Count lines (IN / OUT)';

  @override
  String get countLineEditorModeIn => 'IN line';

  @override
  String get countLineEditorModeOut => 'OUT line';

  @override
  String get countLineEditorReset => 'Reset line';

  @override
  String get countLineEditorHintInStart =>
      'Tap the START point of the IN line.';

  @override
  String get countLineEditorHintInEnd => 'Tap the END point of the IN line.';

  @override
  String get countLineEditorHintInDone => 'IN line set. Tap again to redraw.';

  @override
  String get countLineEditorHintOutStart =>
      'Tap the START point of the OUT line.';

  @override
  String get countLineEditorHintOutEnd => 'Tap the END point of the OUT line.';

  @override
  String get countLineEditorHintOutDone => 'OUT line set. Tap again to redraw.';

  @override
  String get countLineEditorIncomplete =>
      'Both lines need 2 endpoints each before saving.';

  @override
  String get countLineEditorDescription =>
      'Vehicles count once when a track crosses both lines, in either order. Place IN where vehicles enter the scene and OUT where they leave.';

  @override
  String get transitEditorTitle => 'Bus stop & door line';

  @override
  String get transitEditorUndo => 'Undo last point';

  @override
  String get transitEditorModeStopPolygon => 'Stop polygon';

  @override
  String get transitEditorModeDoorLine => 'Door line';

  @override
  String get transitEditorModeBusZone => 'Bus zone';

  @override
  String get transitEditorBusZoneEnable => 'Gate counting on bus presence';

  @override
  String get transitEditorBusZoneHint =>
      'When enabled, door-line crossings only count while a bus overlaps this polygon.';

  @override
  String get transitEditorBusZoneDisabled =>
      'Bus-zone gating is off — every door-line crossing counts.';

  @override
  String get transitEditorCapacity => 'Max capacity (persons)';

  @override
  String get transitEditorCapacityHint =>
      'Density % = persons inside the stop polygon ÷ capacity.';

  @override
  String transitEditorHintStopPolygon(int remaining) {
    return 'Tap to add a polygon vertex. $remaining more needed.';
  }

  @override
  String get transitEditorHintStopPolygonDone =>
      'Stop polygon ready. Add more vertices or switch tabs.';

  @override
  String transitEditorHintDoorLine(int remaining) {
    return 'Tap to set door-line endpoint $remaining of 2.';
  }

  @override
  String get transitEditorHintDoorLineDone =>
      'Door line ready. Tap again to redraw.';

  @override
  String transitEditorHintBusZone(int remaining) {
    return 'Tap to add a bus-zone vertex. $remaining more needed.';
  }

  @override
  String get transitEditorHintBusZoneDone => 'Bus zone ready.';

  @override
  String get transitEditorStopPolygonTooSmall =>
      'Stop polygon needs at least 3 vertices.';

  @override
  String get transitEditorDoorLineIncomplete =>
      'Door line needs exactly 2 endpoints.';

  @override
  String get transitEditorBusZoneTooSmall =>
      'Bus zone needs at least 3 vertices (or turn it off).';

  @override
  String get transitEditorBadCapacity => 'Capacity must be a positive integer.';

  @override
  String get calibrationModeAuto => 'Auto';

  @override
  String get calibrationModeManual => 'Manual';

  @override
  String get transitAutoModeTitle => 'AI auto-detect mode';

  @override
  String get transitAutoModeBody =>
      'AI analyses one keyframe of the video and finds the bus stop area, door line, and bus parking spot automatically. You only need to enter the capacity.';

  @override
  String get transitManualModeBody =>
      'Switch to Manual to draw the regions yourself.';

  @override
  String get transitWhatIsThisTitle => 'What does this configure?';

  @override
  String get transitWhatIsThisBody =>
      'The stop polygon (green) is where people stand — used to compute density (%). The door line (yellow) sits across the bus door — people crossing it count as boarding/alighting. The bus zone (blue) is where the bus parks — boarding only counts while a bus overlaps it.';

  @override
  String get lightAutoModeTitle => 'AI auto-detect mode';

  @override
  String get lightAutoModeBody =>
      'AI finds the traffic light in the video automatically. Just provide a label (used to disambiguate when multiple lights are visible).';

  @override
  String get lightManualModeBody =>
      'Switch to Manual to draw the ROI yourself.';

  @override
  String get lightAutoLabelField => 'Label (e.g. straight, left_turn)';

  @override
  String get lightWhatIsThisTitle => 'What does this configure?';

  @override
  String get lightWhatIsThisBody =>
      'The traffic-light ROI is a tight box around the lamp housing only — no sky, no pole, no signs. A loose box pulls in dark background pixels and confuses the colour state machine.';

  @override
  String get speedWhatIsThisTitle => 'What does this configure?';

  @override
  String get speedWhatIsThisBody =>
      'The trapezoid removes the camera\'s perspective so the road looks like a top-down view. The width / length in metres convert pixels to metres, and the two lines time how long a vehicle takes to travel between them — that gives km/h. Use the lane width (usually 3.5 m) and a known distance.';

  @override
  String get speedDefaultPresetButton => 'Apply preset (1 lane 3.5m × 10m)';

  @override
  String get speedDefaultPresetApplied =>
      'Default preset applied. Adjust to fit your video.';

  @override
  String get countLineWhatIsThisTitle => 'What does this configure?';

  @override
  String get countLineWhatIsThisBody =>
      'Two virtual lines: a vehicle is counted as one only when its track crosses BOTH lines (order doesn\'t matter). More accurate than a single tripwire and separates IN vs OUT direction.';

  @override
  String get pedestrianZoneConfigure => 'Pedestrian ROI';

  @override
  String get pedestrianZoneEditorTitle => 'Pedestrian ROI';

  @override
  String get pedestrianZoneEditorClear => 'Clear polygon';

  @override
  String get pedestrianZoneEditorTooSmall =>
      'Pedestrian ROI needs at least 3 vertices.';

  @override
  String pedestrianZoneEditorHint(int remaining) {
    return 'Tap to add a polygon vertex. $remaining more needed.';
  }

  @override
  String pedestrianZoneEditorHintDone(int count) {
    return 'ROI ready ($count vertices). Tap to add more or save.';
  }

  @override
  String get pedestrianZoneWhatIsThisTitle => 'What does this configure?';

  @override
  String get pedestrianZoneWhatIsThisBody =>
      'An optional polygon outlining the area where pedestrians should be counted. Only people whose feet land inside the polygon are added to the total — ideal for sites where the camera also frames an unrelated sidewalk in the background. Leave it unset to count the whole frame.';

  @override
  String get lprWhatIsThisTitle => 'What does this configure?';

  @override
  String get lprWhatIsThisBody =>
      'Plates on the allowlist are tagged \'resident\', others \'visitor\'. The AI reads plates automatically — no ROI needed.';

  @override
  String get calibrationResetTooltip => 'Reset site calibration';

  @override
  String get calibrationResetTitle => 'Reset calibration?';

  @override
  String get calibrationResetMessage =>
      'Clears every per-task setting saved for this site (enabled tasks, ROIs, speed lines, transit polygons, plate allowlist). Cannot be undone.';

  @override
  String get calibrationResetConfirm => 'Reset';

  @override
  String get calibrationResetDone => 'Site calibration cleared.';

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
