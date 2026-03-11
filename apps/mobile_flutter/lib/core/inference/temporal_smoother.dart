/// Stage 4 — Temporal smoothing of per-track classification predictions.
///
/// Stabilises class labels by aggregating predictions over a sliding window,
/// using either majority voting (default) or exponential moving average (EMA).
///
/// Ported from `services/inference_worker/inference_worker/stages/smoother.py`.
library;

import 'package:greyeye_mobile/core/inference/models.dart';
import 'package:greyeye_mobile/core/inference/pipeline_settings.dart';

class TemporalSmoother {
  TemporalSmoother(this._settings);

  final SmootherSettings _settings;

  /// Produce a smoothed prediction from a track's class history.
  ///
  /// Returns `null` if the track hasn't accumulated enough frames yet.
  SmoothedPrediction? smooth(
    List<ClassPrediction> classHistory,
    int trackAge,
  ) {
    if (trackAge < _settings.minTrackAge || classHistory.isEmpty) {
      return null;
    }

    return switch (_settings.strategy) {
      SmoothingStrategy.ema => _smoothEma(classHistory, _settings.emaAlpha),
      SmoothingStrategy.majority =>
        _smoothMajority(classHistory, _settings.window),
    };
  }
}

SmoothedPrediction _smoothMajority(
  List<ClassPrediction> classHistory,
  int window,
) {
  final recent = classHistory.length <= window
      ? classHistory
      : classHistory.sublist(classHistory.length - window);

  // Count votes per class code.
  final votes = <int, int>{};
  for (final p in recent) {
    votes[p.classCode] = (votes[p.classCode] ?? 0) + 1;
  }

  // Find winner.
  var winnerCode = recent.last.classCode;
  var winnerCount = 0;
  for (final entry in votes.entries) {
    if (entry.value > winnerCount) {
      winnerCount = entry.value;
      winnerCode = entry.key;
    }
  }

  return SmoothedPrediction(
    classCode: winnerCode,
    confidence: winnerCount / recent.length,
    probabilities: _averageProbabilities(recent),
    rawPrediction: recent.last,
  );
}

SmoothedPrediction _smoothEma(
  List<ClassPrediction> classHistory,
  double alpha,
) {
  const n = 12;
  final ema = List<double>.filled(n, 0.0);

  for (final pred in classHistory) {
    for (var i = 0; i < n; i++) {
      ema[i] = alpha * pred.probabilities[i] + (1 - alpha) * ema[i];
    }
  }

  // Normalise.
  var total = 0.0;
  for (final v in ema) {
    total += v;
  }
  if (total > 0) {
    for (var i = 0; i < n; i++) {
      ema[i] /= total;
    }
  }

  var bestIdx = 0;
  for (var i = 1; i < n; i++) {
    if (ema[i] > ema[bestIdx]) bestIdx = i;
  }

  return SmoothedPrediction(
    classCode: bestIdx + 1,
    confidence: ema[bestIdx],
    probabilities: ema,
    rawPrediction: classHistory.last,
  );
}

List<double> _averageProbabilities(List<ClassPrediction> preds) {
  const n = 12;
  if (preds.isEmpty) return List<double>.filled(n, 0.0);

  final avg = List<double>.filled(n, 0.0);
  for (final p in preds) {
    for (var i = 0; i < n; i++) {
      avg[i] += p.probabilities[i];
    }
  }
  final count = preds.length.toDouble();
  for (var i = 0; i < n; i++) {
    avg[i] /= count;
  }
  return avg;
}
