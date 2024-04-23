resource "helm_release" "kube-prometheus-stack-chart" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name       = "kube-prometheus-stack-${var.environment}"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "51.10.0"

  # namespace = kubernetes_namespace.prometheus-stack.metadata[0].name
  namespace = "default"

  # this custom values from line 928 to line 968 were modify so grafana creates an ingress so the service is expose by an alb

  values = ["${file("logstack-values.yaml")}"] 

  # since after creating the ingress for grafana its service remains of type clusterIp, and the load balancer controller requires type NodePort the following was required

  set {
    name = "grafana.service.type"
    value = "NodePort"
  }

  # you can check the generated ingress with kubectl get ingress createdIngressName -n namespaceName -oyaml
  # to get the ingress name use kubectl get ingress -n prometheus-stack

  depends_on = [aws_eks_node_group.private-nodes, helm_release.external_dns]

}