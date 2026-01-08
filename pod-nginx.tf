resource "kubernetes_deployment_v1" "lab_soat_nginx" {
  metadata {
    name = "lab-soat-nginx"
  }

  spec {
    selector {
      match_labels = {
        app = "lab-soat-nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "lab-soat-nginx"
        }
      }
      spec {
        container {
          name  = "lab-soat-nginx"
          image = "wllsistemas/nginx_lab_soat:fase3"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}