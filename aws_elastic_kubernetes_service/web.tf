resource "kubernetes_deployment" "web" {
  metadata {
    name = "web"
    annotations = var.resource_tags
  }
  spec {
    replicas = var.web_resources["replicas"]
    selector {
      match_labels = {
        app = "web"
      }
    }
    template {
      metadata {
        labels = {
          app = "web"
        }
      }
      spec {
        node_selector = {
          "kubernetes.io/role" = "web"
        }
        service_account_name = kubernetes_service_account.codecov.metadata[0].name
        volume {
          name = kubernetes_service_account.codecov.default_secret_name
          secret {
            secret_name = kubernetes_service_account.codecov.default_secret_name
          }
        }
        volume {
          name = "codecov-yml"
          secret {
            secret_name = kubernetes_secret.codecov-yml.metadata[0].name
          }
        }
        volume {
          name = "scm-ca-cert"
          secret {
            secret_name = kubernetes_secret.scm-ca-cert.metadata[0].name
          }
        }
        container {
          name  = "web"
          image = "codecov/enterprise-web:${var.codecov_version}"
          args  = ["web"]
          port {
            container_port = 5000
          }
          env {
            name = "STATSD_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }
          env {
            name = "STATSD_PORT"
            value = "8125"
          }
          env {
            name  = "SERVICES__DATABASE_URL"
            value = local.postgres_url
          }
          env {
            name  = "SERVICES__REDIS_URL"
            value = local.redis_url
          }
          env {
            name  = "SERVICES__MINIO__HOST"
            value = "s3.amazonaws.com"
          }
          env {
            name  = "SERVICES__MINIO__BUCKET"
            value = aws_s3_bucket.minio.id
          }
          env {
            name  = "SERVICES__MINIO__IAM_AUTH"
            value = "true"
          }
          resources {
            limits {
              cpu    = var.web_resources["cpu_limit"]
              memory = var.web_resources["memory_limit"]
            }
            requests {
              cpu    = var.web_resources["cpu_request"]
              memory = var.web_resources["memory_request"]
            }
          }
          readiness_probe {
            http_get {
              path = "/login"
              port = "5000"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
          image_pull_policy = "Always"
          volume_mount {
            name       = "codecov-yml"
            read_only  = "true"
            mount_path = "/config"
          }
          volume_mount {
            name       = "scm-ca-cert"
            read_only  = "true"
            mount_path = "/cert"
          }

          # when using terraform, you must explicitly mount the service account secret volume
          # https://github.com/kubernetes/kubernetes/issues/27973
          # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/38
          volume_mount {
            name       = kubernetes_service_account.codecov.default_secret_name
            read_only  = "true"
            mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "web" {
  metadata {
    name = "web"
    annotations = var.resource_tags
  }
  spec {
    port {
      protocol    = "TCP"
      port        = "5000"
      target_port = "5000"
    }
    selector = {
      app = "web"
    }
  }
}
