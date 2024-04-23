resource "kubernetes_ingress_class" "example" {
  metadata {
    name = "my-aws-ingress-class-${var.environment}"
  }

  spec {
    controller = "ingress.k8s.aws/alb"
  }
}
