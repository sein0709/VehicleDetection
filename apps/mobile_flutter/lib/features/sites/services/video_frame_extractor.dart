import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Returns true when [path] looks like a Dahua-CCTV `.dav` recording.
///
/// Top-level so it can be reused by the picker / submit-gate without
/// instantiating an extractor. Case-insensitive — operators copy files
/// off NVRs that uppercase the extension.
bool looksLikeDavPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext == '.dav';
}

/// Returns true when [path] points to a still image we can hand to
/// `Image.memory` directly without any decoder fallback.
bool looksLikeImagePath(String path) {
  switch (p.extension(path).toLowerCase()) {
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.webp':
    case '.bmp':
      return true;
    default:
      return false;
  }
}

/// Extracts a still frame from a video file for use as a calibration
/// backdrop (line/polygon/ROI editors draw on top of it).
///
/// Routing:
///  - `.png/.jpg/...` → returned as-is via `File.readAsBytes()`.
///  - `.dav` → routed straight to FFmpeg (the platform thumbnailer
///    cannot demux Dahua containers).
///  - everything else → tries `video_thumbnail` first (cheap, native
///    code path on Android/iOS) and falls back to FFmpeg if the
///    thumbnailer returns null. Catches the long tail of codecs
///    (`.ts`, fragmented MP4, h.265-in-mov) that the platform stack
///    sometimes refuses without a clear error.
class VideoFrameExtractor {
  const VideoFrameExtractor();

  /// Returns PNG (or original-encoding for stills) bytes of a frame at
  /// [timeMs] into [videoPath], or null if every decoder we try fails.
  ///
  /// Defaults to t=500ms rather than t=0 because some encoders emit a
  /// black or partial keyframe at the start of the file. Stills ignore
  /// the parameter.
  Future<Uint8List?> extractFrame(
    String videoPath, {
    int timeMs = 500,
    int maxWidth = 1280,
    int quality = 85,
  }) async {
    if (looksLikeImagePath(videoPath)) {
      try {
        return await File(videoPath).readAsBytes();
      } on Exception catch (e, st) {
        debugPrint('[VideoFrameExtractor] image read failed: $e\n$st');
        return null;
      }
    }

    if (looksLikeDavPath(videoPath)) {
      return _extractWithFfmpeg(videoPath, timeMs: timeMs);
    }

    final thumb = await _extractWithVideoThumbnail(
      videoPath,
      timeMs: timeMs,
      maxWidth: maxWidth,
      quality: quality,
    );
    if (thumb != null) return thumb;

    // Fall back to FFmpeg for codecs the platform thumbnailer rejects
    // silently (returning null without an exception).
    return _extractWithFfmpeg(videoPath, timeMs: timeMs);
  }

  /// Convenience: writes the extracted frame to disk so screens that
  /// use `Image.file` can avoid keeping the bytes in memory across
  /// rebuilds. Caller owns deletion (typically via temp dir).
  Future<File?> extractFrameToFile(
    String videoPath,
    String destPath, {
    int timeMs = 500,
  }) async {
    final bytes = await extractFrame(videoPath, timeMs: timeMs);
    if (bytes == null) return null;
    final file = File(destPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<Uint8List?> _extractWithVideoThumbnail(
    String videoPath, {
    required int timeMs,
    required int maxWidth,
    required int quality,
  }) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        timeMs: timeMs,
        maxWidth: maxWidth,
        quality: quality,
      );
    } on Exception catch (e, st) {
      debugPrint('[VideoFrameExtractor] video_thumbnail failed: $e\n$st');
      return null;
    }
  }

  Future<Uint8List?> _extractWithFfmpeg(
    String videoPath, {
    required int timeMs,
  }) async {
    File? outFile;
    try {
      final tmpDir = await getTemporaryDirectory();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      // JPEG instead of PNG: the `ffmpeg_kit_flutter_new_min` builds
      // for some platforms (notably macOS arm64) ship without the PNG
      // encoder and fail with "Default encoder for format image2 (codec
      // png) is probably disabled". MJPEG is built in to every minimal
      // FFmpeg flavour we've shipped against, and `Image.memory`
      // doesn't care about the container format.
      final outPath = p.join(tmpDir.path, 'gye_frame_$stamp.jpg');
      // -ss before -i = fast seek (keyframe-accurate but instant).
      // -frames:v 1 grabs exactly one frame; -update 1 tells the
      // image2 muxer it's a single still (newer FFmpeg builds error
      // out without it because the output path lacks a `%03d`-style
      // sequence pattern). -c:v mjpeg pins the encoder explicitly so
      // the image2 muxer doesn't try to auto-pick one that's been
      // stripped out of the build. -q:v 2 keeps quality near visually-
      // lossless. -y overwrites.
      // We escape paths by quoting; FFmpegKit splits on whitespace.
      final seekS = (timeMs / 1000).toStringAsFixed(3);
      final cmd = '-ss $seekS -i ${_quote(videoPath)} -frames:v 1 '
          '-c:v mjpeg -q:v 2 -update 1 -y ${_quote(outPath)}';
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      outFile = File(outPath);
      if (!ReturnCode.isSuccess(rc)) {
        // Capture stderr — without this we'd just see rc=1 with no
        // hint about whether it was a missing codec, an output-pattern
        // complaint, or a permission error.
        final logs = await session.getAllLogsAsString();
        debugPrint(
          '[VideoFrameExtractor] ffmpeg rc=${rc?.getValue()} cmd=$cmd\n'
          '----- ffmpeg log -----\n$logs\n----- end ffmpeg log -----',
        );
        return null;
      }
      if (!outFile.existsSync()) {
        debugPrint('[VideoFrameExtractor] ffmpeg succeeded but no output');
        return null;
      }
      return await outFile.readAsBytes();
    } on Exception catch (e, st) {
      debugPrint('[VideoFrameExtractor] ffmpeg failed: $e\n$st');
      return null;
    } finally {
      // Best-effort cleanup; failure here just leaves a temp file the
      // OS will reap eventually.
      try {
        if (outFile != null && outFile.existsSync()) {
          await outFile.delete();
        }
      } on Exception catch (_) {}
    }
  }

  /// Wraps a path in double-quotes for the FFmpeg command line. Escapes
  /// any embedded double-quote to keep command parsing safe across
  /// gallery / temp-dir paths that may contain spaces.
  String _quote(String path) => '"${path.replaceAll('"', r'\"')}"';
}
