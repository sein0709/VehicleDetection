import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greyeye_mobile/core/constants/vehicle_classes.dart';
import 'package:greyeye_mobile/core/database/database.dart';
import 'package:greyeye_mobile/core/database/database_provider.dart';
import 'package:greyeye_mobile/core/l10n/app_localizations.dart';
import 'package:greyeye_mobile/features/classify/models/classify_result.dart';
import 'package:greyeye_mobile/features/classify/providers/classify_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class ClassifyScreen extends ConsumerStatefulWidget {
  const ClassifyScreen({super.key});

  @override
  ConsumerState<ClassifyScreen> createState() => _ClassifyScreenState();
}

class _ClassifyScreenState extends ConsumerState<ClassifyScreen> {
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (picked == null) return;
    ref.read(classifyProvider.notifier).classifyImage(picked.path);
  }

  Future<void> _saveResult(VehicleClassifyResult vehicle) async {
    final state = ref.read(classifyProvider);
    if (state.imagePath == null) return;

    final dao = ref.read(classificationsDaoProvider);
    await dao.insertClassification(ManualClassificationsCompanion.insert(
      id: _uuid.v4(),
      imagePath: state.imagePath!,
      stage1Class: vehicle.stage1ClassCode,
      stage1Confidence: vehicle.stage1Confidence,
      wheelCount: Value(vehicle.wheelCount),
      jointCount: Value(vehicle.jointCount),
      axleCount: Value(vehicle.axleCount),
      hasTrailer: Value(vehicle.hasTrailer),
      finalClass12: vehicle.finalClassCode,
      finalConfidence: vehicle.finalConfidence,
      bboxJson: Value(
        '{"x":${vehicle.bbox.x},"y":${vehicle.bbox.y},'
        '"w":${vehicle.bbox.w},"h":${vehicle.bbox.h}}',
      ),
    ),);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).classifySaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classifyProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.classifyTitle),
        actions: [
          if (state.status == ClassifyStatus.done)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(classifyProvider.notifier).reset(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width >= 840 ? 800 : double.infinity,
          ),
          child: switch (state.status) {
            ClassifyStatus.idle => _buildPickerView(theme),
            ClassifyStatus.loading || ClassifyStatus.classifying =>
              _buildLoadingView(state),
            ClassifyStatus.done => _buildResultView(state, theme),
            ClassifyStatus.error => _buildErrorView(state, theme),
          },
        ),
      ),
    );
  }

  Widget _buildPickerView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).classifyVehicle,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).classifyDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(AppLocalizations.of(context).classifyCamera),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(AppLocalizations.of(context).classifyGallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(ClassifyState state) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            state.status == ClassifyStatus.loading
                ? l10n.classifyLoadingModels
                : l10n.classifyClassifying,
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(ClassifyState state, ThemeData theme) {
    final result = state.result!;
    final imagePath = state.imagePath!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.file(
                File(imagePath),
                width: double.infinity,
                fit: BoxFit.contain,
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _DetectionOverlayPainter(
                    vehicles: result.vehicleResults,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.vehicleResults.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:               Text(
                AppLocalizations.of(context).classifyNoVehicles,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...result.vehicleResults.asMap().entries.map((entry) {
            final idx = entry.key;
            final vehicle = entry.value;
            return _VehicleResultCard(
              index: idx,
              vehicle: vehicle,
              onSave: () => _saveResult(vehicle),
            );
          }),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: Text(AppLocalizations.of(context).classifyNewPhoto),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: Text(AppLocalizations.of(context).classifyGallery),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorView(ClassifyState state, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).classifyFailed,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? AppLocalizations.of(context).classifyUnknownError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(classifyProvider.notifier).reset(),
              child: Text(AppLocalizations.of(context).classifyTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleResultCard extends StatelessWidget {
  const _VehicleResultCard({
    required this.index,
    required this.vehicle,
    required this.onSave,
  });

  final int index;
  final VehicleClassifyResult vehicle;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vc = VehicleClass.fromCode(vehicle.finalClassCode);
    final color = vc?.color ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vc?.labelKo ?? 'C${vehicle.finalClassCode}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (vc != null)
                        Text(
                          vc.labelKo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  onPressed: onSave,
                  tooltip: AppLocalizations.of(context).classifySaveTooltip,
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
              label: AppLocalizations.of(context).classifyStage1,
              value: '${vehicle.stage1Label} '
                  '(${(vehicle.stage1Confidence * 100).toStringAsFixed(1)}%)',
            ),
            if (vehicle.stage1ClassCode == 3) ...[
              _InfoRow(
                label: AppLocalizations.of(context).classifyWheels,
                value: '${vehicle.wheelCount}',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).classifyJoints,
                value: '${vehicle.jointCount}',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).classifyAxles,
                value: '${vehicle.axleCount}',
              ),
              _InfoRow(
                label: AppLocalizations.of(context).classifyTrailer,
                value: vehicle.hasTrailer ? AppLocalizations.of(context).classifyYes : AppLocalizations.of(context).classifyNo,
              ),
            ],
            _InfoRow(
              label: AppLocalizations.of(context).classifyFinalClass,
              value: 'C${vehicle.finalClassCode.toString().padLeft(2, '0')} — '
                  '${vc?.labelKo ?? AppLocalizations.of(context).classifyUnknown}',
            ),
            _InfoRow(
              label: AppLocalizations.of(context).classifyConfidence,
              value: '${(vehicle.finalConfidence * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectionOverlayPainter extends CustomPainter {
  _DetectionOverlayPainter({required this.vehicles});

  final List<VehicleClassifyResult> vehicles;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < vehicles.length; i++) {
      final v = vehicles[i];
      final vc = VehicleClass.fromCode(v.finalClassCode);
      final color = vc?.color ?? Colors.white;

      final rect = Rect.fromLTWH(
        v.bbox.x * size.width,
        v.bbox.y * size.height,
        v.bbox.w * size.width,
        v.bbox.h * size.height,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(rect, paint);

      final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
      final label = '${vc?.labelKo ?? "C${v.finalClassCode}"} '
          '${(v.finalConfidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(labelRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionOverlayPainter oldDelegate) =>
      vehicles != oldDelegate.vehicles;
}
