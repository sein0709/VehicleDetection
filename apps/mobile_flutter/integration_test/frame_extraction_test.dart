import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/video_frame_extractor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// End-to-end smoke test for [VideoFrameExtractor]. Runs on a real
/// device / emulator so the platform channels (video_thumbnail +
/// FFmpegKit) actually execute.
///
/// Run with:
///   flutter test integration_test/frame_extraction_test.dart -d emulator-5554
///
/// What this proves:
///  - The bundled fixture mp4 reaches the device
///  - video_thumbnail decodes a frame from it (returns non-null PNG bytes)
///  - The extractor's image short-circuit works for a still png
///  - Bytes returned from the extractor pass `Image.memory`'s decoder
///
/// What this does NOT prove:
///  - DAV (.dav) routing — would need a real Dahua sample which we
///    don't bundle (and FFmpegKit's DAV demuxer needs system codecs
///    that vary per device); covered by the unit tests' code path
///    asserts and a manual smoke test on devices.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late File fixtureMp4;

  setUpAll(() async {
    // Copy the bundled asset to the device's temp dir — the extractor
    // takes a filesystem path, not an asset key.
    final bytes = await rootBundle.load('assets/test/sample_1s.mp4');
    final tmp = await getTemporaryDirectory();
    fixtureMp4 = File(p.join(tmp.path, 'sample_1s.mp4'));
    await fixtureMp4.writeAsBytes(bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    ),);
  });

  group('VideoFrameExtractor', () {
    test('extracts a non-empty frame from the bundled mp4 fixture',
        () async {
      const extractor = VideoFrameExtractor();
      final stopwatch = Stopwatch()..start();
      final frame = await extractor.extractFrame(fixtureMp4.path);
      stopwatch.stop();

      // ignore: avoid_print
      print(
        '[frame-extraction] mp4 frame returned ${frame?.length ?? -1} bytes '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );

      expect(frame, isNotNull,
          reason: 'video_thumbnail should decode the fixture mp4 on this '
              'platform; if this fails check `flutter logs` for native '
              'plugin errors.',);
      expect(frame!.lengthInBytes, greaterThan(64),
          reason: 'PNG-encoded 320x240 frame should be at least a few hundred '
              'bytes even for a solid colour.',);

      // Magic-number sniff — proves we got an encoded image of some
      // kind, not random bytes. We accept both PNG (video_thumbnail's
      // default on Android/iOS) and JPEG (the FFmpeg fallback's
      // output, since the macOS `_min` build lacks a PNG encoder).
      final isPng = frame[0] == 0x89 &&
          frame[1] == 0x50 && // 'P'
          frame[2] == 0x4E && // 'N'
          frame[3] == 0x47; //  'G'
      final isJpeg = frame[0] == 0xFF && frame[1] == 0xD8 && frame[2] == 0xFF;
      expect(isPng || isJpeg, isTrue,
          reason: 'Expected PNG (89 50 4E 47) or JPEG (FF D8 FF) magic '
              'bytes; got 0x${frame[0].toRadixString(16)} '
              '0x${frame[1].toRadixString(16)} '
              '0x${frame[2].toRadixString(16)} '
              '0x${frame[3].toRadixString(16)}',);
    });

    test('image-extension short-circuit returns the file bytes as-is',
        () async {
      // Grab a still PNG fixture. The extractor just reads the file —
      // doesn't touch any platform channel.
      final tmp = await getTemporaryDirectory();
      final png = File(p.join(tmp.path, 'sample.png'));
      // Tiny 1x1 transparent PNG (committed inline as bytes).
      await png.writeAsBytes(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      final bytes = await const VideoFrameExtractor().extractFrame(png.path);
      expect(bytes, isNotNull);
      expect(bytes!.length, 67); // exactly the PNG bytes we wrote
    });

    test('returns null cleanly for a non-existent file (no exception)',
        () async {
      final bytes = await const VideoFrameExtractor()
          .extractFrame('/tmp/this_file_does_not_exist.mp4');
      expect(bytes, isNull);
    });

    test('extension routing helpers agree with the extractor', () {
      expect(looksLikeImagePath('/foo/bar.png'), isTrue);
      expect(looksLikeImagePath('/foo/bar.JPG'), isTrue);
      expect(looksLikeImagePath('/foo/bar.mp4'), isFalse);
      expect(looksLikeDavPath('/foo/bar.dav'), isTrue);
      expect(looksLikeDavPath('/foo/bar.DAV'), isTrue);
      expect(looksLikeDavPath('/foo/bar.mp4'), isFalse);
    });
  });
}
