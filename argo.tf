resource "kubernetes_namespace" "argo_cd" {
  metadata {
    name = "argo-cd-${var.environment}"
  }
  depends_on = [aws_eks_cluster.eks-cluster]
}

// helm chart for argocd, more here: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd 

resource "helm_release" "argo-cd" {
  name = "${var.project_name}-argo-cd-${var.environment}"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argo-cd-${var.environment}"
  version    = "5.24.0"

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "server.service.type"
    value = "NodePort"
  }

  set {
    name  = "serviceAccount.name"
    value = "argo-cd" // creates service account
  }

  depends_on = [aws_eks_cluster.eks-cluster, kubernetes_namespace.argo_cd]
}