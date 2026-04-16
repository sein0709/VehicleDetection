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
