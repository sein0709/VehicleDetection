import 'dart:ui';

/// Pure helpers for converting between widget-space tap coordinates and
/// the normalized [0..1] ratio coordinates the server's calibration JSON
/// expects. Kept widget-free so the math is unit-testable.
abstract final class RoiNormalizer {
  /// Build an `[x, y, w, h]` ROI in normalized image space from two tap
  /// points (any order — we sort on each axis). Inputs and the returned
  /// values are both ratios in [0..1].
  static List<double> roiFromCorners(Offset a, Offset b) {
    final x1 = a.dx.clamp(0.0, 1.0);
    final y1 = a.dy.clamp(0.0, 1.0);
    final x2 = b.dx.clamp(0.0, 1.0);
    final y2 = b.dy.clamp(0.0, 1.0);
    final left = x1 < x2 ? x1 : x2;
    final top = y1 < y2 ? y1 : y2;
    final right = x1 > x2 ? x1 : x2;
    final bottom = y1 > y2 ? y1 : y2;
    return [left, top, right - left, bottom - top];
  }

  /// Translates a tap [Offset] inside a widget that displays an image at
  /// [displaySize] (the size the image is *rendered* at, after BoxFit)
  /// into normalized image-space coordinates in [0..1]. Returns null
  /// when the tap is outside the rendered image bounds (e.g. letterbox
  /// area when the image's aspect ratio doesn't match the widget's).
  ///
  /// [imageRect] is the rectangle inside the widget where the image
  /// actually paints — typically the result of `applyBoxFit`.
  static Offset? widgetToImageRatio({
    required Offset tap,
    required Rect imageRect,
  }) {
    if (!imageRect.contains(tap)) return null;
    final dx = (tap.dx - imageRect.left) / imageRect.width;
    final dy = (tap.dy - imageRect.top) / imageRect.height;
    return Offset(dx.clamp(0.0, 1.0), dy.clamp(0.0, 1.0));
  }

  /// Converts a normalized point back into widget-space pixels for
  /// rendering overlays on top of the image.
  static Offset imageRatioToWidget({
    required Offset ratio,
    required Rect imageRect,
  }) {
    return Offset(
      imageRect.left + ratio.dx * imageRect.width,
      imageRect.top + ratio.dy * imageRect.height,
    );
  }

  /// Computes the rectangle inside a widget of [widgetSize] where an
  /// image of [imageSize] is rendered under [BoxFit.contain]. Used by
  /// the editors to translate tap coordinates correctly when the image
  /// is letterboxed.
  static Rect containRect(Size imageSize, Size widgetSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return Rect.zero;
    final imageAspect = imageSize.width / imageSize.height;
    final widgetAspect = widgetSize.width / widgetSize.height;

    double w, h;
    if (imageAspect > widgetAspect) {
      // Image is wider — fit width, letterbox top/bottom.
      w = widgetSize.width;
      h = w / imageAspect;
    } else {
      // Image is taller — fit height, letterbox left/right.
      h = widgetSize.height;
      w = h * imageAspect;
    }
    final left = (widgetSize.width - w) / 2;
    final top = (widgetSize.height - h) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }
}
