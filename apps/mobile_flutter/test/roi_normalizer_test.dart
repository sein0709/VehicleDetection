import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';

void main() {
  group('RoiNormalizer.roiFromCorners', () {
    test('orders corners regardless of tap sequence', () {
      // Tap top-left then bottom-right.
      final r1 = RoiNormalizer.roiFromCorners(
        const Offset(0.2, 0.3),
        const Offset(0.6, 0.8),
      );
      // Tap bottom-right then top-left — must produce the same ROI.
      final r2 = RoiNormalizer.roiFromCorners(
        const Offset(0.6, 0.8),
        const Offset(0.2, 0.3),
      );
      expect(r1, [closeTo(0.2, 1e-9), closeTo(0.3, 1e-9),
                  closeTo(0.4, 1e-9), closeTo(0.5, 1e-9),]);
      expect(r2, r1);
    });

    test('clamps inputs to [0,1]', () {
      final r = RoiNormalizer.roiFromCorners(
        const Offset(-0.1, -0.5),
        const Offset(1.5, 2.0),
      );
      expect(r, [0.0, 0.0, 1.0, 1.0]);
    });
  });

  group('RoiNormalizer.containRect', () {
    test('image wider than widget — letterboxes top/bottom', () {
      final r = RoiNormalizer.containRect(
        const Size(1920, 1080),    // 16:9
        const Size(400, 400),       // square
      );
      expect(r.width, 400.0);
      expect(r.height, closeTo(225.0, 1e-9)); // 400 / (16/9)
      expect(r.left, 0.0);
      expect(r.top, closeTo(87.5, 1e-9));
    });

    test('image taller than widget — letterboxes left/right', () {
      final r = RoiNormalizer.containRect(
        const Size(720, 1280),     // 9:16
        const Size(400, 400),
      );
      expect(r.height, 400.0);
      expect(r.width, closeTo(225.0, 1e-9));
      expect(r.top, 0.0);
      expect(r.left, closeTo(87.5, 1e-9));
    });

    test('zero-size image returns Rect.zero (no NaN crashes)', () {
      final r = RoiNormalizer.containRect(
        const Size(0, 0),
        const Size(400, 400),
      );
      expect(r, Rect.zero);
    });
  });

  group('RoiNormalizer.widgetToImageRatio', () {
    test('round-trips through imageRatioToWidget', () {
      const imageRect = Rect.fromLTWH(40, 60, 320, 180);
      const original = Offset(0.25, 0.75);
      final widget = RoiNormalizer.imageRatioToWidget(
        ratio: original,
        imageRect: imageRect,
      );
      final back = RoiNormalizer.widgetToImageRatio(
        tap: widget,
        imageRect: imageRect,
      );
      expect(back, isNotNull);
      expect(back!.dx, closeTo(original.dx, 1e-9));
      expect(back.dy, closeTo(original.dy, 1e-9));
    });

    test('returns null when tap falls in the letterbox', () {
      const imageRect = Rect.fromLTWH(40, 60, 320, 180);
      // Tap above the image — in the top letterbox area.
      final outside = RoiNormalizer.widgetToImageRatio(
        tap: const Offset(100, 30),
        imageRect: imageRect,
      );
      expect(outside, isNull);
    });
  });
}
