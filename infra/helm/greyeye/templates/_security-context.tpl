{{/*
Default pod-level security context for GreyEye services.
Implements: non-root, read-only rootfs, drop all capabilities.
*/}}
{{- define "greyeye.podSecurityContext" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
{{- end -}}

{{/*
Default container-level security context.
*/}}
{{- define "greyeye.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
{{- end -}}

{{/*
Container security context for GPU workloads (inference worker).
Slightly relaxed: needs device access but still non-root.
*/}}
{{- define "greyeye.gpuContainerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
{{- end -}}
