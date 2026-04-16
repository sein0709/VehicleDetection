/// HTTP client for cloud VLM vehicle classification via Gemini or OpenAI.
///
/// Encodes a JPEG vehicle crop as base64, sends it to the configured VLM
/// provider with a structured prompt, and parses the response into a
/// [VlmClassificationResult].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:greyeye_mobile/core/constants/api_constants.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

/// Result of a single VLM classification request.
class VlmClassificationResult {
  const VlmClassificationResult({
    required this.classCode,
    required this.confidence,
    required this.source,
    this.rawResponse,
  });

  /// KICT 12-class code (1–12).
  final int classCode;

  /// Model-reported confidence (0.0–1.0).
  final double confidence;

  /// `'vlm'` on success, `'fallback'` when the VLM call failed.
  final String source;

  /// Raw text response from the model, retained for debugging.
  final String? rawResponse;
}

/// Thrown when the VLM provider returns an unparseable or invalid response.
class VlmParseException implements Exception {
  VlmParseException(this.message, {this.rawResponse});
  final String message;
  final String? rawResponse;

  @override
  String toString() => 'VlmParseException: $message';
}

class VlmClient {
  VlmClient({required VlmSettings settings, Dio? dio})
      : _settings = settings,
        _dio = dio ?? _createDio(settings);

  final VlmSettings _settings;
  final Dio _dio;

  static Dio _createDio(VlmSettings settings) {
    return Dio(
      BaseOptions(
        connectTimeout: Duration(milliseconds: settings.requestTimeoutMs),
        receiveTimeout: Duration(milliseconds: settings.requestTimeoutMs),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  /// Classify a single JPEG-encoded vehicle crop.
  ///
  /// Retries up to [VlmSettings.maxRetries] times on transient errors.
  Future<VlmClassificationResult> classifyVehicleCrop(
    Uint8List jpegCrop,
  ) async {
    final base64Image = base64Encode(jpegCrop);

    Exception? lastError;
    for (var attempt = 0; attempt <= _settings.maxRetries; attempt++) {
      try {
        return switch (_settings.provider) {
          VlmProvider.gemini => await _callGemini(base64Image),
          VlmProvider.openai => await _callOpenAI(base64Image),
        };
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == _settings.maxRetries) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (attempt + 1)),
        );
      } on VlmParseException {
        rethrow;
      }
    }
    throw lastError!;
  }

