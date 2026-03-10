import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:greyeye_mobile/core/theme/app_colors.dart';

enum AlertSeverity {
  info(AppColors.severityInfo),
  warning(AppColors.severityWarning),
  critical(AppColors.severityCritical);

  const AlertSeverity(this.color);
  final Color color;
}

enum AlertStatus { triggered, acknowledged, assigned, resolved, suppressed }

@immutable
class AlertRule {
  const AlertRule({
    required this.id,
    required this.name,
    required this.conditionType,
    this.cameraId,
    this.siteId,
    this.threshold = 0,
    this.severity = AlertSeverity.warning,
    this.enabled = true,
    this.cooldownMinutes = 15,
  });

  final String id;
  final String name;
  final String conditionType;
  final String? cameraId;
  final String? siteId;
  final double threshold;
  final AlertSeverity severity;
  final bool enabled;
  final int cooldownMinutes;

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
        id: json['id'] as String,
        name: json['name'] as String,
        conditionType: json['condition_type'] as String,
        cameraId: json['camera_id'] as String?,
        siteId: json['site_id'] as String?,
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
        severity: AlertSeverity.values.firstWhere(
          (s) => s.name == json['severity'],
          orElse: () => AlertSeverity.warning,
        ),
        enabled: json['enabled'] as bool? ?? true,
        cooldownMinutes: json['cooldown_minutes'] as int? ?? 15,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'condition_type': conditionType,
        if (cameraId != null) 'camera_id': cameraId,
        if (siteId != null) 'site_id': siteId,
        'threshold': threshold,
        'severity': severity.name,
        'enabled': enabled,
        'cooldown_minutes': cooldownMinutes,
      };
}

@immutable
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.ruleId,
    required this.ruleName,
    required this.conditionType,
    this.cameraId,
    this.siteId,
    this.siteName,
    this.cameraName,
    required this.severity,
    required this.status,
    this.message = '',
    this.triggeredAt,
    this.acknowledgedAt,
    this.resolvedAt,
    this.assignedTo,
  });

  final String id;
  final String ruleId;
  final String ruleName;
  final String conditionType;
  final String? cameraId;
  final String? siteId;
  final String? siteName;
  final String? cameraName;
  final AlertSeverity severity;
  final AlertStatus status;
  final String message;
  final DateTime? triggeredAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final String? assignedTo;

  bool get isActive =>
      status == AlertStatus.triggered || status == AlertStatus.acknowledged;

  factory AlertEvent.fromJson(Map<String, dynamic> json) => AlertEvent(
        id: json['id'] as String,
        ruleId: json['rule_id'] as String,
        ruleName: json['rule_name'] as String? ?? '',
        conditionType: json['condition_type'] as String,
        cameraId: json['camera_id'] as String?,
        siteId: json['site_id'] as String?,
        siteName: json['site_name'] as String?,
        cameraName: json['camera_name'] as String?,
        severity: AlertSeverity.values.firstWhere(
          (s) => s.name == json['severity'],
          orElse: () => AlertSeverity.warning,
        ),
        status: AlertStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AlertStatus.triggered,
        ),
        message: json['message'] as String? ?? '',
        triggeredAt: json['triggered_at'] != null
            ? DateTime.parse(json['triggered_at'] as String)
            : null,
        acknowledgedAt: json['acknowledged_at'] != null
            ? DateTime.parse(json['acknowledged_at'] as String)
            : null,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
        assignedTo: json['assigned_to'] as String?,
      );
}
