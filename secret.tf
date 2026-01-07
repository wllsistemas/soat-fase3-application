resource "kubernetes_secret_v1" "lab_secret" {
  metadata {
    name = "tf-lab-secret"
  }
  type = "Opaque"
  data = {
    DB_USERNAME = "postgres" 
    DB_PASSWORD = "postgres"     
    DB_NAME = "postgres"     
  }
}