resource "kubernetes_deployment_v1" "lab_soat_php" {
  metadata {
    name = "lab-soat-php"
  }

  spec {
    selector {
      match_labels = {
        app = "lab-soat-php"
      }
    }
    template {
      metadata {
        labels = {
          app = "lab-soat-php"
        }
      }
      spec {
        container {
          name  = "lab-soat-php"
          image = "wllsistemas/php_lab_soat:fase3-v1.0.0"
          port {
            container_port = 9000
          }
          env {
            name = "ENV_APP_ENV"
            value_from {
              config_map_key_ref {
                name = "tf-configmap"
                key  = "APP_ENV"
              }
            }
          }
          env {
            name = "ENV_APP_NAME"
            value_from {
              config_map_key_ref {
                name = "tf-configmap"
                key  = "APP_NAME"
              }
            }
          }
          env {
            name = "ENV_APP_VERSION"
            value_from {
              config_map_key_ref {
                name = "tf-configmap"
                key  = "APP_VERSION"
              }
            }
          }
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = "tf-lab-secret"
                key  = "DB_NAME"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "tf-lab-secret"
                key  = "DB_PASSWORD"
              }
            }
          }
          env {
            name = "DB_USERNAME"
            value_from {
              secret_key_ref {
                name = "tf-lab-secret"
                key  = "DB_USERNAME"
              }
            }
          }

          # Datadog APM (dd-trace-php)
          env {
            name = "DD_AGENT_HOST"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name  = "DD_TRACE_AGENT_PORT"
            value = "8126"
          }

          env {
            name  = "DD_TRACE_ENABLED"
            value = "true"
          }

          env {
            name  = "DD_SERVICE"
            value = "lab-soat-php"
          }

          env {
            name = "DD_ENV"
            value_from {
              config_map_key_ref {
                name = "tf-configmap"
                key  = "APP_ENV"
              }
            }
          }

          env {
            name = "DD_VERSION"
            value_from {
              config_map_key_ref {
                name = "tf-configmap"
                key  = "APP_VERSION"
              }
            }
          }

          env {
            name  = "DD_LOGS_INJECTION"
            value = "true"
          }

          env {
            name  = "DD_RUNTIME_METRICS_ENABLED"
            value = "true"
          }

          env {
            name  = "DD_TRACE_DEBUG"
            value = "true"
          }

          env {
            name  = "DD_TRACE_LOG_LEVEL"
            value = "debug"
          }

          env {
            name  = "DD_TRACE_LOG_FILE"
            value = "/dev/stderr"
          }

        }
      }
    }
  }
}