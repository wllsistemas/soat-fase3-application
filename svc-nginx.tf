resource "kubernetes_service_v1" "svc_nginx" {
  metadata {
    name = "svc-nginx"
  }

   spec {
    type = "LoadBalancer"

    selector = {
      app = "lab-soat-nginx"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}