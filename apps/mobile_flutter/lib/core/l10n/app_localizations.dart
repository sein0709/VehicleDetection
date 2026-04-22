import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GreyEye'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Intelligent Traffic Monitoring'**
  String get appTagline;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get loginInvalidCredentials;

  /// No description provided for @loginFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get loginFieldRequired;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get loginInvalidEmail;

  /// No description provided for @loginEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address first'**
  String get loginEnterEmailFirst;

  /// No description provided for @loginResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Check your inbox.'**
  String get loginResetEmailSent;

  /// No description provided for @loginOfflineModeActive.
  ///
  /// In en, this message translates to:
  /// **'Offline mode is active'**
  String get loginOfflineModeActive;

  /// No description provided for @loginOfflineModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Supabase is not configured, so authentication is skipped and the local dashboard is available immediately.'**
  String get loginOfflineModeDescription;

  /// No description provided for @loginOpenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open dashboard'**
  String get loginOpenDashboard;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @registerName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerName;

  /// No description provided for @registerEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get registerEmail;

  /// No description provided for @registerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPassword;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerConfirmPassword;

  /// No description provided for @registerOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get registerOrganization;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @registerPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerPasswordMismatch;

  /// No description provided for @registerAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get registerAlreadyHaveAccount;

  /// No description provided for @registerAuthDisabled.
  ///
  /// In en, this message translates to:
  /// **'Authentication is disabled'**
  String get registerAuthDisabled;

  /// No description provided for @registerAuthDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure Supabase environment variables to enable account creation. The local dashboard is still available without it.'**
  String get registerAuthDisabledDescription;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Initial Setup'**
  String get setupTitle;

  /// No description provided for @setupWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to GreyEye'**
  String get setupWelcome;

  /// No description provided for @setupAddSite.
  ///
  /// In en, this message translates to:
  /// **'Add your first monitoring site'**
  String get setupAddSite;

  /// No description provided for @setupComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete Setup'**
  String get setupComplete;

  /// No description provided for @setupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get setupNext;

  /// No description provided for @setupAddCameraPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add your first camera to this site.'**
  String get setupAddCameraPrompt;

  /// No description provided for @setupDefaultLineNote.
  ///
  /// In en, this message translates to:
  /// **'A default counting line will be created. You can edit it later in the ROI editor.'**
  String get setupDefaultLineNote;

  /// No description provided for @setupDefaultLinePreview.
  ///
  /// In en, this message translates to:
  /// **'Default counting line preview'**
  String get setupDefaultLinePreview;

  /// No description provided for @setupCreateAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Create & Continue'**
  String get setupCreateAndContinue;

  /// No description provided for @setupVerifySite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get setupVerifySite;

  /// No description provided for @setupVerifyCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get setupVerifyCamera;

  /// No description provided for @setupVerifyCountingLine.
  ///
  /// In en, this message translates to:
  /// **'Counting Line'**
  String get setupVerifyCountingLine;

  /// No description provided for @setupDefaultHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Default (horizontal)'**
  String get setupDefaultHorizontal;

  /// No description provided for @setupActivateAndStart.
  ///
  /// In en, this message translates to:
  /// **'Activate & Start'**
  String get setupActivateAndStart;

  /// No description provided for @setupReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your monitoring site is ready. Start capturing traffic data.'**
  String get setupReadyMessage;

  /// No description provided for @setupGoToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get setupGoToDashboard;

  /// No description provided for @setupOpenMonitor.
  ///
  /// In en, this message translates to:
  /// **'Open Live Monitor'**
  String get setupOpenMonitor;

  /// No description provided for @setupOpenRoiEditor.
  ///
  /// In en, this message translates to:
  /// **'Open Full ROI Editor'**
  String get setupOpenRoiEditor;

  /// No description provided for @setupStepCreateSite.
  ///
  /// In en, this message translates to:
  /// **'Create Site'**
  String get setupStepCreateSite;

  /// No description provided for @setupStepAddCamera.
  ///
  /// In en, this message translates to:
  /// **'Add Camera'**
  String get setupStepAddCamera;

  /// No description provided for @setupStepDrawLines.
  ///
  /// In en, this message translates to:
  /// **'Draw Counting Lines'**
  String get setupStepDrawLines;

  /// No description provided for @setupStepVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify Setup'**
  String get setupStepVerify;

  /// No description provided for @setupStepStart.
  ///
  /// In en, this message translates to:
  /// **'Start Monitoring'**
  String get setupStepStart;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navClassify.
  ///
  /// In en, this message translates to:
  /// **'Classify'**
  String get navClassify;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homeTitle;

  /// No description provided for @homeSites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get homeSites;

  /// No description provided for @homeActiveCameras.
  ///
  /// In en, this message translates to:
  /// **'Active Cameras'**
  String get homeActiveCameras;

  /// No description provided for @homeTotalVehicles.
  ///
  /// In en, this message translates to:
  /// **'Total Vehicles'**
  String get homeTotalVehicles;

  /// No description provided for @homeAlertCount.
  ///
  /// In en, this message translates to:
  /// **'Active Alerts'**
  String get homeAlertCount;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivity;

  /// No description provided for @homeNoSites.
  ///
  /// In en, this message translates to:
  /// **'No monitoring sites configured'**
  String get homeNoSites;

  /// No description provided for @homeAddSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get homeAddSite;

  /// No description provided for @siteListTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitoring Sites'**
  String get siteListTitle;

  /// No description provided for @siteDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Site Details'**
  String get siteDetailTitle;

  /// No description provided for @siteAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get siteAddTitle;

  /// No description provided for @siteEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Site'**
  String get siteEditTitle;

  /// No description provided for @siteName.
  ///
  /// In en, this message translates to:
  /// **'Site name'**
  String get siteName;

  /// No description provided for @siteAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get siteAddress;

  /// No description provided for @siteStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get siteStatus;

  /// No description provided for @siteStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get siteStatusOnline;

  /// No description provided for @siteStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get siteStatusOffline;

  /// No description provided for @siteCameraCount.
  ///
  /// In en, this message translates to:
  /// **'{count} cameras'**
  String siteCameraCount(int count);

  /// No description provided for @siteAnalyzeVideo.
  ///
  /// In en, this message translates to:
  /// **'Analyze Local Video'**
  String get siteAnalyzeVideo;

  /// No description provided for @siteAnalyzeVideoDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload a video to count vehicles'**
  String get siteAnalyzeVideoDesc;

  /// No description provided for @cameraListTitle.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get cameraListTitle;

  /// No description provided for @cameraDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Details'**
  String get cameraDetailTitle;

  /// No description provided for @cameraAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Camera'**
  String get cameraAddTitle;

  /// No description provided for @cameraName.
  ///
  /// In en, this message translates to:
  /// **'Camera name'**
  String get cameraName;

  /// No description provided for @cameraStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Stream URL'**
  String get cameraStreamUrl;

  /// No description provided for @cameraStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get cameraStatus;

  /// No description provided for @cameraLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get cameraLive;

  /// No description provided for @cameraOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get cameraOffline;

  /// No description provided for @cameraSourceType.
  ///
  /// In en, this message translates to:
  /// **'Source Type'**
  String get cameraSourceType;

  /// No description provided for @cameraTargetFps.
  ///
  /// In en, this message translates to:
  /// **'Target FPS'**
  String get cameraTargetFps;

  /// No description provided for @cameraResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get cameraResolution;

  /// No description provided for @cameraClassificationMode.
  ///
  /// In en, this message translates to:
  /// **'Classification Mode'**
  String get cameraClassificationMode;

  /// No description provided for @cameraNightMode.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get cameraNightMode;

  /// No description provided for @cameraSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get cameraSource;

  /// No description provided for @cameraSourceSmartphone.
  ///
  /// In en, this message translates to:
  /// **'Smartphone'**
  String get cameraSourceSmartphone;

  /// No description provided for @cameraSourceRtsp.
  ///
  /// In en, this message translates to:
  /// **'RTSP'**
  String get cameraSourceRtsp;

  /// No description provided for @cameraSourceOnvif.
  ///
  /// In en, this message translates to:
  /// **'ONVIF'**
  String get cameraSourceOnvif;

  /// No description provided for @classificationFull12.
  ///
  /// In en, this message translates to:
  /// **'Full 12-Class'**
  String get classificationFull12;

  /// No description provided for @classificationCoarse.
  ///
  /// In en, this message translates to:
  /// **'Coarse (Car/Bus/Truck/Trailer)'**
  String get classificationCoarse;

  /// No description provided for @classificationDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get classificationDisabled;

  /// No description provided for @nightModeOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get nightModeOn;

  /// No description provided for @nightModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get nightModeOff;

  /// No description provided for @menuLiveMonitor.
  ///
  /// In en, this message translates to:
  /// **'Live Monitor'**
  String get menuLiveMonitor;

  /// No description provided for @menuRoiEditor.
  ///
  /// In en, this message translates to:
  /// **'ROI Editor'**
  String get menuRoiEditor;

  /// No description provided for @menuAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get menuAnalytics;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @roiTitle.
  ///
  /// In en, this message translates to:
  /// **'Region of Interest'**
  String get roiTitle;

  /// No description provided for @roiDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw ROI'**
  String get roiDraw;

  /// No description provided for @roiReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get roiReset;

  /// No description provided for @roiSave.
  ///
  /// In en, this message translates to:
  /// **'Save ROI'**
  String get roiSave;

  /// No description provided for @roiInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap to place polygon vertices on the camera view'**
  String get roiInstructions;

  /// No description provided for @roiPresetName.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get roiPresetName;

  /// No description provided for @roiPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'ROI Presets'**
  String get roiPresetsTitle;

  /// No description provided for @roiNoPresets.
  ///
  /// In en, this message translates to:
  /// **'No ROI presets configured'**
  String get roiNoPresets;

  /// No description provided for @roiCreatePreset.
  ///
  /// In en, this message translates to:
  /// **'Create Preset'**
  String get roiCreatePreset;

  /// No description provided for @roiActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get roiActive;

  /// No description provided for @roiActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get roiActivate;

  /// No description provided for @roiFinishDrawing.
  ///
  /// In en, this message translates to:
  /// **'Finish Drawing'**
  String get roiFinishDrawing;

  /// No description provided for @roiPresetSaved.
  ///
  /// In en, this message translates to:
  /// **'ROI preset saved'**
  String get roiPresetSaved;

  /// No description provided for @roiSegmentRoi.
  ///
  /// In en, this message translates to:
  /// **'ROI'**
  String get roiSegmentRoi;

  /// No description provided for @roiSegmentLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get roiSegmentLine;

  /// No description provided for @roiSegmentLane.
  ///
  /// In en, this message translates to:
  /// **'Lane'**
  String get roiSegmentLane;

  /// No description provided for @roiSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get roiSummaryNone;

  /// No description provided for @roiSummarySet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get roiSummarySet;

  /// No description provided for @roiSummaryLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get roiSummaryLines;

  /// No description provided for @roiSummaryLanes.
  ///
  /// In en, this message translates to:
  /// **'Lanes'**
  String get roiSummaryLanes;

  /// No description provided for @roiFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load presets'**
  String get roiFailedToLoad;

  /// No description provided for @roiLinesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lines · {laneCount} lanes'**
  String roiLinesCount(int count, int laneCount);

  /// No description provided for @monitorTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Monitor'**
  String get monitorTitle;

  /// No description provided for @monitorVehicleCount.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Count'**
  String get monitorVehicleCount;

  /// No description provided for @monitorSpeed.
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get monitorSpeed;

  /// No description provided for @monitorOccupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get monitorOccupancy;

  /// No description provided for @monitorNoFeed.
  ///
  /// In en, this message translates to:
  /// **'No live feed available'**
  String get monitorNoFeed;

  /// No description provided for @monitorFlowRate.
  ///
  /// In en, this message translates to:
  /// **'Flow Rate/h'**
  String get monitorFlowRate;

  /// No description provided for @monitorActiveTracks.
  ///
  /// In en, this message translates to:
  /// **'Active Tracks'**
  String get monitorActiveTracks;

  /// No description provided for @monitorCurrentBucket.
  ///
  /// In en, this message translates to:
  /// **'Current Bucket'**
  String get monitorCurrentBucket;

  /// No description provided for @monitorByDirection.
  ///
  /// In en, this message translates to:
  /// **'By Direction'**
  String get monitorByDirection;

  /// No description provided for @monitorByClass.
  ///
  /// In en, this message translates to:
  /// **'By Class'**
  String get monitorByClass;

  /// No description provided for @monitorInbound.
  ///
  /// In en, this message translates to:
  /// **'Inbound'**
  String get monitorInbound;

  /// No description provided for @monitorOutbound.
  ///
  /// In en, this message translates to:
  /// **'Outbound'**
  String get monitorOutbound;

  /// No description provided for @monitorInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing camera & ML models...'**
  String get monitorInitializing;

  /// No description provided for @monitorSimulated.
  ///
  /// In en, this message translates to:
  /// **'Simulated traffic'**
  String get monitorSimulated;

  /// No description provided for @monitorLive.
  ///
  /// In en, this message translates to:
  /// **'Live inference'**
  String get monitorLive;

  /// No description provided for @monitorTracksAndCrossings.
  ///
  /// In en, this message translates to:
  /// **'{trackCount} tracks · {crossingCount} crossings'**
  String monitorTracksAndCrossings(int trackCount, int crossingCount);

  /// No description provided for @monitorWaitingForData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for data...'**
  String get monitorWaitingForData;

  /// No description provided for @monitorRefiningCrossings.
  ///
  /// In en, this message translates to:
  /// **'Refining {count} {count, plural, =1{crossing} other{crossings}}...'**
  String monitorRefiningCrossings(int count);

  /// No description provided for @monitorCloudVlm.
  ///
  /// In en, this message translates to:
  /// **'Cloud VLM'**
  String get monitorCloudVlm;

  /// No description provided for @monitorRefining.
  ///
  /// In en, this message translates to:
  /// **'refining {count}'**
  String monitorRefining(int count);

  /// No description provided for @monitorIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get monitorIdle;

  /// No description provided for @monitorSentToVlm.
  ///
  /// In en, this message translates to:
  /// **'Sent to VLM'**
  String get monitorSentToVlm;

  /// No description provided for @monitorRefined.
  ///
  /// In en, this message translates to:
  /// **'Refined'**
  String get monitorRefined;

  /// No description provided for @monitorFallbacks.
  ///
  /// In en, this message translates to:
  /// **'Fallbacks'**
  String get monitorFallbacks;

  /// No description provided for @monitorAvgLatency.
  ///
  /// In en, this message translates to:
  /// **'Avg latency'**
  String get monitorAvgLatency;

  /// No description provided for @monitorNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'No API key configured'**
  String get monitorNoApiKey;

  /// No description provided for @monitorPipelineFull12.
  ///
  /// In en, this message translates to:
  /// **'Live 12-class (two-stage) inference'**
  String get monitorPipelineFull12;

  /// No description provided for @monitorPipelineCoarse.
  ///
  /// In en, this message translates to:
  /// **'Live coarse vehicle classification'**
  String get monitorPipelineCoarse;

  /// No description provided for @monitorPipelineHybrid.
  ///
  /// In en, this message translates to:
  /// **'Live hybrid cloud classification'**
  String get monitorPipelineHybrid;

  /// No description provided for @monitorPipelineDetectionOnly.
  ///
  /// In en, this message translates to:
  /// **'Live detection only'**
  String get monitorPipelineDetectionOnly;

  /// No description provided for @monitorCameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission denied. Running simulated traffic mode.'**
  String get monitorCameraPermissionDenied;

  /// No description provided for @monitorCameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {error}. Running simulated traffic mode.'**
  String monitorCameraError(String error);

  /// No description provided for @monitorCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera access is unavailable. Running simulated traffic mode.'**
  String get monitorCameraUnavailable;

  /// No description provided for @monitorClassificationUnavailable12.
  ///
  /// In en, this message translates to:
  /// **'12-class classification unavailable: {error}'**
  String monitorClassificationUnavailable12(String error);

  /// No description provided for @monitorClassificationUnavailableCoarse.
  ///
  /// In en, this message translates to:
  /// **'Coarse classification unavailable: {error}'**
  String monitorClassificationUnavailableCoarse(String error);

  /// No description provided for @monitorClassificationUnavailableHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid cloud classification unavailable: {error}'**
  String monitorClassificationUnavailableHybrid(String error);

  /// No description provided for @monitorClassificationUnavailableDisabled.
  ///
  /// In en, this message translates to:
  /// **'Live inference unavailable: {error}'**
  String monitorClassificationUnavailableDisabled(String error);

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get analyticsTimeRange;

  /// No description provided for @analyticsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get analyticsToday;

  /// No description provided for @analyticsWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get analyticsWeek;

  /// No description provided for @analyticsMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get analyticsMonth;

  /// No description provided for @analyticsCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get analyticsCustom;

  /// No description provided for @analyticsVolumeChart.
  ///
  /// In en, this message translates to:
  /// **'Traffic Volume'**
  String get analyticsVolumeChart;

  /// No description provided for @analyticsSpeedChart.
  ///
  /// In en, this message translates to:
  /// **'Speed Distribution'**
  String get analyticsSpeedChart;

  /// No description provided for @analyticsClassChart.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Classification'**
  String get analyticsClassChart;

  /// No description provided for @analyticsExport.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get analyticsExport;

  /// No description provided for @analyticsBuckets.
  ///
  /// In en, this message translates to:
  /// **'Buckets'**
  String get analyticsBuckets;

  /// No description provided for @analyticsClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get analyticsClasses;

  /// No description provided for @analyticsDemoDataLoaded.
  ///
  /// In en, this message translates to:
  /// **'Demo data loaded.'**
  String get analyticsDemoDataLoaded;

  /// No description provided for @analyticsDataAlreadyPresent.
  ///
  /// In en, this message translates to:
  /// **'Data already present.'**
  String get analyticsDataAlreadyPresent;

  /// No description provided for @analyticsLoadDemoData.
  ///
  /// In en, this message translates to:
  /// **'Load Demo Data'**
  String get analyticsLoadDemoData;

  /// No description provided for @analyticsVehiclesTooltip.
  ///
  /// In en, this message translates to:
  /// **'{time}\n{count} vehicles'**
  String analyticsVehiclesTooltip(String time, int count);

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No alerts'**
  String get alertsEmpty;

  /// No description provided for @alertsMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get alertsMarkRead;

  /// No description provided for @alertsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get alertsMarkAllRead;

  /// No description provided for @alertsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get alertsClear;

  /// No description provided for @alertDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert Detail'**
  String get alertDetailTitle;

  /// No description provided for @alertTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get alertTimestamp;

  /// No description provided for @alertSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get alertSeverityHigh;

  /// No description provided for @alertSeverityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get alertSeverityMedium;

  /// No description provided for @alertSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get alertSeverityLow;

  /// No description provided for @alertTypeIncident.
  ///
  /// In en, this message translates to:
  /// **'Incident'**
  String get alertTypeIncident;

  /// No description provided for @alertTypeAnomaly.
  ///
  /// In en, this message translates to:
  /// **'Anomaly'**
  String get alertTypeAnomaly;

  /// No description provided for @alertTypeThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get alertTypeThreshold;

  /// No description provided for @alertStatusTriggered.
  ///
  /// In en, this message translates to:
  /// **'Triggered'**
  String get alertStatusTriggered;

  /// No description provided for @alertStatusAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Ack'**
  String get alertStatusAcknowledged;

  /// No description provided for @alertStatusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get alertStatusAssigned;

  /// No description provided for @alertStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get alertStatusResolved;

  /// No description provided for @alertStatusSuppressed.
  ///
  /// In en, this message translates to:
  /// **'Suppressed'**
  String get alertStatusSuppressed;

  /// No description provided for @alertSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get alertSeverity;

  /// No description provided for @alertStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get alertStatus;

  /// No description provided for @alertCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get alertCondition;

  /// No description provided for @alertSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get alertSite;

  /// No description provided for @alertCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get alertCamera;

  /// No description provided for @alertMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get alertMessage;

  /// No description provided for @alertAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned To'**
  String get alertAssignedTo;

  /// No description provided for @alertResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get alertResolve;

  /// No description provided for @alertRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert Rules'**
  String get alertRulesTitle;

  /// No description provided for @alertRuleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Rule'**
  String get alertRuleAdd;

  /// No description provided for @alertRuleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Rule'**
  String get alertRuleEdit;

  /// No description provided for @alertRuleName.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get alertRuleName;

  /// No description provided for @alertRuleCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get alertRuleCondition;

  /// No description provided for @alertRuleThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get alertRuleThreshold;

  /// No description provided for @alertRuleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get alertRuleEnabled;

  /// No description provided for @alertRuleAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Alert Rule'**
  String get alertRuleAddTitle;

  /// No description provided for @alertRuleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule Name'**
  String get alertRuleNameLabel;

  /// No description provided for @alertConditionLabel.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get alertConditionLabel;

  /// No description provided for @alertThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get alertThresholdLabel;

  /// No description provided for @alertSeverityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get alertSeverityLabel;

  /// No description provided for @alertCondCongestion.
  ///
  /// In en, this message translates to:
  /// **'Congestion'**
  String get alertCondCongestion;

  /// No description provided for @alertCondSpeedDrop.
  ///
  /// In en, this message translates to:
  /// **'Speed Drop'**
  String get alertCondSpeedDrop;

  /// No description provided for @alertCondStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped Vehicle'**
  String get alertCondStopped;

  /// No description provided for @alertCondHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy Vehicle Share'**
  String get alertCondHeavy;

  /// No description provided for @alertCondCameraOffline.
  ///
  /// In en, this message translates to:
  /// **'Camera Offline'**
  String get alertCondCameraOffline;

  /// No description provided for @alertCondCountAnomaly.
  ///
  /// In en, this message translates to:
  /// **'Count Anomaly'**
  String get alertCondCountAnomaly;

  /// No description provided for @alertNoRules.
  ///
  /// In en, this message translates to:
  /// **'No alert rules configured'**
  String get alertNoRules;

  /// No description provided for @alertRuleCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get alertRuleCreate;

  /// No description provided for @alertRuleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{conditionType} · threshold: {threshold}'**
  String alertRuleSubtitle(String conditionType, String threshold);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsQuickSetup.
  ///
  /// In en, this message translates to:
  /// **'Quick Setup'**
  String get settingsQuickSetup;

  /// No description provided for @settingsQuickSetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Run the setup wizard again'**
  String get settingsQuickSetupDesc;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear All Local Data'**
  String get settingsClearData;

  /// No description provided for @settingsClearDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove all sites, cameras, and crossings'**
  String get settingsClearDataDesc;

  /// No description provided for @settingsClearDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Data?'**
  String get settingsClearDataConfirmTitle;

  /// No description provided for @settingsClearDataConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all local sites, cameras, ROI presets, and crossing data. This cannot be undone.'**
  String get settingsClearDataConfirmBody;

  /// No description provided for @settingsCleared.
  ///
  /// In en, this message translates to:
  /// **'All data cleared'**
  String get settingsCleared;

  /// No description provided for @settingsClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearButton;

  /// No description provided for @settingsCloudClassification.
  ///
  /// In en, this message translates to:
  /// **'Cloud Classification'**
  String get settingsCloudClassification;

  /// No description provided for @settingsVlmProvider.
  ///
  /// In en, this message translates to:
  /// **'VLM Provider'**
  String get settingsVlmProvider;

  /// No description provided for @settingsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get settingsNotConfigured;

  /// No description provided for @settingsProviderGemini.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get settingsProviderGemini;

  /// No description provided for @settingsProviderOpenai.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get settingsProviderOpenai;

  /// No description provided for @settingsProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsProvider;

  /// No description provided for @settingsAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get settingsAuth;

  /// No description provided for @settingsApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get settingsApiKey;

  /// No description provided for @settingsApiKeySecure.
  ///
  /// In en, this message translates to:
  /// **'Stored securely on device. Never sent to our servers.'**
  String get settingsApiKeySecure;

  /// No description provided for @settingsModelName.
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get settingsModelName;

  /// No description provided for @settingsConfidenceThreshold.
  ///
  /// In en, this message translates to:
  /// **'Confidence Threshold'**
  String get settingsConfidenceThreshold;

  /// No description provided for @settingsConfidenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Skip VLM when local classifier confidence exceeds this value. Lower = more VLM calls.'**
  String get settingsConfidenceDescription;

  /// No description provided for @settingsBatching.
  ///
  /// In en, this message translates to:
  /// **'Batching'**
  String get settingsBatching;

  /// No description provided for @settingsBatchingDescription.
  ///
  /// In en, this message translates to:
  /// **'Accumulate crops before sending to reduce API calls.'**
  String get settingsBatchingDescription;

  /// No description provided for @settingsBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch Size'**
  String get settingsBatchSize;

  /// No description provided for @settingsBatchTimeout.
  ///
  /// In en, this message translates to:
  /// **'Batch Timeout'**
  String get settingsBatchTimeout;

  /// No description provided for @settingsRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request Timeout'**
  String get settingsRequestTimeout;

  /// No description provided for @settingsMaxRetries.
  ///
  /// In en, this message translates to:
  /// **'Max Retries'**
  String get settingsMaxRetries;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get settingsResetDefaults;

  /// No description provided for @settingsResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset VLM Settings?'**
  String get settingsResetConfirmTitle;

  /// No description provided for @settingsResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear your API key and reset all cloud classification settings to their defaults.'**
  String get settingsResetConfirmBody;

  /// No description provided for @settingsResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetButton;

  /// No description provided for @settingsGemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get settingsGemini;

  /// No description provided for @settingsOpenai.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get settingsOpenai;

  /// No description provided for @classifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Classify Vehicle'**
  String get classifyTitle;

  /// No description provided for @classifyVehicle.
  ///
  /// In en, this message translates to:
  /// **'Classify a Vehicle'**
  String get classifyVehicle;

  /// No description provided for @classifyDescription.
  ///
  /// In en, this message translates to:
  /// **'Take a photo or pick from gallery to identify the vehicle type using two-stage AI classification.'**
  String get classifyDescription;

  /// No description provided for @classifyCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get classifyCamera;

  /// No description provided for @classifyGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get classifyGallery;

  /// No description provided for @classifyNewPhoto.
  ///
  /// In en, this message translates to:
  /// **'New Photo'**
  String get classifyNewPhoto;

  /// No description provided for @classifyLoadingModels.
  ///
  /// In en, this message translates to:
  /// **'Loading ML models...'**
  String get classifyLoadingModels;

  /// No description provided for @classifyClassifying.
  ///
  /// In en, this message translates to:
  /// **'Classifying vehicle...'**
  String get classifyClassifying;

  /// No description provided for @classifyNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles detected in this image.'**
  String get classifyNoVehicles;

  /// No description provided for @classifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Classification Failed'**
  String get classifyFailed;

  /// No description provided for @classifyUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get classifyUnknownError;

  /// No description provided for @classifyTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get classifyTryAgain;

  /// No description provided for @classifySaved.
  ///
  /// In en, this message translates to:
  /// **'Classification saved'**
  String get classifySaved;

  /// No description provided for @classifySaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save classification'**
  String get classifySaveTooltip;

  /// No description provided for @classifyStage1.
  ///
  /// In en, this message translates to:
  /// **'Stage 1 (Coarse)'**
  String get classifyStage1;

  /// No description provided for @classifyWheels.
  ///
  /// In en, this message translates to:
  /// **'Wheels Detected'**
  String get classifyWheels;

  /// No description provided for @classifyJoints.
  ///
  /// In en, this message translates to:
  /// **'Joints Detected'**
  String get classifyJoints;

  /// No description provided for @classifyAxles.
  ///
  /// In en, this message translates to:
  /// **'Estimated Axles'**
  String get classifyAxles;

  /// No description provided for @classifyTrailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get classifyTrailer;

  /// No description provided for @classifyFinalClass.
  ///
  /// In en, this message translates to:
  /// **'Final Class'**
  String get classifyFinalClass;

  /// No description provided for @classifyConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get classifyConfidence;

  /// No description provided for @classifyYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get classifyYes;

  /// No description provided for @classifyNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get classifyNo;

  /// No description provided for @classifyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get classifyUnknown;

  /// No description provided for @videoAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Analysis'**
  String get videoAnalysisTitle;

  /// No description provided for @videoAnalysisCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud Video Analysis'**
  String get videoAnalysisCloud;

  /// No description provided for @videoAnalysisDescription.
  ///
  /// In en, this message translates to:
  /// **'Record or choose a video (max 5 minutes) to run cloud-based vehicle detection and counting.'**
  String get videoAnalysisDescription;

  /// No description provided for @videoAnalysisGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get videoAnalysisGallery;

  /// No description provided for @videoAnalysisRecord.
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get videoAnalysisRecord;

  /// No description provided for @videoAnalysisPickFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a video file (MP4 or DAV)'**
  String get videoAnalysisPickFileTitle;

  /// No description provided for @videoAnalysisStartAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start analysis'**
  String get videoAnalysisStartAnalysis;

  /// No description provided for @videoAnalysisChooseDifferentFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a different file'**
  String get videoAnalysisChooseDifferentFile;

  /// No description provided for @videoAnalysisStagedFile.
  ///
  /// In en, this message translates to:
  /// **'Selected: {filename}'**
  String videoAnalysisStagedFile(String filename);

  /// No description provided for @videoAnalysisStagedHint.
  ///
  /// In en, this message translates to:
  /// **'Review the tasks below, then tap Start to upload and analyze.'**
  String get videoAnalysisStagedHint;

  /// No description provided for @videoAnalysisBusStopPreset.
  ///
  /// In en, this message translates to:
  /// **'Bus stop preset'**
  String get videoAnalysisBusStopPreset;

  /// No description provided for @videoAnalysisBusStopPresetHint.
  ///
  /// In en, this message translates to:
  /// **'One-tap setup for a bus stop: disables vehicle counting, enables transit (boarding / alighting) and pedestrians.'**
  String get videoAnalysisBusStopPresetHint;

  /// No description provided for @videoAnalysisBusStopApplied.
  ///
  /// In en, this message translates to:
  /// **'Bus stop preset applied — vehicle counting is off.'**
  String get videoAnalysisBusStopApplied;

  /// No description provided for @videoAnalysisCountLineConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure count lines'**
  String get videoAnalysisCountLineConfigure;

  /// No description provided for @videoAnalysisCountLineConfigured.
  ///
  /// In en, this message translates to:
  /// **'IN/OUT lines set'**
  String get videoAnalysisCountLineConfigured;

  /// No description provided for @videoAnalysisDavNotSupported.
  ///
  /// In en, this message translates to:
  /// **'DAV files cannot be uploaded for analysis. Open the Speed, Transit, or Traffic-light editor to use this file as a calibration backdrop, or transcode it to MP4 first.'**
  String get videoAnalysisDavNotSupported;

  /// No description provided for @videoAnalysisUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading and analyzing…'**
  String get videoAnalysisUploading;

  /// No description provided for @videoAnalysisUploadingHint.
  ///
  /// In en, this message translates to:
  /// **'This may take several minutes depending on video length.'**
  String get videoAnalysisUploadingHint;

  /// No description provided for @videoAnalysisProcessing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing video on server…'**
  String get videoAnalysisProcessing;

  /// No description provided for @videoAnalysisProcessingHint.
  ///
  /// In en, this message translates to:
  /// **'The video has been uploaded. The server is processing it now. This may take several minutes depending on video length.'**
  String get videoAnalysisProcessingHint;

  /// No description provided for @videoAnalysisTotalCounted.
  ///
  /// In en, this message translates to:
  /// **'Total vehicles counted'**
  String get videoAnalysisTotalCounted;

  /// No description provided for @videoAnalysisBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Breakdown by Class'**
  String get videoAnalysisBreakdown;

  /// No description provided for @videoAnalysisExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get videoAnalysisExportCsv;

  /// No description provided for @videoAnalysisRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get videoAnalysisRetry;

  /// No description provided for @videoAnalysisIncludeAnnotatedVideo.
  ///
  /// In en, this message translates to:
  /// **'Generate annotated video'**
  String get videoAnalysisIncludeAnnotatedVideo;

  /// No description provided for @videoAnalysisIncludeAnnotatedVideoHint.
  ///
  /// In en, this message translates to:
  /// **'Adds a labeled MP4 you can download after analysis. Increases processing time.'**
  String get videoAnalysisIncludeAnnotatedVideoHint;

  /// No description provided for @videoAnalysisDownloadVideo.
  ///
  /// In en, this message translates to:
  /// **'Download annotated video'**
  String get videoAnalysisDownloadVideo;

  /// No description provided for @videoAnalysisDownloadTransitVideo.
  ///
  /// In en, this message translates to:
  /// **'Download transit overlay video'**
  String get videoAnalysisDownloadTransitVideo;

  /// No description provided for @videoAnalysisDownloadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Downloading annotated video…'**
  String get videoAnalysisDownloadingVideo;

  /// No description provided for @videoAnalysisDownloadCanceled.
  ///
  /// In en, this message translates to:
  /// **'Download canceled.'**
  String get videoAnalysisDownloadCanceled;

  /// No description provided for @videoAnalysisDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String videoAnalysisDownloadSaved(String path);

  /// No description provided for @videoAnalysisTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks to run'**
  String get videoAnalysisTasksTitle;

  /// No description provided for @videoAnalysisTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Each task needs site calibration to produce useful numbers. Defaults assume a centered road in the lower half of the frame.'**
  String get videoAnalysisTasksHint;

  /// No description provided for @videoAnalysisTaskVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles (counting + classification)'**
  String get videoAnalysisTaskVehicles;

  /// No description provided for @videoAnalysisTaskPedestrians.
  ///
  /// In en, this message translates to:
  /// **'Pedestrians (people crossing)'**
  String get videoAnalysisTaskPedestrians;

  /// No description provided for @videoAnalysisTaskSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed (two-line measurement)'**
  String get videoAnalysisTaskSpeed;

  /// No description provided for @videoAnalysisTaskTransit.
  ///
  /// In en, this message translates to:
  /// **'Transit (boarding / alighting / density)'**
  String get videoAnalysisTaskTransit;

  /// No description provided for @videoAnalysisTaskTrafficLight.
  ///
  /// In en, this message translates to:
  /// **'Traffic-light timing'**
  String get videoAnalysisTaskTrafficLight;

  /// No description provided for @videoAnalysisTaskLpr.
  ///
  /// In en, this message translates to:
  /// **'License plates (resident vs visitor)'**
  String get videoAnalysisTaskLpr;

  /// No description provided for @videoAnalysisPedestrianTitle.
  ///
  /// In en, this message translates to:
  /// **'Pedestrians'**
  String get videoAnalysisPedestrianTitle;

  /// No description provided for @videoAnalysisPedestrianCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pedestrians counted} one{1 pedestrian counted} other{{count} pedestrians counted}}'**
  String videoAnalysisPedestrianCount(int count);

  /// No description provided for @videoAnalysisPedestrianDetectorOff.
  ///
  /// In en, this message translates to:
  /// **'Pedestrian detector is off — set ENABLE_PEDESTRIAN_DETECTOR=1 on the server.'**
  String get videoAnalysisPedestrianDetectorOff;

  /// No description provided for @videoAnalysisSpeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get videoAnalysisSpeedTitle;

  /// No description provided for @videoAnalysisSpeedNoMeasurements.
  ///
  /// In en, this message translates to:
  /// **'No vehicles crossed both speed lines.'**
  String get videoAnalysisSpeedNoMeasurements;

  /// No description provided for @videoAnalysisSpeedAvg.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get videoAnalysisSpeedAvg;

  /// No description provided for @videoAnalysisSpeedMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get videoAnalysisSpeedMin;

  /// No description provided for @videoAnalysisSpeedMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get videoAnalysisSpeedMax;

  /// No description provided for @videoAnalysisSpeedKmh.
  ///
  /// In en, this message translates to:
  /// **'{value} km/h'**
  String videoAnalysisSpeedKmh(String value);

  /// No description provided for @videoAnalysisSpeedMeasured.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vehicle measured} other{{count} vehicles measured}}'**
  String videoAnalysisSpeedMeasured(int count);

  /// No description provided for @videoAnalysisSpeedPerTrack.
  ///
  /// In en, this message translates to:
  /// **'Per-vehicle speeds'**
  String get videoAnalysisSpeedPerTrack;

  /// No description provided for @videoAnalysisSpeedTrackRow.
  ///
  /// In en, this message translates to:
  /// **'Track {trackId}'**
  String videoAnalysisSpeedTrackRow(String trackId);

  /// No description provided for @videoAnalysisTransitTitle.
  ///
  /// In en, this message translates to:
  /// **'Public transit'**
  String get videoAnalysisTransitTitle;

  /// No description provided for @videoAnalysisTransitBoarding.
  ///
  /// In en, this message translates to:
  /// **'Boarding'**
  String get videoAnalysisTransitBoarding;

  /// No description provided for @videoAnalysisTransitAlighting.
  ///
  /// In en, this message translates to:
  /// **'Alighting'**
  String get videoAnalysisTransitAlighting;

  /// No description provided for @videoAnalysisTransitPeak.
  ///
  /// In en, this message translates to:
  /// **'Peak inside stop'**
  String get videoAnalysisTransitPeak;

  /// No description provided for @videoAnalysisTransitDensity.
  ///
  /// In en, this message translates to:
  /// **'Avg density'**
  String get videoAnalysisTransitDensity;

  /// No description provided for @videoAnalysisTransitDensityValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String videoAnalysisTransitDensityValue(String value);

  /// No description provided for @videoAnalysisTransitBusGated.
  ///
  /// In en, this message translates to:
  /// **'Counts gated to bus presence.'**
  String get videoAnalysisTransitBusGated;

  /// No description provided for @videoAnalysisTransitNotGated.
  ///
  /// In en, this message translates to:
  /// **'All door-line crossings counted (no bus-zone gate).'**
  String get videoAnalysisTransitNotGated;

  /// No description provided for @videoAnalysisTrafficLightTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic-light timing'**
  String get videoAnalysisTrafficLightTitle;

  /// No description provided for @videoAnalysisTrafficLightLabel.
  ///
  /// In en, this message translates to:
  /// **'Light: {label}'**
  String videoAnalysisTrafficLightLabel(String label);

  /// No description provided for @videoAnalysisTrafficLightCycles.
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get videoAnalysisTrafficLightCycles;

  /// No description provided for @videoAnalysisTrafficLightAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get videoAnalysisTrafficLightAvgDuration;

  /// No description provided for @videoAnalysisTrafficLightTotalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get videoAnalysisTrafficLightTotalDuration;

  /// No description provided for @videoAnalysisTrafficLightSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String videoAnalysisTrafficLightSeconds(String value);

  /// No description provided for @videoAnalysisTrafficLightRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get videoAnalysisTrafficLightRed;

  /// No description provided for @videoAnalysisTrafficLightGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get videoAnalysisTrafficLightGreen;

  /// No description provided for @videoAnalysisTrafficLightYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get videoAnalysisTrafficLightYellow;

  /// No description provided for @videoAnalysisLprTitle.
  ///
  /// In en, this message translates to:
  /// **'License plates'**
  String get videoAnalysisLprTitle;

  /// No description provided for @videoAnalysisLprResident.
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get videoAnalysisLprResident;

  /// No description provided for @videoAnalysisLprVisitor.
  ///
  /// In en, this message translates to:
  /// **'Visitor'**
  String get videoAnalysisLprVisitor;

  /// No description provided for @videoAnalysisLprAllowlistSize.
  ///
  /// In en, this message translates to:
  /// **'Allowlist: {count} plate(s)'**
  String videoAnalysisLprAllowlistSize(int count);

  /// No description provided for @videoAnalysisLprPrivacyHashed.
  ///
  /// In en, this message translates to:
  /// **'Plate text stored as SHA-256 prefix (privacy mode).'**
  String get videoAnalysisLprPrivacyHashed;

  /// No description provided for @videoAnalysisLprPlatePrefix.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get videoAnalysisLprPlatePrefix;

  /// No description provided for @videoAnalysisLprHashPrefix.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get videoAnalysisLprHashPrefix;

  /// No description provided for @videoAnalysisConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get videoAnalysisConfigure;

  /// No description provided for @videoAnalysisConfigureNoVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick a video first to enable per-task configuration.'**
  String get videoAnalysisConfigureNoVideo;

  /// No description provided for @videoAnalysisRoiConfigured.
  ///
  /// In en, this message translates to:
  /// **'ROI set: {label} ({width}×{height}, {position})'**
  String videoAnalysisRoiConfigured(
      String label, String width, String height, String position);

  /// No description provided for @roiEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Traffic-light ROI'**
  String get roiEditorTitle;

  /// No description provided for @roiEditorLabel.
  ///
  /// In en, this message translates to:
  /// **'Light label (e.g. main, left_turn)'**
  String get roiEditorLabel;

  /// No description provided for @roiEditorReset.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get roiEditorReset;

  /// No description provided for @roiEditorSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get roiEditorSave;

  /// No description provided for @roiEditorCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get roiEditorCancel;

  /// No description provided for @roiEditorPickStill.
  ///
  /// In en, this message translates to:
  /// **'Pick a still image instead'**
  String get roiEditorPickStill;

  /// No description provided for @roiEditorPickBackdrop.
  ///
  /// In en, this message translates to:
  /// **'Choose backdrop file'**
  String get roiEditorPickBackdrop;

  /// No description provided for @roiEditorPickBackdropTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick MP4, DAV, or still image'**
  String get roiEditorPickBackdropTitle;

  /// No description provided for @roiEditorNoBackdrop.
  ///
  /// In en, this message translates to:
  /// **'No backdrop loaded yet. Pick an MP4, DAV, or still image of the scene to start drawing.'**
  String get roiEditorNoBackdrop;

  /// No description provided for @roiEditorFrameLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t extract a frame from the video. Pick a still image of the same scene.'**
  String get roiEditorFrameLoadFailed;

  /// No description provided for @roiEditorRoiTooSmall.
  ///
  /// In en, this message translates to:
  /// **'ROI is too small. Pick two corners further apart.'**
  String get roiEditorRoiTooSmall;

  /// No description provided for @roiEditorHintTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Tap the TOP-LEFT corner of the signal head.'**
  String get roiEditorHintTopLeft;

  /// No description provided for @roiEditorHintBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Tap the BOTTOM-RIGHT corner of the signal head.'**
  String get roiEditorHintBottomRight;

  /// No description provided for @roiEditorHintRefine.
  ///
  /// In en, this message translates to:
  /// **'Tap to refine either corner. Press Save when ready.'**
  String get roiEditorHintRefine;

  /// No description provided for @lprAllowlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Resident plates'**
  String get lprAllowlistTitle;

  /// No description provided for @lprAllowlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No resident plates yet. Add the first one below.'**
  String get lprAllowlistEmpty;

  /// No description provided for @lprAllowlistHint.
  ///
  /// In en, this message translates to:
  /// **'Korean format: NNga NNNN (e.g. 12가 3456). Spaces are stripped automatically.'**
  String get lprAllowlistHint;

  /// No description provided for @lprAllowlistAddHint.
  ///
  /// In en, this message translates to:
  /// **'Plate (e.g. 12가 3456)'**
  String get lprAllowlistAddHint;

  /// No description provided for @lprAllowlistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get lprAllowlistAdd;

  /// No description provided for @lprAllowlistInvalid.
  ///
  /// In en, this message translates to:
  /// **'Plate doesn\'t match the Korean format (NN(N)가 NNNN).'**
  String get lprAllowlistInvalid;

  /// No description provided for @lprAllowlistDuplicate.
  ///
  /// In en, this message translates to:
  /// **'That plate is already on the allowlist.'**
  String get lprAllowlistDuplicate;

  /// No description provided for @lprAllowlistRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get lprAllowlistRemove;

  /// No description provided for @lprAllowlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No plates} one{1 plate} other{{count} plates}}'**
  String lprAllowlistCount(int count);

  /// No description provided for @lprAllowlistConfigure.
  ///
  /// In en, this message translates to:
  /// **'Manage allowlist'**
  String get lprAllowlistConfigure;

  /// No description provided for @speedEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Speed lines & quad'**
  String get speedEditorTitle;

  /// No description provided for @speedEditorResetQuad.
  ///
  /// In en, this message translates to:
  /// **'Clear quad'**
  String get speedEditorResetQuad;

  /// No description provided for @speedEditorModeQuad.
  ///
  /// In en, this message translates to:
  /// **'Quad ({count}/4)'**
  String speedEditorModeQuad(int count);

  /// No description provided for @speedEditorModeLine1.
  ///
  /// In en, this message translates to:
  /// **'Line 1'**
  String get speedEditorModeLine1;

  /// No description provided for @speedEditorModeLine2.
  ///
  /// In en, this message translates to:
  /// **'Line 2'**
  String get speedEditorModeLine2;

  /// No description provided for @speedEditorWidthM.
  ///
  /// In en, this message translates to:
  /// **'Width (m)'**
  String get speedEditorWidthM;

  /// No description provided for @speedEditorLengthM.
  ///
  /// In en, this message translates to:
  /// **'Length (m)'**
  String get speedEditorLengthM;

  /// No description provided for @speedEditorHintQuad.
  ///
  /// In en, this message translates to:
  /// **'Tap {remaining} more corner(s) of a known real-world rectangle (e.g. lane markings).'**
  String speedEditorHintQuad(int remaining);

  /// No description provided for @speedEditorHintQuadDone.
  ///
  /// In en, this message translates to:
  /// **'Quad complete. Tap again to start over, or switch to Line 1 / Line 2.'**
  String get speedEditorHintQuadDone;

  /// No description provided for @speedEditorHintLine1Start.
  ///
  /// In en, this message translates to:
  /// **'Tap the START point of Line 1 (entry).'**
  String get speedEditorHintLine1Start;

  /// No description provided for @speedEditorHintLine1End.
  ///
  /// In en, this message translates to:
  /// **'Tap the END point of Line 1 (entry).'**
  String get speedEditorHintLine1End;

  /// No description provided for @speedEditorHintLine1Done.
  ///
  /// In en, this message translates to:
  /// **'Line 1 set. Tap again to redraw.'**
  String get speedEditorHintLine1Done;

  /// No description provided for @speedEditorHintLine2Start.
  ///
  /// In en, this message translates to:
  /// **'Tap the START point of Line 2 (exit).'**
  String get speedEditorHintLine2Start;

  /// No description provided for @speedEditorHintLine2End.
  ///
  /// In en, this message translates to:
  /// **'Tap the END point of Line 2 (exit).'**
  String get speedEditorHintLine2End;

  /// No description provided for @speedEditorHintLine2Done.
  ///
  /// In en, this message translates to:
  /// **'Line 2 set. Tap again to redraw.'**
  String get speedEditorHintLine2Done;

  /// No description provided for @speedEditorSnapHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Snap lines to horizontal'**
  String get speedEditorSnapHorizontal;

  /// No description provided for @speedEditorSnapHorizontalHint.
  ///
  /// In en, this message translates to:
  /// **'Forces both lines to be perfectly horizontal — old behavior; uncheck for arbitrary lines.'**
  String get speedEditorSnapHorizontalHint;

  /// No description provided for @speedEditorQuadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Tap all 4 quad corners before saving.'**
  String get speedEditorQuadIncomplete;

  /// No description provided for @speedEditorLinesIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Both speed lines need 2 endpoints each before saving.'**
  String get speedEditorLinesIncomplete;

  /// No description provided for @speedEditorLinesTooClose.
  ///
  /// In en, this message translates to:
  /// **'Lines must be at least 5% of frame height apart.'**
  String get speedEditorLinesTooClose;

  /// No description provided for @speedEditorBadMetres.
  ///
  /// In en, this message translates to:
  /// **'Width and length must be positive numbers in metres.'**
  String get speedEditorBadMetres;

  /// No description provided for @countLineEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Count lines (IN / OUT)'**
  String get countLineEditorTitle;

  /// No description provided for @countLineEditorModeIn.
  ///
  /// In en, this message translates to:
  /// **'IN line'**
  String get countLineEditorModeIn;

  /// No description provided for @countLineEditorModeOut.
  ///
  /// In en, this message translates to:
  /// **'OUT line'**
  String get countLineEditorModeOut;

  /// No description provided for @countLineEditorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset line'**
  String get countLineEditorReset;

  /// No description provided for @countLineEditorHintInStart.
  ///
  /// In en, this message translates to:
  /// **'Tap the START point of the IN line.'**
  String get countLineEditorHintInStart;

  /// No description provided for @countLineEditorHintInEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap the END point of the IN line.'**
  String get countLineEditorHintInEnd;

  /// No description provided for @countLineEditorHintInDone.
  ///
  /// In en, this message translates to:
  /// **'IN line set. Tap again to redraw.'**
  String get countLineEditorHintInDone;

  /// No description provided for @countLineEditorHintOutStart.
  ///
  /// In en, this message translates to:
  /// **'Tap the START point of the OUT line.'**
  String get countLineEditorHintOutStart;

  /// No description provided for @countLineEditorHintOutEnd.
  ///
  /// In en, this message translates to:
  /// **'Tap the END point of the OUT line.'**
  String get countLineEditorHintOutEnd;

  /// No description provided for @countLineEditorHintOutDone.
  ///
  /// In en, this message translates to:
  /// **'OUT line set. Tap again to redraw.'**
  String get countLineEditorHintOutDone;

  /// No description provided for @countLineEditorIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Both lines need 2 endpoints each before saving.'**
  String get countLineEditorIncomplete;

  /// No description provided for @countLineEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Vehicles count once when a track crosses both lines, in either order. Place IN where vehicles enter the scene and OUT where they leave.'**
  String get countLineEditorDescription;

  /// No description provided for @transitEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Bus stop & door line'**
  String get transitEditorTitle;

  /// No description provided for @transitEditorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo last point'**
  String get transitEditorUndo;

  /// No description provided for @transitEditorModeStopPolygon.
  ///
  /// In en, this message translates to:
  /// **'Stop polygon'**
  String get transitEditorModeStopPolygon;

  /// No description provided for @transitEditorModeDoorLine.
  ///
  /// In en, this message translates to:
  /// **'Door line'**
  String get transitEditorModeDoorLine;

  /// No description provided for @transitEditorModeBusZone.
  ///
  /// In en, this message translates to:
  /// **'Bus zone'**
  String get transitEditorModeBusZone;

  /// No description provided for @transitEditorBusZoneEnable.
  ///
  /// In en, this message translates to:
  /// **'Gate counting on bus presence'**
  String get transitEditorBusZoneEnable;

  /// No description provided for @transitEditorBusZoneHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, door-line crossings only count while a bus overlaps this polygon.'**
  String get transitEditorBusZoneHint;

  /// No description provided for @transitEditorBusZoneDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bus-zone gating is off — every door-line crossing counts.'**
  String get transitEditorBusZoneDisabled;

  /// No description provided for @transitEditorCapacity.
  ///
  /// In en, this message translates to:
  /// **'Max capacity (persons)'**
  String get transitEditorCapacity;

  /// No description provided for @transitEditorCapacityHint.
  ///
  /// In en, this message translates to:
  /// **'Density % = persons inside the stop polygon ÷ capacity.'**
  String get transitEditorCapacityHint;

  /// No description provided for @transitEditorHintStopPolygon.
  ///
  /// In en, this message translates to:
  /// **'Tap to add a polygon vertex. {remaining} more needed.'**
  String transitEditorHintStopPolygon(int remaining);

  /// No description provided for @transitEditorHintStopPolygonDone.
  ///
  /// In en, this message translates to:
  /// **'Stop polygon ready. Add more vertices or switch tabs.'**
  String get transitEditorHintStopPolygonDone;

  /// No description provided for @transitEditorHintDoorLine.
  ///
  /// In en, this message translates to:
  /// **'Tap to set door-line endpoint {remaining} of 2.'**
  String transitEditorHintDoorLine(int remaining);

  /// No description provided for @transitEditorHintDoorLineDone.
  ///
  /// In en, this message translates to:
  /// **'Door line ready. Tap again to redraw.'**
  String get transitEditorHintDoorLineDone;

  /// No description provided for @transitEditorHintBusZone.
  ///
  /// In en, this message translates to:
  /// **'Tap to add a bus-zone vertex. {remaining} more needed.'**
  String transitEditorHintBusZone(int remaining);

  /// No description provided for @transitEditorHintBusZoneDone.
  ///
  /// In en, this message translates to:
  /// **'Bus zone ready.'**
  String get transitEditorHintBusZoneDone;

  /// No description provided for @transitEditorStopPolygonTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Stop polygon needs at least 3 vertices.'**
  String get transitEditorStopPolygonTooSmall;

  /// No description provided for @transitEditorDoorLineIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Door line needs exactly 2 endpoints.'**
  String get transitEditorDoorLineIncomplete;

  /// No description provided for @transitEditorBusZoneTooSmall.
  ///
  /// In en, this message translates to:
  /// **'Bus zone needs at least 3 vertices (or turn it off).'**
  String get transitEditorBusZoneTooSmall;

  /// No description provided for @transitEditorBadCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity must be a positive integer.'**
  String get transitEditorBadCapacity;

  /// No description provided for @calibrationModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get calibrationModeAuto;

  /// No description provided for @calibrationModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get calibrationModeManual;

  /// No description provided for @transitAutoModeTitle.
  ///
  /// In en, this message translates to:
  /// **'AI auto-detect mode'**
  String get transitAutoModeTitle;

  /// No description provided for @transitAutoModeBody.
  ///
  /// In en, this message translates to:
  /// **'AI analyses one keyframe of the video and finds the bus stop area, door line, and bus parking spot automatically. You only need to enter the capacity.'**
  String get transitAutoModeBody;

  /// No description provided for @transitManualModeBody.
  ///
  /// In en, this message translates to:
  /// **'Switch to Manual to draw the regions yourself.'**
  String get transitManualModeBody;

  /// No description provided for @transitWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What does this configure?'**
  String get transitWhatIsThisTitle;

  /// No description provided for @transitWhatIsThisBody.
  ///
  /// In en, this message translates to:
  /// **'The stop polygon (green) is where people stand — used to compute density (%). The door line (yellow) sits across the bus door — people crossing it count as boarding/alighting. The bus zone (blue) is where the bus parks — boarding only counts while a bus overlaps it.'**
  String get transitWhatIsThisBody;

  /// No description provided for @lightAutoModeTitle.
  ///
  /// In en, this message translates to:
  /// **'AI auto-detect mode'**
  String get lightAutoModeTitle;

  /// No description provided for @lightAutoModeBody.
  ///
  /// In en, this message translates to:
  /// **'AI finds the traffic light in the video automatically. Just provide a label (used to disambiguate when multiple lights are visible).'**
  String get lightAutoModeBody;

  /// No description provided for @lightManualModeBody.
  ///
  /// In en, this message translates to:
  /// **'Switch to Manual to draw the ROI yourself.'**
  String get lightManualModeBody;

  /// No description provided for @lightAutoLabelField.
  ///
  /// In en, this message translates to:
  /// **'Label (e.g. straight, left_turn)'**
  String get lightAutoLabelField;

  /// No description provided for @lightWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What does this configure?'**
  String get lightWhatIsThisTitle;

  /// No description provided for @lightWhatIsThisBody.
  ///
  /// In en, this message translates to:
  /// **'The traffic-light ROI is a tight box around the lamp housing only — no sky, no pole, no signs. A loose box pulls in dark background pixels and confuses the colour state machine.'**
  String get lightWhatIsThisBody;

  /// No description provided for @speedWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What does this configure?'**
  String get speedWhatIsThisTitle;

  /// No description provided for @speedWhatIsThisBody.
  ///
  /// In en, this message translates to:
  /// **'The trapezoid removes the camera\'s perspective so the road looks like a top-down view. The width / length in metres convert pixels to metres, and the two lines time how long a vehicle takes to travel between them — that gives km/h. Use the lane width (usually 3.5 m) and a known distance.'**
  String get speedWhatIsThisBody;

  /// No description provided for @speedDefaultPresetButton.
  ///
  /// In en, this message translates to:
  /// **'Apply preset (1 lane 3.5m × 10m)'**
  String get speedDefaultPresetButton;

  /// No description provided for @speedDefaultPresetApplied.
  ///
  /// In en, this message translates to:
  /// **'Default preset applied. Adjust to fit your video.'**
  String get speedDefaultPresetApplied;

  /// No description provided for @countLineWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What does this configure?'**
  String get countLineWhatIsThisTitle;

  /// No description provided for @countLineWhatIsThisBody.
  ///
  /// In en, this message translates to:
  /// **'Two virtual lines: a vehicle is counted as one only when its track crosses BOTH lines (order doesn\'t matter). More accurate than a single tripwire and separates IN vs OUT direction.'**
  String get countLineWhatIsThisBody;

  /// No description provided for @lprWhatIsThisTitle.
  ///
  /// In en, this message translates to:
  /// **'What does this configure?'**
  String get lprWhatIsThisTitle;

  /// No description provided for @lprWhatIsThisBody.
  ///
  /// In en, this message translates to:
  /// **'Plates on the allowlist are tagged \'resident\', others \'visitor\'. The AI reads plates automatically — no ROI needed.'**
  String get lprWhatIsThisBody;

  /// No description provided for @calibrationResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset site calibration'**
  String get calibrationResetTooltip;

  /// No description provided for @calibrationResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset calibration?'**
  String get calibrationResetTitle;

  /// No description provided for @calibrationResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Clears every per-task setting saved for this site (enabled tasks, ROIs, speed lines, transit polygons, plate allowlist). Cannot be undone.'**
  String get calibrationResetMessage;

  /// No description provided for @calibrationResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get calibrationResetConfirm;

  /// No description provided for @calibrationResetDone.
  ///
  /// In en, this message translates to:
  /// **'Site calibration cleared.'**
  String get calibrationResetDone;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'GreyEye Traffic Report'**
  String get reportTitle;

  /// No description provided for @reportCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera: {cameraId}'**
  String reportCamera(String cameraId);

  /// No description provided for @reportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period: {period}'**
  String reportPeriod(String period);

  /// No description provided for @reportNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get reportNA;

  /// No description provided for @reportTotalCrossings.
  ///
  /// In en, this message translates to:
  /// **'Total crossings: {count}'**
  String reportTotalCrossings(int count);

  /// No description provided for @reportByClass.
  ///
  /// In en, this message translates to:
  /// **'By Vehicle Class'**
  String get reportByClass;

  /// No description provided for @reportByDirection.
  ///
  /// In en, this message translates to:
  /// **'By Direction'**
  String get reportByDirection;

  /// No description provided for @reportRawCrossings.
  ///
  /// In en, this message translates to:
  /// **'Raw Crossings (first 200)'**
  String get reportRawCrossings;

  /// No description provided for @reportHeaderClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get reportHeaderClass;

  /// No description provided for @reportHeaderCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get reportHeaderCount;

  /// No description provided for @reportHeaderDirection.
  ///
  /// In en, this message translates to:
  /// **'Direction'**
  String get reportHeaderDirection;

  /// No description provided for @reportHeaderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reportHeaderTime;

  /// No description provided for @reportHeaderDir.
  ///
  /// In en, this message translates to:
  /// **'Dir'**
  String get reportHeaderDir;

  /// No description provided for @reportHeaderConf.
  ///
  /// In en, this message translates to:
  /// **'Conf'**
  String get reportHeaderConf;

  /// No description provided for @exportExported.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} crossings'**
  String exportExported(int count);

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get exportFormat;

  /// No description provided for @exportSelectRange.
  ///
  /// In en, this message translates to:
  /// **'Please select a date range'**
  String get exportSelectRange;

  /// No description provided for @exportStarted.
  ///
  /// In en, this message translates to:
  /// **'Export started'**
  String get exportStarted;

  /// No description provided for @exportSelectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get exportSelectDateRange;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorServer;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Resource not found.'**
  String get errorNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
