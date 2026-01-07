resource "kubernetes_config_map_v1" "php_app_config" {
  metadata {
    name = "tf-configmap"
  }

  data = {
    APP_NAME    = "lab-soat"
    APP_VERSION = "1.0.0"
    APP_ENV     = "production"
  }
}