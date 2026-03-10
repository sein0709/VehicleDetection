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

  /// No description provided for @setupDefaultLineNote.
  ///
  /// In en, this message translates to:
  /// **'A default counting line will be created. You can edit it later in the ROI editor.'**
  String get setupDefaultLineNote;

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
