import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/sites/services/video_frame_extractor.dart';
import 'package:greyeye_mobile/features/sites/widgets/calibration_canvas.dart';
import 'package:image/image.dart' as img;

/// Fake [VideoFrameExtractor] that returns canned bytes (or null) and
/// logs every call. Subclassing rather than mocking because the
/// concrete extractor only exposes one method we care about overriding.
///
/// Pass a [completer] to keep the future pending indefinitely — useful
/// for asserting on the loading-state UI without leaving real timers
/// outstanding (Flutter test fails the test if a Timer survives the
/// teardown).
class _FakeExtractor extends VideoFrameExtractor {
  _FakeExtractor({this.bytes, this.completer});
  final Uint8List? bytes;
  final Completer<Uint8List?>? completer;
  final List<String> calls = [];

  @override
  Future<Uint8List?> extractFrame(
    String videoPath, {
    int timeMs = 500,
    int maxWidth = 1280,
    int quality = 85,
  }) async {
    calls.add(videoPath);
    if (completer != null) return completer!.future;
    return bytes;
  }
}

/// Solid-color PNG so the canvas's MemoryImage decoder has real bytes
/// available. The decoded image stream doesn't fire under widget-test
/// fake async, so we use this only for the "loading visible while
/// extracting" case where we never let the future resolve.
Uint8List _makeFakePng({int w = 320, int h = 240}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(64, 128, 192));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

CustomPainter _noopOverlay(Rect _) => _NoopPainter();

class _NoopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(_) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalibrationCanvas', () {
    testWidgets(
      'extractor is called and CircularProgressIndicator is visible '
      'until the future resolves',
      (tester) async {
        // Never-completing future keeps the canvas in its loading state
        // for the duration of the test without leaving timers pending
        // (which Flutter's widget-test harness treats as a leak).
        final completer = Completer<Uint8List?>();
        final fake = _FakeExtractor(completer: completer);
        await tester.pumpWidget(_wrap(CalibrationCanvas(
          videoPath: '/tmp/fake.mp4',
          overlayBuilder: _noopOverlay,
          onTap: (_) {},
          extractor: fake,
        ),),);

        await tester.pump(); // run initState's _loadInitial

        expect(fake.calls, ['/tmp/fake.mp4']);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Image), findsNothing);

        // Resolve to null so any awaiters drain cleanly during teardown.
        completer.complete(null);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'renders the empty-state CTA when the extractor returns null',
      (tester) async {
        final fake = _FakeExtractor(bytes: null);
        await tester.pumpWidget(_wrap(CalibrationCanvas(
          videoPath: '/tmp/broken.mp4',
          overlayBuilder: _noopOverlay,
          onTap: (_) {},
          extractor: fake,
        ),),);

        // Drain the (immediately-resolving) extractor future and rebuild.
        await tester.pumpAndSettle();

        // Localized "Pick another backdrop" CTA + extractor was tried.
        final l10n =
            await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.roiEditorPickBackdrop), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(Image), findsNothing);
        expect(fake.calls, ['/tmp/broken.mp4']);
      },
    );

    testWidgets(
      'short-circuits to picker when videoPath is empty (no extract call)',
      (tester) async {
        final fake = _FakeExtractor(bytes: _makeFakePng());
        await tester.pumpWidget(_wrap(CalibrationCanvas(
          videoPath: '',
          overlayBuilder: _noopOverlay,
          onTap: (_) {},
          extractor: fake,
        ),),);

        await tester.pumpAndSettle();

        // The extractor is never called for empty paths — the canvas
        // jumps straight to the "no backdrop yet" picker state.
        expect(fake.calls, isEmpty);
        expect(find.byType(Image), findsNothing);
        final l10n =
            await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.roiEditorPickBackdrop), findsOneWidget);
      },
    );

    testWidgets(
      'extractor is invoked exactly once per build, with the supplied path',
      (tester) async {
        final completer = Completer<Uint8List?>();
        final fake = _FakeExtractor(completer: completer);
        await tester.pumpWidget(_wrap(CalibrationCanvas(
          videoPath: '/path/with spaces/and-dashes_and.dots.mov',
          overlayBuilder: _noopOverlay,
          onTap: (_) {},
          extractor: fake,
        ),),);
        await tester.pump();

        expect(fake.calls, ['/path/with spaces/and-dashes_and.dots.mov']);

        // Re-pump a few frames — the extractor should not be called again.
        await tester.pump();
        await tester.pump();
        expect(fake.calls.length, 1);

        completer.complete(null);
        await tester.pumpAndSettle();
      },
    );
  });
}
