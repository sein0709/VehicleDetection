import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

const _storageKeyPrefix = 'vlm_';
const _apiKeyKey = '${_storageKeyPrefix}api_key';
const _providerKey = '${_storageKeyPrefix}provider';
const _modelKey = '${_storageKeyPrefix}model';
const _nonSecretKey = '${_storageKeyPrefix}settings_json';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final vlmSettingsProvider =
    StateNotifierProvider<VlmSettingsNotifier, VlmSettings>(
  (ref) => VlmSettingsNotifier(),
);

class VlmSettingsNotifier extends StateNotifier<VlmSettings> {
  VlmSettingsNotifier() : super(const VlmSettings()) {
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _secureStorage.read(key: _apiKeyKey),
      _secureStorage.read(key: _providerKey),
      _secureStorage.read(key: _modelKey),
      _secureStorage.read(key: _nonSecretKey),
    ]);

    final apiKey = results[0] ?? '';
    final providerName = results[1];
    final model = results[2];
    final nonSecretJson = results[3];

    var settings = state.copyWith(apiKey: apiKey);

    if (providerName != null) {
      final provider = VlmProvider.values.asNameMap()[providerName];
      if (provider != null) settings = settings.copyWith(provider: provider);
    }

    if (model != null) {
      settings = settings.copyWith(model: model);
    }

    if (nonSecretJson != null) {
      settings = _mergeNonSecretJson(settings, nonSecretJson);
    }

    if (mounted) state = settings;
  }

  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<void> setProvider(VlmProvider provider) async {
    state = state.copyWith(provider: provider);
    await _secureStorage.write(key: _providerKey, value: provider.name);
  }

  Future<void> setModel(String model) async {
    state = state.copyWith(model: model);
    await _secureStorage.write(key: _modelKey, value: model);
  }

  Future<void> setConfidenceThreshold(double value) async {
    state = state.copyWith(confidenceThreshold: value);
    await _persistNonSecret();
  }

  Future<void> setBatchSize(int value) async {
    state = state.copyWith(batchSize: value);
    await _persistNonSecret();
  }

  Future<void> setBatchTimeoutMs(int value) async {
    state = state.copyWith(batchTimeoutMs: value);
    await _persistNonSecret();
  }

  Future<void> setRequestTimeoutMs(int value) async {
    state = state.copyWith(requestTimeoutMs: value);
    await _persistNonSecret();
  }

  Future<void> setMaxRetries(int value) async {
    state = state.copyWith(maxRetries: value);
    await _persistNonSecret();
  }

  Future<void> setSystemPrompt(String prompt) async {
    state = state.copyWith(systemPrompt: prompt);
    await _persistNonSecret();
  }

  Future<void> updateSettings(VlmSettings settings) async {
    final apiKeyChanged = settings.apiKey != state.apiKey;
    final providerChanged = settings.provider != state.provider;
    final modelChanged = settings.model != state.model;

    state = settings;

    final futures = <Future<void>>[_persistNonSecret()];
    if (apiKeyChanged) {
      futures.add(_secureStorage.write(key: _apiKeyKey, value: settings.apiKey));
    }
    if (providerChanged) {
      futures.add(
        _secureStorage.write(key: _providerKey, value: settings.provider.name),
      );
    }
    if (modelChanged) {
      futures.add(_secureStorage.write(key: _modelKey, value: settings.model));
    }
    await Future.wait(futures);
  }

  /// Removes the stored API key and resets all VLM settings to defaults.
  Future<void> clearAll() async {
    state = const VlmSettings();
    await Future.wait([
      _secureStorage.delete(key: _apiKeyKey),
      _secureStorage.delete(key: _providerKey),
      _secureStorage.delete(key: _modelKey),
      _secureStorage.delete(key: _nonSecretKey),
    ]);
  }

  Future<void> _persistNonSecret() async {
    final json = jsonEncode({
      'confidenceThreshold': state.confidenceThreshold,
      'batchSize': state.batchSize,
      'batchTimeoutMs': state.batchTimeoutMs,
      'requestTimeoutMs': state.requestTimeoutMs,
      'maxRetries': state.maxRetries,
      'systemPrompt': state.systemPrompt,
    });
    await _secureStorage.write(key: _nonSecretKey, value: json);
  }

  VlmSettings _mergeNonSecretJson(VlmSettings base, String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return base.copyWith(
        confidenceThreshold:
            (map['confidenceThreshold'] as num?)?.toDouble(),
        batchSize: map['batchSize'] as int?,
        batchTimeoutMs: map['batchTimeoutMs'] as int?,
        requestTimeoutMs: map['requestTimeoutMs'] as int?,
        maxRetries: map['maxRetries'] as int?,
        systemPrompt: map['systemPrompt'] as String?,
      );
    } on Object {
      return base;
    }
  }
}
