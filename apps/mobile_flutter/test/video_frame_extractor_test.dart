import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/video_frame_extractor.dart';
import 'package:path/path.dart' as p;

void main() {
  group('looksLikeDavPath', () {
    test('matches lowercase .dav', () {
      expect(looksLikeDavPath('/tmp/clip.dav'), isTrue);
      expect(looksLikeDavPath('clip.dav'), isTrue);
      expect(
        looksLikeDavPath(r'C:\Users\Op\Recordings\07.dav'),
        isTrue,
      );
    });

    test('matches uppercase / mixed-case .DAV', () {
      // NVRs often write extensions in uppercase.
      expect(looksLikeDavPath('/tmp/clip.DAV'), isTrue);
      expect(looksLikeDavPath('/tmp/clip.Dav'), isTrue);
    });

    test('rejects mp4 / mov / image extensions', () {
      expect(looksLikeDavPath('/tmp/clip.mp4'), isFalse);
      expect(looksLikeDavPath('/tmp/clip.MP4'), isFalse);
      expect(looksLikeDavPath('/tmp/clip.mov'), isFalse);
      expect(looksLikeDavPath('/tmp/snapshot.jpg'), isFalse);
      expect(looksLikeDavPath('/tmp/snapshot.png'), isFalse);
    });

    test('rejects no-extension and ambiguous inputs', () {
      expect(looksLikeDavPath('/tmp/clip'), isFalse);
      expect(looksLikeDavPath(''), isFalse);
      // `.dav` only triggers when it's the actual extension — a name
      // that *contains* "dav" mid-string must not match (e.g. davinci).
      expect(looksLikeDavPath('/tmp/davinci.mp4'), isFalse);
    });
  });

  group('looksLikeImagePath', () {
    test('matches common still-image extensions', () {
      expect(looksLikeImagePath('/tmp/scene.png'), isTrue);
      expect(looksLikeImagePath('/tmp/scene.jpg'), isTrue);
      expect(looksLikeImagePath('/tmp/scene.JPEG'), isTrue);
      expect(looksLikeImagePath('/tmp/scene.webp'), isTrue);
      expect(looksLikeImagePath('/tmp/scene.bmp'), isTrue);
    });

    test('rejects video and unknown extensions', () {
      expect(looksLikeImagePath('/tmp/clip.mp4'), isFalse);
      expect(looksLikeImagePath('/tmp/clip.dav'), isFalse);
      expect(looksLikeImagePath('/tmp/notes.txt'), isFalse);
      expect(looksLikeImagePath(''), isFalse);
    });
  });

  group('VideoFrameExtractor.extractFrame image short-circuit', () {
    // The image-passthrough branch is platform-independent (just
    // File.readAsBytes), so we can exercise it in the unit suite. The
    // FFmpeg / video_thumbnail branches require a device runner — those
    // are intentionally not covered here.
    test('returns the file bytes verbatim for a still image', () async {
      final tempDir = await Directory.systemTemp.createTemp('gye_extractor_');
      try {
        final fakePng = Uint8List.fromList(
          // PNG magic + arbitrary trailing bytes — the extractor must
          // not parse or re-encode.
          [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, 4, 5],
        );
        final path = p.join(tempDir.path, 'still.png');
        await File(path).writeAsBytes(fakePng);

        final out = await const VideoFrameExtractor().extractFrame(path);
        expect(out, isNotNull);
        expect(out, equals(fakePng));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null when the still-image path is missing', () async {
      final out = await const VideoFrameExtractor()
          .extractFrame('/tmp/__definitely_not_there__.png');
      expect(out, isNull);
    });
  });
}
