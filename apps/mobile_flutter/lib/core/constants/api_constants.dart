abstract final class ApiConstants {
  static const String defaultSupabaseUrl = 'http://127.0.0.1:54321';

  static const String supabaseUrl = String.fromEnvironment(
    'GREYEYE_SUPABASE_URL',
    defaultValue: defaultSupabaseUrl,
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'GREYEYE_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const bool authEnabled = supabaseAnonKey != '';

  static const String alerts = '/alerts';
  static const String alertRules = '/alert-rules';
  static String alertAcknowledge(String id) => '/alerts/$id/acknowledge';
  static String alertResolve(String id) => '/alerts/$id/resolve';
  static String alertRule(String id) => '/alert-rules/$id';

  static const String analyzeVideoUrl = String.fromEnvironment(
    'GREYEYE_ANALYZE_VIDEO_URL',
    defaultValue: 'https://kcic1v8d6c7h86-8000.proxy.runpod.net/analyze_video',
  );

  /// Polling endpoint for async job status.
  /// Derives the base URL from [analyzeVideoUrl] automatically.
  static String jobStatusUrl(String jobId) => '${_analyzeBase()}/status/$jobId';

  /// Annotated MP4 download endpoint. [kind] is `classified` (default) for the
  /// per-class bbox overlay or `transit` for the head-circle / boarding overlay.
  /// Only available when the job was submitted with `output_video: true` (or
  /// `transit.output_video: true` for the transit variant).
  static String videoUrl(String jobId, {String kind = 'classified'}) =>
      '${_analyzeBase()}/video/$jobId?kind=$kind';

  /// Pre-flight traffic-light ROI preview. Mobile uploads a single keyframe
  /// (extracted on-device) and the server returns the VLM's proposed bbox
  /// per detected light head so the operator can confirm before running
  /// the full analysis.
  static String get trafficLightPreviewUrl =>
      '${_analyzeBase()}/preview_traffic_light_roi';

  static String _analyzeBase() {
    final idx = analyzeVideoUrl.lastIndexOf('/analyze_video');
    return idx >= 0 ? analyzeVideoUrl.substring(0, idx) : analyzeVideoUrl;
  }

  static String geminiGenerateContent(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  static const String openaiChatCompletions =
      'https://api.openai.com/v1/chat/completions';
}
