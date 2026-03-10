###############################################################################
# NATS Module
#
# Deploys NATS JetStream cluster via Helm chart on EKS.
# - 3-node cluster with R=3 replication
# - File-based storage on gp3 PVCs
# - Monitoring endpoint exposed
###############################################################################

resource "kubernetes_namespace" "nats" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "nats" {
  name       = "${var.name_prefix}-nats"
  repository = "https://nats-io.github.io/k8s/helm/charts/"
  chart      = "nats"
  version    = "1.2.6"
  namespace  = kubernetes_namespace.nats.metadata[0].name

  values = [yamlencode({
    config = {
      cluster = {
        enabled  = true
        replicas = var.cluster_size
      }
      jetstream = {
        enabled = true
        fileStore = {
          pvc = {
            size         = var.storage_size
            storageClassName = "gp3"
          }
        }
        memoryStore = {
          enabled = true
          maxSize = "1Gi"
        }
      }
      monitor = {
        enabled = true
        port    = 8222
      }
    }
    container = {
      merge = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }
    }
    podTemplate = {
      topologySpreadConstraints = [{
        maxSkew           = 1
        topologyKey       = "topology.kubernetes.io/zone"
        whenUnsatisfiable = "DoNotSchedule"
        labelSelector = {
          matchLabels = {
            "app.kubernetes.io/name" = "nats"
          }
        }
      }]
    }
    service = {
      merge = {
        metadata = {
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "7777"
          }
        }
      }
    }
  })]

  depends_on = [kubernetes_namespace.nats]
}