  /// Classify multiple crops in a single prompt (batch mode).
  ///
  /// Returns one [VlmClassificationResult] per input crop, in the same order.
  Future<List<VlmClassificationResult>> classifyBatch(
    List<Uint8List> jpegCrops,
  ) async {
    if (jpegCrops.isEmpty) return const [];
    if (jpegCrops.length == 1) {
      return [await classifyVehicleCrop(jpegCrops.first)];
    }

    final base64Images = jpegCrops.map(base64Encode).toList();

    Exception? lastError;
    for (var attempt = 0; attempt <= _settings.maxRetries; attempt++) {
      try {
        return switch (_settings.provider) {
          VlmProvider.gemini => await _callGeminiBatch(base64Images),
          VlmProvider.openai => await _callOpenAIBatch(base64Images),
        };
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e) || attempt == _settings.maxRetries) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (attempt + 1)),
        );
      } on VlmParseException {
        rethrow;
      }
    }
    throw lastError!;
  }

  void dispose() => _dio.close();

  // ---------------------------------------------------------------------------
  // Gemini
  // ---------------------------------------------------------------------------

  Future<VlmClassificationResult> _callGemini(String base64Image) async {
    final url =
        '${ApiConstants.geminiGenerateContent(_settings.model)}'
        '?key=${_settings.apiKey}';

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: _buildGeminiPayload([base64Image]),
    );

    final text = _extractGeminiText(response.data!);
    return _parseSingleResult(text);
  }

  Future<List<VlmClassificationResult>> _callGeminiBatch(
    List<String> base64Images,
  ) async {
    final url =
        '${ApiConstants.geminiGenerateContent(_settings.model)}'
        '?key=${_settings.apiKey}';

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: _buildGeminiPayload(base64Images, batch: true),
    );

    final text = _extractGeminiText(response.data!);
    return _parseBatchResult(text, base64Images.length);
  }

  Map<String, dynamic> _buildGeminiPayload(
    List<String> base64Images, {
    bool batch = false,
  }) {
    final imageParts = base64Images.map(
      (b64) => {
        'inlineData': {'mimeType': 'image/jpeg', 'data': b64},
      },
    );

    final userText = batch
        ? '${base64Images.length}대의 차량 이미지가 첨부되어 있습니다. '
            '각 이미지를 순서대로 분류하세요. '
            'JSON 배열로 응답하세요: [{"class": <1-12>, "confidence": <0.0-1.0>}, ...]'
        : '이 차량 이미지를 분류하세요.';

    return {
      'systemInstruction': {
        'parts': [
          {'text': _settings.systemPrompt},
        ],
      },
      'contents': [
        {
          'parts': [
            ...imageParts,
            {'text': userText},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 256,
        'responseMimeType': 'application/json',
      },
    };
  }

  String _extractGeminiText(Map<String, dynamic> body) {
    try {
      final candidates = body['candidates'] as List<dynamic>;
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      return (parts.first['text'] as String).trim();
    } catch (e) {
      throw VlmParseException(
        'Failed to extract text from Gemini response: $e',
        rawResponse: jsonEncode(body),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OpenAI
  // ---------------------------------------------------------------------------

  Future<VlmClassificationResult> _callOpenAI(String base64Image) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.openaiChatCompletions,
      options: Options(
        headers: {'Authorization': 'Bearer ${_settings.apiKey}'},
      ),
      data: _buildOpenAIPayload([base64Image]),
    );

    final text = _extractOpenAIText(response.data!);
    return _parseSingleResult(text);
  }

  Future<List<VlmClassificationResult>> _callOpenAIBatch(
    List<String> base64Images,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.openaiChatCompletions,
      options: Options(
        headers: {'Authorization': 'Bearer ${_settings.apiKey}'},
      ),
      data: _buildOpenAIPayload(base64Images, batch: true),
    );

    final text = _extractOpenAIText(response.data!);
    return _parseBatchResult(text, base64Images.length);
  }

  Map<String, dynamic> _buildOpenAIPayload(
    List<String> base64Images, {
    bool batch = false,
  }) {
    final imageContent = base64Images
        .map(
          (b64) => {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$b64'},
          },
        )
        .toList();

    final userText = batch
        ? '${base64Images.length}대의 차량 이미지가 첨부되어 있습니다. '
            '각 이미지를 순서대로 분류하세요. '
            'JSON 배열로 응답하세요: [{"class": <1-12>, "confidence": <0.0-1.0>}, ...]'
        : '이 차량 이미지를 분류하세요.';

    return {
      'model': _settings.model,
      'messages': [
        {'role': 'system', 'content': _settings.systemPrompt},
        {
          'role': 'user',
          'content': [
            ...imageContent,
            {'type': 'text', 'text': userText},
          ],
        },
      ],
      'temperature': 0.1,
      'max_tokens': 256,
      'response_format': {'type': 'json_object'},
    };
  }

  String _extractOpenAIText(Map<String, dynamic> body) {
    try {
      final choices = body['choices'] as List<dynamic>;
      final message = choices.first['message'] as Map<String, dynamic>;
      return (message['content'] as String).trim();
    } catch (e) {
      throw VlmParseException(
        'Failed to extract text from OpenAI response: $e',
        rawResponse: jsonEncode(body),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Response parsing
  // ---------------------------------------------------------------------------

  static final _jsonObjectPattern = RegExp(r'\{[^{}]*\}');
  static final _jsonArrayPattern = RegExp(r'\[[\s\S]*\]');

  VlmClassificationResult _parseSingleResult(String text) {
    final parsed = _tryParseJson(text);

    if (parsed is Map<String, dynamic>) {
      return _mapToResult(parsed, text);
    }

    if (parsed is List && parsed.isNotEmpty) {
      return _mapToResult(parsed.first as Map<String, dynamic>, text);
    }

    final match = _jsonObjectPattern.firstMatch(text);
    if (match != null) {
      final obj = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return _mapToResult(obj, text);
    }

    throw VlmParseException(
      'No valid JSON object found in VLM response',
      rawResponse: text,
    );
  }

  List<VlmClassificationResult> _parseBatchResult(
    String text,
    int expectedCount,
  ) {
    final parsed = _tryParseJson(text);

    if (parsed is List) {
      return parsed
          .cast<Map<String, dynamic>>()
          .map((obj) => _mapToResult(obj, text))
          .toList();
    }

    if (parsed is Map<String, dynamic>) {
      final listValue = parsed.values.firstWhere(
        (v) => v is List,
        orElse: () => null,
      );
      if (listValue is List) {
        return listValue
            .cast<Map<String, dynamic>>()
            .map((obj) => _mapToResult(obj, text))
            .toList();
      }
      return [_mapToResult(parsed, text)];
    }

    final arrayMatch = _jsonArrayPattern.firstMatch(text);
    if (arrayMatch != null) {
      final list = jsonDecode(arrayMatch.group(0)!) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map((obj) => _mapToResult(obj, text))
          .toList();
    }

    final objectMatches = _jsonObjectPattern.allMatches(text).toList();
    if (objectMatches.isNotEmpty) {
      return objectMatches.map((m) {
        final obj = jsonDecode(m.group(0)!) as Map<String, dynamic>;
        return _mapToResult(obj, text);
      }).toList();
    }

    throw VlmParseException(
      'No valid JSON found in VLM batch response',
      rawResponse: text,
    );
  }

  VlmClassificationResult _mapToResult(
    Map<String, dynamic> json,
    String rawResponse,
  ) {
    final classCode = _extractClassCode(json);
    final confidence = _extractConfidence(json);

    if (classCode < 1 || classCode > 12) {
      throw VlmParseException(
        'Class code $classCode out of valid range 1–12',
        rawResponse: rawResponse,
      );
    }

    return VlmClassificationResult(
      classCode: classCode,
      confidence: confidence.clamp(0.0, 1.0),
      source: 'vlm',
      rawResponse: rawResponse,
    );
  }

  int _extractClassCode(Map<String, dynamic> json) {
    final raw = json['class'] ?? json['class_code'] ?? json['classCode'];
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    if (raw is String) return int.parse(raw);
    throw VlmParseException(
      'Missing or invalid "class" field in VLM response',
      rawResponse: jsonEncode(json),
    );
  }

  double _extractConfidence(Map<String, dynamic> json) {
    final raw = json['confidence'] ?? json['conf'] ?? json['score'];
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is String) return double.parse(raw);
    return 0.0;
  }

  static dynamic _tryParseJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  bool _isRetryable(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    final statusCode = e.response?.statusCode;
    return statusCode == 429 || (statusCode != null && statusCode >= 500);
  }
}
