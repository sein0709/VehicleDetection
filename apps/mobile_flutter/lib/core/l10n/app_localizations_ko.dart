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
  String get setupTitle => '초기 설정';

  @override
  String get setupWelcome => 'GreyEye에 오신 것을 환영합니다';

  @override
  String get setupAddSite => '첫 번째 모니터링 사이트를 추가하세요';

  @override
  String get setupComplete => '설정 완료';

  @override
  String get navHome => '홈';

  @override
  String get navAlerts => '알림';

  @override
  String get navSettings => '설정';

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
  String get setupDefaultLineNote =>
      '기본 카운팅 라인이 생성됩니다. 나중에 ROI 편집기에서 수정할 수 있습니다.';

  @override
  String get setupGoToDashboard => '대시보드로 이동';

  @override
  String get setupOpenMonitor => '실시간 모니터 열기';

  @override
  String get setupOpenRoiEditor => 'ROI 편집기 열기';

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
  String get exportFormat => '내보내기 형식';

  @override
  String get exportSelectRange => '날짜 범위를 선택하세요';

  @override
  String get exportStarted => '내보내기 시작됨';

  @override
  String get exportSelectDateRange => '날짜 범위 선택';
}
