// EFS CSI driver

// assume policy for efs csi driver rol

data "aws_iam_policy_document" "efs_csi_rol_doc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    // this condition restrict the role created from this document to only be use by the proper service account

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:${var.project_name}-eks-csi-sa-${var.environment}"] // service acc name and namespace
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "efs_csi_rol" {
  assume_role_policy = data.aws_iam_policy_document.efs_csi_rol_doc.json
  name               = "${var.project_name}-eks-csi-rol-${var.environment}"
}

// this policy gives permissions to mount efs volumes

resource "aws_iam_policy" "efs_csi_driver" {
  name        = "${var.project_name}-eks-csi-pol-${var.environment}"
  description = "Policy for the EFS CSI driver to communicate with EFS resources."

  policy = file("./policies/efs_csi_driver_policy.json")
}

resource "aws_iam_role_policy_attachment" "efs_csi_attach_pol" {
  role       = aws_iam_role.efs_csi_rol.name
  policy_arn = aws_iam_policy.efs_csi_driver.arn
}

// create service account for efs csi driver, the cluster that it will be deployed in is defined by cluster name in kubernetes provider

resource "kubernetes_service_account" "efs_csi_controller_sa" {
  metadata {
    name      = "${var.project_name}-eks-csi-sa-${var.environment}"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_rol.arn
    }
  }

  depends_on = [
    aws_eks_node_group.private-nodes
  ]
}

// deploy efs csi driver controller in eks cluster

resource "helm_release" "aws_efs_csi_driver" {
  name       = "${var.project_name}-aws-efs-csi-driver-${var.environment}"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.efs_csi_controller_sa.metadata[0].name
  }

  depends_on = [
    aws_eks_node_group.private-nodes, kubernetes_service_account.efs_csi_controller_sa
  ]
}