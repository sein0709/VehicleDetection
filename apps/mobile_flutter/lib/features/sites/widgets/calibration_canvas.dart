import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/sites/services/roi_normalizer.dart';
import 'package:greyeye_mobile/features/sites/services/video_frame_extractor.dart';

/// Painter contract for the calibration overlays. Implementations get
/// the rectangle inside the widget where the image is rendered (after
/// BoxFit.contain letterboxing) so they can convert their normalized
/// state back into widget pixels with [RoiNormalizer.imageRatioToWidget].
typedef CalibrationOverlayBuilder = CustomPainter Function(Rect imageRect);

/// Reusable backdrop for every per-task calibration editor (F4 speed,
/// F6 transit, F7 traffic-light). Owns the messy bits — frame
/// extraction, image decoding, BoxFit-aware tap-to-ratio conversion,
/// and a built-in "pick another backdrop" path so the operator can
/// swap the source without leaving the editor.
///
/// Editors only have to:
///  1. Render an overlay (a [CustomPainter] returned from
///     [overlayBuilder])
///  2. React to [onTap] which fires with normalized image-space ratios
///
/// Both callbacks are skipped silently when the tap falls in the
/// letterbox area outside the rendered image — saves every editor from
/// re-implementing the same null-check.
///
/// Pass an empty string for [videoPath] to open the editor without a
/// pre-picked source; the canvas will surface a "pick backdrop"
/// button. Editors that want to expose the same action in their app
/// bar should pass a [GlobalKey<CalibrationCanvasState>] and call
/// `key.currentState?.pickBackdrop()`.
class CalibrationCanvas extends StatefulWidget {
  const CalibrationCanvas({
    super.key,
    required this.videoPath,
    required this.overlayBuilder,
    required this.onTap,
    this.extractor = const VideoFrameExtractor(),
  });

  /// Path to an MP4/DAV/MOV video OR a still image (PNG/JPEG/WEBP/BMP).
  /// Empty string is allowed and tells the canvas to start in a
  /// "no backdrop" state where the operator picks the file.
  final String videoPath;
  final CalibrationOverlayBuilder overlayBuilder;
  final void Function(Offset normalizedTap) onTap;

  /// Test seam — production callers leave this at the default. Widget
  /// tests inject a fake (subclass overriding [VideoFrameExtractor.extractFrame])
  /// so the canvas can be exercised without a platform channel or a
  /// real video file.
  final VideoFrameExtractor extractor;

  @override
  State<CalibrationCanvas> createState() => CalibrationCanvasState();
}

class CalibrationCanvasState extends State<CalibrationCanvas> {
  Uint8List? _frameBytes;
  Size? _frameSize;
  bool _loading = true;
  String _loadError = '';

  // Allowed extensions for the file-pick fallback. Kept here so the
  // editor app bar entry-point and the in-canvas "no backdrop" button
  // share the same allow-list. Includes images so an operator can use
  // a CCTV still snapshot when they don't have video access.
  static const _backdropExtensions = <String>[
    'mp4', 'mov', 'm4v', 'dav',
    'png', 'jpg', 'jpeg', 'webp', 'bmp',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (widget.videoPath.isEmpty) {
      // No source picked yet — drop straight to the "pick backdrop"
      // empty state. This is the entry point used when the operator
      // opened the editor without picking a video on the parent
      // screen first.
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    await _loadFromPath(widget.videoPath);
  }

  Future<void> _loadFromPath(String path) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = '';
    });
    final bytes = await widget.extractor.extractFrame(path);
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _loading = false;
        _loadError = AppLocalizations.of(context).roiEditorFrameLoadFailed;
      });
      return;
    }
    final size = await _decodeImageSize(bytes);
    if (!mounted) return;
    setState(() {
      _frameBytes = bytes;
      _frameSize = size;
      _loading = false;
    });
  }

  /// Public entry-point so editor app bars can trigger the same picker
  /// the in-canvas empty-state offers. Wires through `file_picker` and
  /// then [VideoFrameExtractor], which routes by extension (DAV → FFmpeg,
  /// MP4 → video_thumbnail, image → bytes as-is).
  Future<void> pickBackdrop() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _backdropExtensions,
      dialogTitle: l10n.roiEditorPickBackdropTitle,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await _loadFromPath(path);
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final completer = Completer<Size>();
    final image = MemoryImage(bytes);
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  void _handleTap(Offset tap, Rect imageRect) {
    final ratio = RoiNormalizer.widgetToImageRatio(
      tap: tap,
      imageRect: imageRect,
    );
    if (ratio == null) return;
    widget.onTap(ratio);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_frameBytes == null) {
      // Two cases share this empty state:
      //  - No videoPath was provided (operator opened the editor
      //    without picking a video on the parent screen)
      //  - A path was provided but extraction failed
      // Both want the same call-to-action, so we just swap the message.
      final message = _loadError.isEmpty ? l10n.roiEditorNoBackdrop : _loadError;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: pickBackdrop,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.roiEditorPickBackdrop),
            ),
          ],
        ),
      );
    }

    final size = _frameSize!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageRect = RoiNormalizer.containRect(
          size,
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _handleTap(details.localPosition, imageRect),
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: Image.memory(_frameBytes!, fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: widget.overlayBuilder(imageRect),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
