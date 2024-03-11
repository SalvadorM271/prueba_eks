# resource "kubernetes_ingress_class" "ingress_class" {
#   metadata {
#     name = "${var.project_name}-ingress-class-${var.environment}"
#   }

#   spec {
#     controller = "ingress.k8s.aws/alb"
#     parameters {
#       kind      = "IngressClass"
#       name      = "${var.project_name}-ingress-class-${var.environment}"
#     }
#   }

#   depends_on = [
#     aws_eks_node_group.private-nodes,
#     helm_release.aws-load-balancer-controller
#   ]

# }