// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'GreyEye';

  @override
  String get appTagline => '지능형 교통 모니터링';

  @override
  String get loginTitle => '로그인';

  @override
  String get loginEmail => '이메일 주소';

  @override
  String get loginPassword => '비밀번호';

  @override
  String get loginButton => '로그인';

  @override
  String get loginForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get loginInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다';

  @override
  String get loginFieldRequired => '필수 입력 항목입니다';

  @override
  String get loginInvalidEmail => '유효한 이메일 주소를 입력하세요';

  @override
  String get loginEnterEmailFirst => '먼저 이메일 주소를 입력하세요';

  @override
  String get loginResetEmailSent => '비밀번호 재설정 이메일이 발송되었습니다. 받은편지함을 확인하세요.';

  @override
  String get loginOfflineModeActive => '오프라인 모드 활성 중';

  @override
  String get loginOfflineModeDescription =>
      'Supabase가 구성되지 않아 인증이 생략되며 로컬 대시보드를 바로 사용할 수 있습니다.';

  @override
  String get loginOpenDashboard => '대시보드 열기';

  @override
  String get registerTitle => '계정 만들기';

  @override
  String get registerName => '이름';

  @override
  String get registerEmail => '이메일 주소';

  @override
  String get registerPassword => '비밀번호';

  @override
  String get registerConfirmPassword => '비밀번호 확인';

  @override
  String get registerOrganization => '소속 기관';

  @override
  String get registerButton => '계정 만들기';

  @override
  String get registerPasswordMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get registerAlreadyHaveAccount => '이미 계정이 있으신가요? 로그인';

  @override
  String get registerAuthDisabled => '인증이 비활성화되었습니다';

  @override
  String get registerAuthDisabledDescription =>
      '계정 생성을 활성화하려면 Supabase 환경 변수를 구성하세요. 로컬 대시보드는 구성 없이도 사용할 수 있습니다.';

  @override
  String get setupTitle => '초기 설정';

  @override
  String get setupWelcome => 'GreyEye에 오신 것을 환영합니다';

  @override
  String get setupAddSite => '첫 번째 모니터링 사이트를 추가하세요';

  @override
  String get setupComplete => '설정 완료';

  @override
  String get setupNext => '다음';

  @override
  String get setupAddCameraPrompt => '이 사이트에 첫 번째 카메라를 추가하세요.';

  @override
  String get setupDefaultLineNote =>
      '기본 카운팅 라인이 생성됩니다. 나중에 ROI 편집기에서 수정할 수 있습니다.';

  @override
  String get setupDefaultLinePreview => '기본 카운팅 라인 미리보기';

  @override
  String get setupCreateAndContinue => '생성 후 계속';

  @override
  String get setupVerifySite => '사이트';

  @override
  String get setupVerifyCamera => '카메라';

  @override
  String get setupVerifyCountingLine => '카운팅 라인';

  @override
  String get setupDefaultHorizontal => '기본값 (수평)';

  @override
  String get setupActivateAndStart => '활성화 및 시작';

  @override
  String get setupReadyMessage => '모니터링 사이트가 준비되었습니다. 교통 데이터 수집을 시작하세요.';

  @override
  String get setupGoToDashboard => '대시보드로 이동';

  @override
  String get setupOpenMonitor => '실시간 모니터 열기';

  @override
  String get setupOpenRoiEditor => 'ROI 편집기 열기';

  @override
  String get setupStepCreateSite => '사이트 생성';

  @override
  String get setupStepAddCamera => '카메라 추가';

  @override
  String get setupStepDrawLines => '카운팅 라인 그리기';

  @override
  String get setupStepVerify => '설정 확인';

  @override
  String get setupStepStart => '모니터링 시작';

  @override
  String get navHome => '홈';

  @override
  String get navAlerts => '알림';

  @override
  String get navSettings => '설정';

  @override
  String get navClassify => '분류';

  @override
  String get homeTitle => '대시보드';

  @override
  String get homeSites => '사이트';

  @override
  String get homeActiveCameras => '활성 카메라';

  @override
  String get homeTotalVehicles => '총 차량 수';

  @override
  String get homeAlertCount => '활성 알림';

  @override
  String get homeRecentActivity => '최근 활동';

  @override
  String get homeNoSites => '구성된 모니터링 사이트가 없습니다';

  @override
  String get homeAddSite => '사이트 추가';

  @override
  String get siteListTitle => '모니터링 사이트';

  @override
  String get siteDetailTitle => '사이트 상세';

  @override
  String get siteAddTitle => '사이트 추가';

  @override
  String get siteEditTitle => '사이트 편집';

  @override
  String get siteName => '사이트 이름';

  @override
  String get siteAddress => '주소';

  @override
  String get siteStatus => '상태';

  @override
  String get siteStatusOnline => '온라인';

  @override
  String get siteStatusOffline => '오프라인';

  @override
  String siteCameraCount(int count) {
    return '카메라 $count대';
  }

  @override
  String get siteAnalyzeVideo => '로컬 영상 분석';

  @override
  String get siteAnalyzeVideoDesc => '영상을 업로드하여 차량을 계수합니다';

  @override
  String get cameraListTitle => '카메라';

  @override
  String get cameraDetailTitle => '카메라 상세';

  @override
  String get cameraAddTitle => '카메라 추가';

  @override
  String get cameraName => '카메라 이름';

  @override
  String get cameraStreamUrl => '스트림 URL';

  @override
  String get cameraStatus => '상태';

  @override
  String get cameraLive => '실시간';

  @override
  String get cameraOffline => '오프라인';

  @override
  String get cameraSourceType => '소스 유형';

  @override
  String get cameraTargetFps => '목표 FPS';

  @override
  String get cameraResolution => '해상도';

  @override
  String get cameraClassificationMode => '분류 모드';

  @override
  String get cameraNightMode => '야간 모드';

  @override
  String get cameraSource => '소스';

  @override
  String get cameraSourceSmartphone => '스마트폰';

  @override
  String get cameraSourceRtsp => 'RTSP';

  @override
  String get cameraSourceOnvif => 'ONVIF';

  @override
  String get classificationFull12 => '전체 12종 분류';

  @override
  String get classificationCoarse => '대분류 (승용/버스/트럭/트레일러)';

  @override
  String get classificationDisabled => '비활성';

  @override
  String get nightModeOn => '켜짐';

  @override
  String get nightModeOff => '꺼짐';

  @override
  String get menuLiveMonitor => '실시간 모니터';

  @override
  String get menuRoiEditor => 'ROI 편집기';

  @override
  String get menuAnalytics => '분석';

  @override
  String get menuSettings => '설정';

  @override
  String get roiTitle => '관심 영역';

  @override
  String get roiDraw => 'ROI 그리기';

  @override
  String get roiReset => '초기화';

  @override
  String get roiSave => 'ROI 저장';

  @override
  String get roiInstructions => '카메라 화면에서 다각형 꼭짓점을 탭하여 지정하세요';

  @override
  String get roiPresetName => '프리셋 이름';

  @override
  String get roiPresetsTitle => 'ROI 프리셋';

  @override
  String get roiNoPresets => '구성된 ROI 프리셋이 없습니다';

  @override
  String get roiCreatePreset => '프리셋 생성';

  @override
  String get roiActive => '활성';

  @override
  String get roiActivate => '활성화';

  @override
  String get roiFinishDrawing => '그리기 완료';

  @override
  String get roiPresetSaved => 'ROI 프리셋이 저장되었습니다';

  @override
  String get roiSegmentRoi => 'ROI';

  @override
  String get roiSegmentLine => '라인';

  @override
  String get roiSegmentLane => '차선';

  @override
  String get roiSummaryNone => '없음';

  @override
  String get roiSummarySet => '설정됨';

  @override
  String get roiSummaryLines => '라인';

  @override
  String get roiSummaryLanes => '차선';

  @override
  String get roiFailedToLoad => '프리셋을 불러오지 못했습니다';

  @override
  String roiLinesCount(int count, int laneCount) {
    return '라인 $count개 · 차선 $laneCount개';
  }

  @override
  String get monitorTitle => '실시간 모니터';

  @override
  String get monitorVehicleCount => '차량 수';

  @override
  String get monitorSpeed => '평균 속도';

  @override
  String get monitorOccupancy => '점유율';

  @override
  String get monitorNoFeed => '실시간 피드를 사용할 수 없습니다';

  @override
  String get monitorFlowRate => '시간당 유량';

  @override
  String get monitorActiveTracks => '활성 추적';

  @override
  String get monitorCurrentBucket => '현재 버킷';

  @override
  String get monitorByDirection => '방향별';

  @override
  String get monitorByClass => '차종별';

  @override
  String get monitorInbound => '진입';

  @override
  String get monitorOutbound => '진출';

  @override
  String get monitorInitializing => '카메라 및 ML 모델 초기화 중...';

  @override
  String get monitorSimulated => '시뮬레이션 교통';

  @override
  String get monitorLive => '실시간 추론';

  @override
  String monitorTracksAndCrossings(int trackCount, int crossingCount) {
    return '추적 $trackCount개 · 통과 $crossingCount건';
  }

  @override
  String get monitorWaitingForData => '데이터 대기 중...';

  @override
  String monitorRefiningCrossings(int count) {
    return '$count건 정밀 분류 중...';
  }

  @override
  String get monitorCloudVlm => '클라우드 VLM';

  @override
  String monitorRefining(int count) {
    return '정밀 분류 중 $count건';
  }

  @override
  String get monitorIdle => '대기 중';

  @override
  String get monitorSentToVlm => 'VLM 전송';

  @override
  String get monitorRefined => '정밀 분류 완료';

  @override
  String get monitorFallbacks => '폴백';

  @override
  String get monitorAvgLatency => '평균 지연';

  @override
  String get monitorNoApiKey => 'API 키가 구성되지 않았습니다';

  @override
  String get monitorPipelineFull12 => '실시간 12종 (2단계) 추론';

  @override
  String get monitorPipelineCoarse => '실시간 대분류 차량 분류';

  @override
  String get monitorPipelineHybrid => '실시간 하이브리드 클라우드 분류';

  @override
  String get monitorPipelineDetectionOnly => '실시간 탐지만';

  @override
  String get monitorCameraPermissionDenied =>
      '카메라 권한이 거부되었습니다. 시뮬레이션 모드로 실행합니다.';

  @override
  String monitorCameraError(String error) {
    return '카메라 오류: $error. 시뮬레이션 모드로 실행합니다.';
  }

  @override
  String get monitorCameraUnavailable => '카메라를 사용할 수 없습니다. 시뮬레이션 모드로 실행합니다.';

  @override
  String monitorClassificationUnavailable12(String error) {
    return '12종 분류를 사용할 수 없습니다: $error';
  }

  @override
  String monitorClassificationUnavailableCoarse(String error) {
    return '대분류를 사용할 수 없습니다: $error';
  }

  @override
  String monitorClassificationUnavailableHybrid(String error) {
    return '하이브리드 클라우드 분류를 사용할 수 없습니다: $error';
  }

  @override
  String monitorClassificationUnavailableDisabled(String error) {
    return '실시간 추론을 사용할 수 없습니다: $error';
  }

  @override
  String get analyticsTitle => '분석';

  @override
  String get analyticsTimeRange => '기간';

  @override
  String get analyticsToday => '오늘';

  @override
  String get analyticsWeek => '이번 주';

  @override
  String get analyticsMonth => '이번 달';

  @override
  String get analyticsCustom => '사용자 지정';

  @override
  String get analyticsVolumeChart => '교통량';

  @override
  String get analyticsSpeedChart => '속도 분포';

  @override
  String get analyticsClassChart => '차종 분류';

  @override
  String get analyticsExport => '보고서 내보내기';

  @override
  String get analyticsBuckets => '버킷';

  @override
  String get analyticsClasses => '차종';

  @override
  String get analyticsDemoDataLoaded => '데모 데이터가 로드되었습니다.';

  @override
  String get analyticsDataAlreadyPresent => '데이터가 이미 존재합니다.';

  @override
  String get analyticsLoadDemoData => '데모 데이터 로드';

  @override
  String analyticsVehiclesTooltip(String time, int count) {
    return '$time\n$count대';
  }

  @override
  String get alertsTitle => '알림';

  @override
  String get alertsEmpty => '알림 없음';

  @override
  String get alertsMarkRead => '읽음으로 표시';

  @override
  String get alertsMarkAllRead => '모두 읽음으로 표시';

  @override
  String get alertsClear => '삭제';

  @override
  String get alertDetailTitle => '알림 상세';

  @override
  String get alertTimestamp => '시간';

  @override
  String get alertSeverityHigh => '높음';

  @override
  String get alertSeverityMedium => '보통';

  @override
  String get alertSeverityLow => '낮음';

  @override
  String get alertTypeIncident => '사고';

  @override
  String get alertTypeAnomaly => '이상';

  @override
  String get alertTypeThreshold => '임계값';

  @override
  String get alertStatusTriggered => '발생';

  @override
  String get alertStatusAcknowledged => '확인됨';

  @override
  String get alertStatusAssigned => '할당됨';

  @override
  String get alertStatusResolved => '해결됨';

  @override
  String get alertStatusSuppressed => '억제됨';

  @override
  String get alertSeverity => '심각도';

  @override
  String get alertStatus => '상태';

  @override
  String get alertCondition => '조건';

  @override
  String get alertSite => '사이트';

  @override
  String get alertCamera => '카메라';

  @override
  String get alertMessage => '메시지';

  @override
  String get alertAssignedTo => '담당자';

  @override
  String get alertResolve => '해결';

  @override
  String get alertRulesTitle => '알림 규칙';

  @override
  String get alertRuleAdd => '규칙 추가';

  @override
  String get alertRuleEdit => '규칙 편집';

  @override
  String get alertRuleName => '규칙 이름';

  @override
  String get alertRuleCondition => '조건';

  @override
  String get alertRuleThreshold => '임계값';

  @override
  String get alertRuleEnabled => '활성화';

  @override
  String get alertRuleAddTitle => '알림 규칙 추가';

  @override
  String get alertRuleNameLabel => '규칙 이름';

  @override
  String get alertConditionLabel => '조건';

  @override
  String get alertThresholdLabel => '임계값';

  @override
  String get alertSeverityLabel => '심각도';

  @override
  String get alertCondCongestion => '혼잡';

  @override
  String get alertCondSpeedDrop => '속도 저하';

  @override
  String get alertCondStopped => '정지 차량';

  @override
  String get alertCondHeavy => '대형차 비율';

  @override
  String get alertCondCameraOffline => '카메라 오프라인';

  @override
  String get alertCondCountAnomaly => '계수 이상';

  @override
  String get alertNoRules => '구성된 알림 규칙이 없습니다';

  @override
  String get alertRuleCreate => '생성';

  @override
  String alertRuleSubtitle(String conditionType, String threshold) {
    return '$conditionType · 임계값: $threshold';
  }

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsProfile => '프로필';

  @override
  String get settingsNotifications => '알림';

  @override
  String get settingsAppearance => '외관';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsThemeLight => '라이트';

  @override
  String get settingsThemeDark => '다크';

  @override
  String get settingsThemeSystem => '시스템';

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsVersion => '버전';

  @override
  String get settingsLogout => '로그아웃';

  @override
  String get settingsLogoutConfirm => '정말 로그아웃하시겠습니까?';

  @override
  String get settingsQuickSetup => '빠른 설정';

  @override
  String get settingsQuickSetupDesc => '설정 마법사를 다시 실행합니다';

  @override
  String get settingsData => '데이터';

  @override
  String get settingsClearData => '모든 로컬 데이터 삭제';

  @override
  String get settingsClearDataDesc => '모든 사이트, 카메라, 통과 데이터를 삭제합니다';

  @override
  String get settingsClearDataConfirmTitle => '모든 데이터를 삭제하시겠습니까?';

  @override
  String get settingsClearDataConfirmBody =>
      '모든 로컬 사이트, 카메라, ROI 프리셋 및 통과 데이터가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get settingsCleared => '모든 데이터가 삭제되었습니다';

  @override
  String get settingsClearButton => '삭제';

  @override
  String get settingsCloudClassification => '클라우드 분류';

  @override
  String get settingsVlmProvider => 'VLM 제공자';

  @override
  String get settingsNotConfigured => '구성되지 않음';

  @override
  String get settingsProviderGemini => 'Google Gemini';

  @override
  String get settingsProviderOpenai => 'OpenAI';

  @override
  String get settingsProvider => '제공자';

  @override
  String get settingsAuth => '인증';

  @override
  String get settingsApiKey => 'API 키';

  @override
  String get settingsApiKeySecure => '기기에 안전하게 저장됩니다. 당사 서버로 전송되지 않습니다.';

  @override
  String get settingsModelName => '모델 이름';

  @override
  String get settingsConfidenceThreshold => '신뢰도 임계값';

  @override
  String get settingsConfidenceDescription =>
      '로컬 분류기 신뢰도가 이 값을 초과하면 VLM을 건너뜁니다. 낮을수록 VLM 호출이 많아집니다.';

  @override
  String get settingsBatching => '배치 처리';

  @override
  String get settingsBatchingDescription => 'API 호출을 줄이기 위해 크롭을 모아서 전송합니다.';

  @override
  String get settingsBatchSize => '배치 크기';

  @override
  String get settingsBatchTimeout => '배치 타임아웃';

  @override
  String get settingsRequestTimeout => '요청 타임아웃';

  @override
  String get settingsMaxRetries => '최대 재시도';

  @override
  String get settingsAdvanced => '고급';

  @override
  String get settingsResetDefaults => '기본값으로 재설정';

  @override
  String get settingsResetConfirmTitle => 'VLM 설정을 재설정하시겠습니까?';

  @override
  String get settingsResetConfirmBody =>
      'API 키가 삭제되고 모든 클라우드 분류 설정이 기본값으로 재설정됩니다.';

  @override
  String get settingsResetButton => '재설정';

  @override
  String get settingsGemini => 'Gemini';

  @override
  String get settingsOpenai => 'OpenAI';

  @override
  String get classifyTitle => '차량 분류';

  @override
  String get classifyVehicle => '차량 분류하기';

  @override
  String get classifyDescription =>
      '사진을 촬영하거나 갤러리에서 선택하여 2단계 AI 분류로 차종을 식별합니다.';

  @override
  String get classifyCamera => '카메라';

  @override
  String get classifyGallery => '갤러리';

  @override
  String get classifyNewPhoto => '새 사진';

  @override
  String get classifyLoadingModels => 'ML 모델 로딩 중...';

  @override
  String get classifyClassifying => '차량 분류 중...';

  @override
  String get classifyNoVehicles => '이 이미지에서 차량이 감지되지 않았습니다.';

  @override
  String get classifyFailed => '분류 실패';

  @override
  String get classifyUnknownError => '알 수 없는 오류';

  @override
  String get classifyTryAgain => '다시 시도';

  @override
  String get classifySaved => '분류가 저장되었습니다';

  @override
  String get classifySaveTooltip => '분류 저장';

  @override
  String get classifyStage1 => '1단계 (대분류)';

  @override
  String get classifyWheels => '감지된 바퀴';

  @override
  String get classifyJoints => '감지된 연결부';

  @override
  String get classifyAxles => '추정 축수';

  @override
  String get classifyTrailer => '트레일러';

  @override
  String get classifyFinalClass => '최종 분류';

  @override
  String get classifyConfidence => '신뢰도';

  @override
  String get classifyYes => '있음';

  @override
  String get classifyNo => '없음';

  @override
  String get classifyUnknown => '알 수 없음';

  @override
  String get videoAnalysisTitle => '영상 분석';

  @override
  String get videoAnalysisCloud => '클라우드 영상 분석';

  @override
  String get videoAnalysisDescription =>
      '영상을 촬영하거나 선택 (최대 5분) 하여 클라우드 기반 차량 탐지 및 계수를 실행합니다.';

  @override
  String get videoAnalysisGallery => '갤러리에서 선택';

  @override
  String get videoAnalysisRecord => '영상 촬영';

  @override
  String get videoAnalysisPickFileTitle => '영상 파일 선택 (MP4 또는 DAV)';

  @override
  String get videoAnalysisStartAnalysis => '분석 시작';

  @override
  String get videoAnalysisChooseDifferentFile => '다른 파일 선택';

  @override
  String videoAnalysisStagedFile(String filename) {
    return '선택됨: $filename';
  }

  @override
  String get videoAnalysisStagedHint => '아래에서 분석 항목을 확인한 뒤 시작을 눌러 업로드하세요.';

  @override
  String get videoAnalysisBusStopPreset => '버스정류장 프리셋';

  @override
  String get videoAnalysisBusStopPresetHint =>
      '한 번 탭으로 차량 계수를 끄고 대중교통(승하차)과 보행자 항목을 활성화합니다.';

  @override
  String get videoAnalysisBusStopApplied => '버스정류장 프리셋 적용됨 — 차량 계수가 꺼졌습니다.';

  @override
  String get videoAnalysisCountLineConfigure => '카운트 라인 설정';

  @override
  String get videoAnalysisCountLineConfigured => 'IN/OUT 라인 설정 완료';

  @override
  String get videoAnalysisDavNotSupported =>
      'DAV 파일은 분석을 위해 업로드할 수 없습니다. 속도/대중교통/신호등 시간 설정 화면에서 보정 배경으로만 사용하거나, 먼저 MP4로 변환하세요.';

  @override
  String get videoAnalysisUploading => '업로드 및 분석 중…';

  @override
  String get videoAnalysisUploadingHint => '영상 길이에 따라 수 분이 소요될 수 있습니다.';

  @override
  String get videoAnalysisProcessing => '서버에서 영상 분석 중…';

  @override
  String get videoAnalysisProcessingHint =>
      '영상이 업로드되었습니다. 서버에서 처리 중이며, 영상 길이에 따라 수 분이 소요될 수 있습니다.';

  @override
  String get videoAnalysisTotalCounted => '총 감지 차량 수';

  @override
  String get videoAnalysisBreakdown => '차종별 분류';

  @override
  String get videoAnalysisExportCsv => 'CSV 내보내기';

  @override
  String get videoAnalysisRetry => '재시도';

  @override
  String get videoAnalysisIncludeAnnotatedVideo => '주석 영상 생성';

  @override
  String get videoAnalysisIncludeAnnotatedVideoHint =>
      '분석 후 다운로드할 수 있는 라벨이 표시된 MP4를 생성합니다. 처리 시간이 늘어납니다.';

  @override
  String get videoAnalysisDownloadVideo => '주석 영상 다운로드';

  @override
  String get videoAnalysisDownloadTransitVideo => '대중교통 오버레이 영상 다운로드';

  @override
  String get videoAnalysisDownloadingVideo => '주석 영상 다운로드 중…';

  @override
  String get videoAnalysisDownloadCanceled => '다운로드가 취소되었습니다.';

  @override
  String videoAnalysisDownloadSaved(String path) {
    return '저장 완료: $path';
  }

  @override
  String get videoAnalysisTasksTitle => '분석 항목';

  @override
  String get videoAnalysisTasksHint =>
      '각 항목은 정확한 결과를 위해 현장 보정이 필요합니다. 기본값은 화면 하단 중앙의 도로를 가정합니다.';

  @override
  String get videoAnalysisTaskVehicles => '차량 (계수 + 분류)';

  @override
  String get videoAnalysisTaskPedestrians => '보행자';

  @override
  String get videoAnalysisTaskSpeed => '속도 (두 라인 측정)';

  @override
  String get videoAnalysisTaskTransit => '대중교통 (승하차 / 밀집도)';

  @override
  String get videoAnalysisTaskTrafficLight => '신호등 시간';

  @override
  String get videoAnalysisTaskLpr => '차량번호판 (상주/방문)';

  @override
  String get videoAnalysisPedestrianTitle => '보행자';

  @override
  String videoAnalysisPedestrianCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보행자 $count명 감지',
      zero: '보행자 감지 없음',
    );
    return '$_temp0';
  }

  @override
  String get videoAnalysisPedestrianDetectorOff =>
      '보행자 감지기가 꺼져 있습니다 — 서버에서 ENABLE_PEDESTRIAN_DETECTOR=1 설정 필요.';

  @override
  String get videoAnalysisSpeedTitle => '속도';

  @override
  String get videoAnalysisSpeedNoMeasurements => '두 속도 라인을 모두 통과한 차량이 없습니다.';

  @override
  String get videoAnalysisSpeedAvg => '평균';

  @override
  String get videoAnalysisSpeedMin => '최저';

  @override
  String get videoAnalysisSpeedMax => '최고';

  @override
  String videoAnalysisSpeedKmh(String value) {
    return '$value km/h';
  }

  @override
  String videoAnalysisSpeedMeasured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '차량 $count대 측정',
    );
    return '$_temp0';
  }

  @override
  String get videoAnalysisSpeedPerTrack => '차량별 속도';

  @override
  String videoAnalysisSpeedTrackRow(String trackId) {
    return '트랙 $trackId';
  }

  @override
  String get videoAnalysisTransitTitle => '대중교통';

  @override
  String get videoAnalysisTransitBoarding => '승차';

  @override
  String get videoAnalysisTransitAlighting => '하차';

  @override
  String get videoAnalysisTransitPeak => '정류장 최대 인원';

  @override
  String get videoAnalysisTransitDensity => '평균 밀집도';

  @override
  String videoAnalysisTransitDensityValue(String value) {
    return '$value%';
  }

  @override
  String get videoAnalysisTransitBusGated => '버스 도착 시에만 승하차를 카운트합니다.';

  @override
  String get videoAnalysisTransitNotGated => '모든 도어 라인 통과를 카운트합니다 (버스 게이트 없음).';

  @override
  String get videoAnalysisTrafficLightTitle => '신호등 시간';

  @override
  String videoAnalysisTrafficLightLabel(String label) {
    return '신호: $label';
  }

  @override
  String get videoAnalysisTrafficLightCycles => '주기';

  @override
  String get videoAnalysisTrafficLightAvgDuration => '평균';

  @override
  String get videoAnalysisTrafficLightTotalDuration => '합계';

  @override
  String videoAnalysisTrafficLightSeconds(String value) {
    return '$value초';
  }

  @override
  String get videoAnalysisTrafficLightRed => '빨강';

  @override
  String get videoAnalysisTrafficLightGreen => '초록';

  @override
  String get videoAnalysisTrafficLightYellow => '노랑';

  @override
  String get videoAnalysisLprTitle => '차량번호판';

  @override
  String get videoAnalysisLprResident => '상주';

  @override
  String get videoAnalysisLprVisitor => '방문';

  @override
  String videoAnalysisLprAllowlistSize(int count) {
    return '허용 목록: $count개';
  }

  @override
  String get videoAnalysisLprPrivacyHashed =>
      '번호판 텍스트가 SHA-256 해시로 저장됩니다 (개인정보 보호 모드).';

  @override
  String get videoAnalysisLprPlatePrefix => '번호';

  @override
  String get videoAnalysisLprHashPrefix => '해시';

  @override
  String get videoAnalysisConfigure => '설정';

  @override
  String get videoAnalysisConfigureNoVideo => '각 항목을 설정하려면 먼저 영상을 선택하세요.';

  @override
  String videoAnalysisRoiConfigured(
      String label, String width, String height, String position) {
    return 'ROI 설정 완료: $label ($width×$height, $position)';
  }

  @override
  String get roiEditorTitle => '신호등 ROI';

  @override
  String get roiEditorLabel => '신호 라벨 (예: main, left_turn)';

  @override
  String get roiEditorReset => '초기화';

  @override
  String get roiEditorSave => '저장';

  @override
  String get roiEditorCancel => '취소';

  @override
  String get roiEditorPickStill => '정지 이미지 선택';

  @override
  String get roiEditorPickBackdrop => '배경 파일 선택';

  @override
  String get roiEditorPickBackdropTitle => 'MP4, DAV 또는 정지 이미지 선택';

  @override
  String get roiEditorNoBackdrop =>
      '배경이 아직 로드되지 않았습니다. 동일 장면의 MP4, DAV 또는 정지 이미지를 선택하여 시작하세요.';

  @override
  String get roiEditorFrameLoadFailed =>
      '영상에서 프레임을 추출할 수 없습니다. 동일 장면의 정지 이미지를 선택하세요.';

  @override
  String get roiEditorRoiTooSmall => 'ROI가 너무 작습니다. 두 모서리를 더 멀리 잡아주세요.';

  @override
  String get roiEditorHintTopLeft => '신호등의 좌측 상단을 탭하세요.';

  @override
  String get roiEditorHintBottomRight => '신호등의 우측 하단을 탭하세요.';

  @override
  String get roiEditorHintRefine => '모서리를 다시 탭하여 조정하거나, 저장을 누르세요.';

  @override
  String get lprAllowlistTitle => '상주 차량번호판';

  @override
  String get lprAllowlistEmpty => '아직 상주 차량이 없습니다. 아래에서 추가하세요.';

  @override
  String get lprAllowlistHint =>
      '한국식 형식: NN가 NNNN (예: 12가 3456). 공백은 자동으로 제거됩니다.';

  @override
  String get lprAllowlistAddHint => '번호판 (예: 12가 3456)';

  @override
  String get lprAllowlistAdd => '추가';

  @override
  String get lprAllowlistInvalid => '한국식 형식이 아닙니다 (NN(N)가 NNNN).';

  @override
  String get lprAllowlistDuplicate => '이미 허용 목록에 있는 번호판입니다.';

  @override
  String get lprAllowlistRemove => '삭제';

  @override
  String lprAllowlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '번호판 $count개',
    );
    return '$_temp0';
  }

  @override
  String get lprAllowlistConfigure => '허용 목록 관리';

  @override
  String get speedEditorTitle => '속도 라인 & 사각형';

  @override
  String get speedEditorResetQuad => '사각형 초기화';

  @override
  String speedEditorModeQuad(int count) {
    return '사각형 ($count/4)';
  }

  @override
  String get speedEditorModeLine1 => '라인 1';

  @override
  String get speedEditorModeLine2 => '라인 2';

  @override
  String get speedEditorWidthM => '너비 (m)';

  @override
  String get speedEditorLengthM => '길이 (m)';

  @override
  String speedEditorHintQuad(int remaining) {
    return '실측 가능한 사각형(예: 차선 표시)의 모서리를 $remaining개 더 탭하세요.';
  }

  @override
  String get speedEditorHintQuadDone =>
      '사각형 완성. 다시 탭하여 새로 시작하거나 라인 1/2로 전환하세요.';

  @override
  String get speedEditorHintLine1Start => '라인 1(진입)의 시작 점을 탭하세요.';

  @override
  String get speedEditorHintLine1End => '라인 1(진입)의 끝 점을 탭하세요.';

  @override
  String get speedEditorHintLine1Done => '라인 1 설정 완료. 다시 탭하여 새로 그리기.';

  @override
  String get speedEditorHintLine2Start => '라인 2(진출)의 시작 점을 탭하세요.';

  @override
  String get speedEditorHintLine2End => '라인 2(진출)의 끝 점을 탭하세요.';

  @override
  String get speedEditorHintLine2Done => '라인 2 설정 완료. 다시 탭하여 새로 그리기.';

  @override
  String get speedEditorSnapHorizontal => '라인을 수평으로 고정';

  @override
  String get speedEditorSnapHorizontalHint =>
      '두 라인을 완전히 수평으로 강제합니다 — 이전 동작; 임의 라인은 해제하세요.';

  @override
  String get speedEditorQuadIncomplete => '저장 전에 사각형 모서리 4개를 모두 탭하세요.';

  @override
  String get speedEditorLinesIncomplete => '저장 전에 두 라인 각각의 끝 점 2개를 모두 설정하세요.';

  @override
  String get speedEditorLinesTooClose => '두 라인은 프레임 높이의 5% 이상 떨어져야 합니다.';

  @override
  String get speedEditorBadMetres => '너비와 길이는 0보다 큰 미터 값이어야 합니다.';

  @override
  String get countLineEditorTitle => '카운트 라인 (IN / OUT)';

  @override
  String get countLineEditorModeIn => 'IN 라인';

  @override
  String get countLineEditorModeOut => 'OUT 라인';

  @override
  String get countLineEditorReset => '라인 초기화';

  @override
  String get countLineEditorHintInStart => 'IN 라인의 시작 점을 탭하세요.';

  @override
  String get countLineEditorHintInEnd => 'IN 라인의 끝 점을 탭하세요.';

  @override
  String get countLineEditorHintInDone => 'IN 라인 설정 완료. 다시 탭하여 새로 그리기.';

  @override
  String get countLineEditorHintOutStart => 'OUT 라인의 시작 점을 탭하세요.';

  @override
  String get countLineEditorHintOutEnd => 'OUT 라인의 끝 점을 탭하세요.';

  @override
  String get countLineEditorHintOutDone => 'OUT 라인 설정 완료. 다시 탭하여 새로 그리기.';

  @override
  String get countLineEditorIncomplete => '저장 전에 두 라인 각각의 끝 점 2개를 모두 설정하세요.';

  @override
  String get countLineEditorDescription =>
      '한 차량 트랙이 두 라인 모두를 통과(순서 무관)할 때 1대로 계수됩니다. IN은 차량이 진입하는 위치, OUT은 빠져나가는 위치에 배치하세요.';

  @override
  String get transitEditorTitle => '정류장 & 도어 라인';

  @override
  String get transitEditorUndo => '마지막 점 취소';

  @override
  String get transitEditorModeStopPolygon => '정류장 영역';

  @override
  String get transitEditorModeDoorLine => '도어 라인';

  @override
  String get transitEditorModeBusZone => '버스 영역';

  @override
  String get transitEditorBusZoneEnable => '버스 도착 시에만 카운트';

  @override
  String get transitEditorBusZoneHint =>
      '활성화하면, 버스가 이 영역과 겹치는 동안에만 도어 라인 통과를 카운트합니다.';

  @override
  String get transitEditorBusZoneDisabled =>
      '버스 영역 게이트 비활성화 — 모든 도어 라인 통과를 카운트합니다.';

  @override
  String get transitEditorCapacity => '최대 수용 인원';

  @override
  String get transitEditorCapacityHint => '밀집도 % = 정류장 영역 내 인원 ÷ 최대 수용 인원.';

  @override
  String transitEditorHintStopPolygon(int remaining) {
    return '탭하여 정류장 꼭짓점을 추가하세요. $remaining개 더 필요합니다.';
  }

  @override
  String get transitEditorHintStopPolygonDone =>
      '정류장 영역 준비 완료. 꼭짓점을 추가하거나 탭을 전환하세요.';

  @override
  String transitEditorHintDoorLine(int remaining) {
    return '도어 라인 엔드포인트 $remaining/2을 탭하세요.';
  }

  @override
  String get transitEditorHintDoorLineDone => '도어 라인 준비 완료. 다시 탭하여 재설정.';

  @override
  String transitEditorHintBusZone(int remaining) {
    return '탭하여 버스 영역 꼭짓점을 추가하세요. $remaining개 더 필요합니다.';
  }

  @override
  String get transitEditorHintBusZoneDone => '버스 영역 준비 완료.';

  @override
  String get transitEditorStopPolygonTooSmall => '정류장 영역에는 최소 3개의 꼭짓점이 필요합니다.';

  @override
  String get transitEditorDoorLineIncomplete => '도어 라인에는 정확히 2개의 엔드포인트가 필요합니다.';

  @override
  String get transitEditorBusZoneTooSmall =>
      '버스 영역에는 최소 3개의 꼭짓점이 필요합니다 (또는 비활성화하세요).';

  @override
  String get transitEditorBadCapacity => '수용 인원은 양의 정수여야 합니다.';

  @override
  String get calibrationModeAuto => '자동';

  @override
  String get calibrationModeManual => '수동';

  @override
  String get transitAutoModeTitle => 'AI 자동 감지 모드';

  @override
  String get transitAutoModeBody =>
      'AI가 영상의 첫 프레임을 분석해 정류장 영역, 도어 라인, 버스 정차 위치를 자동으로 찾습니다. 정원만 입력하시면 됩니다.';

  @override
  String get transitManualModeBody => '직접 영역을 그리고 싶다면 수동으로 전환하세요.';

  @override
  String get transitWhatIsThisTitle => '이 설정은 무엇인가요?';

  @override
  String get transitWhatIsThisBody =>
      '정류장 영역(녹색)은 사람이 서 있는 곳이며 밀집도(%)를 계산합니다. 도어 라인(노랑)은 버스 출입문 위치이며, 통과하는 사람을 승하차로 셉니다. 버스 영역(파랑)은 버스가 정차하는 자리로, 이 안에 버스가 있을 때만 승하차가 카운트됩니다.';

  @override
  String get lightAutoModeTitle => 'AI 자동 감지 모드';

  @override
  String get lightAutoModeBody =>
      'AI가 영상에서 신호등 위치를 자동으로 찾습니다. 라벨만 입력하시면 됩니다 (여러 신호등이 있을 때 구분용).';

  @override
  String get lightManualModeBody => '직접 ROI를 그리고 싶다면 수동으로 전환하세요.';

  @override
  String get lightAutoLabelField => '신호 라벨 (예: 직진, 좌회전)';

  @override
  String get lightWhatIsThisTitle => '이 설정은 무엇인가요?';

  @override
  String get lightWhatIsThisBody =>
      '신호등 ROI는 색상 판정을 위해 신호등 자체만 감싸는 작은 박스입니다. 박스가 크면 배경 픽셀이 색상 판정을 어둡게 만들어 정확도가 떨어집니다.';

  @override
  String get speedWhatIsThisTitle => '이 설정은 무엇인가요?';

  @override
  String get speedWhatIsThisBody =>
      '사다리꼴은 카메라 화면을 위에서 본 것처럼 펴 줍니다(원근 보정). 가로/세로 미터 값으로 픽셀을 미터로 환산하고, 두 라인을 통과한 시간으로 km/h를 계산합니다. 실제 도로의 차선 폭(보통 3.5m)과 알려진 거리를 사용하세요.';

  @override
  String get speedDefaultPresetButton => '기본값 적용 (1차로 3.5m × 10m)';

  @override
  String get speedDefaultPresetApplied => '기본값을 적용했습니다. 영상에 맞게 조정하세요.';

  @override
  String get countLineWhatIsThisTitle => '이 설정은 무엇인가요?';

  @override
  String get countLineWhatIsThisBody =>
      '두 가상의 선을 그으면 차량이 두 선을 모두 통과할 때 1대로 카운트됩니다(순서 무관). 단일 선보다 정확하며 진입(IN)/진출(OUT) 방향까지 분리됩니다.';

  @override
  String get lprWhatIsThisTitle => '이 설정은 무엇인가요?';

  @override
  String get lprWhatIsThisBody =>
      '허용 목록(상주 차량)에 등록된 번호판은 ‘상주’로, 그 외는 ‘방문’으로 분류됩니다. 번호판 자체는 AI가 자동으로 인식하므로 ROI 설정이 필요 없습니다.';

  @override
  String get calibrationResetTooltip => '사이트 보정 초기화';

  @override
  String get calibrationResetTitle => '보정을 초기화할까요?';

  @override
  String get calibrationResetMessage =>
      '이 사이트에 저장된 모든 항목(활성화된 작업, ROI, 속도 라인, 정류장 영역, 번호판 허용 목록)이 삭제됩니다. 되돌릴 수 없습니다.';

  @override
  String get calibrationResetConfirm => '초기화';

  @override
  String get calibrationResetDone => '사이트 보정이 초기화되었습니다.';

  @override
  String get reportTitle => 'GreyEye 교통 보고서';

  @override
  String reportCamera(String cameraId) {
    return '카메라: $cameraId';
  }

  @override
  String reportPeriod(String period) {
    return '기간: $period';
  }

  @override
  String get reportNA => '해당 없음';

  @override
  String reportTotalCrossings(int count) {
    return '총 통과 건수: $count';
  }

  @override
  String get reportByClass => '차종별';

  @override
  String get reportByDirection => '방향별';

  @override
  String get reportRawCrossings => '원시 통과 데이터 (처음 200건)';

  @override
  String get reportHeaderClass => '차종';

  @override
  String get reportHeaderCount => '건수';

  @override
  String get reportHeaderDirection => '방향';

  @override
  String get reportHeaderTime => '시간';

  @override
  String get reportHeaderDir => '방향';

  @override
  String get reportHeaderConf => '신뢰도';

  @override
  String exportExported(int count) {
    return '$count건의 통과 데이터를 내보냈습니다';
  }

  @override
  String get exportFormat => '내보내기 형식';

  @override
  String get exportSelectRange => '날짜 범위를 선택하세요';

  @override
  String get exportStarted => '내보내기 시작됨';

  @override
  String get exportSelectDateRange => '날짜 범위 선택';

  @override
  String get commonSave => '저장';

  @override
  String get commonCancel => '취소';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonEdit => '편집';

  @override
  String get commonRetry => '재시도';

  @override
  String get commonLoading => '로딩 중…';

  @override
  String get commonError => '문제가 발생했습니다';

  @override
  String get commonNoData => '데이터가 없습니다';

  @override
  String get commonConfirm => '확인';

  @override
  String get commonSearch => '검색';

  @override
  String get commonRefresh => '새로고침';

  @override
  String get errorNetwork => '네트워크 오류입니다. 연결 상태를 확인하세요.';

  @override
  String get errorTimeout => '요청 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get errorServer => '서버 오류입니다. 나중에 다시 시도해 주세요.';

  @override
  String get errorUnauthorized => '세션이 만료되었습니다. 다시 로그인해 주세요.';

  @override
  String get errorForbidden => '이 작업에 대한 권한이 없습니다.';

  @override
  String get errorNotFound => '리소스를 찾을 수 없습니다.';
}
