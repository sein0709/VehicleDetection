/// Mirror of `runpod/ocr.py::normalize_plate` so the mobile UI validates
/// and stores plates in the same canonical form the server expects.
///
/// Korean plate format: optional 2–3 digit prefix, one Hangul syllable
/// from the registered set (가-힣 in practice — exact subset varies by
/// region), then 4 digits. We strip whitespace and reject anything that
/// doesn't match the regex.
abstract final class PlateNormalizer {
  /// Pattern aligned with the server-side regex (ocr.py): NN(N)가NNNN.
  /// Hangul range \uAC00-\uD7A3 covers all syllable blocks; the actual
  /// plate-issuance set is smaller, but matching the broad range here
  /// keeps the mobile validator from being stricter than the server.
  static final RegExp _re = RegExp(r'^(\d{2,3})([\uAC00-\uD7A3])(\d{4})$');

  /// Returns the canonical form (whitespace stripped) when [raw] is a
  /// valid Korean plate, or null otherwise.
  ///
  /// Examples:
  ///   "12가3456"   → "12가3456"
  ///   " 123가 4567" → "123가4567"
  ///   "ABC123"     → null
  static String? normalize(String raw) {
    final stripped = raw.replaceAll(RegExp(r'\s+'), '');
    if (stripped.isEmpty) return null;
    return _re.hasMatch(stripped) ? stripped : null;
  }

  /// True when [raw] normalizes to a valid plate. Convenience for form
  /// validators.
  static bool isValid(String raw) => normalize(raw) != null;
}
