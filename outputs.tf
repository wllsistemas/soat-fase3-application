output "app_elb_hostname" {
  description = "DNS do LoadBalancer do service NGINX"
  value       = try(kubernetes_service_v1.svc_nginx.status[0].load_balancer[0].ingress[0].hostname, null)
}