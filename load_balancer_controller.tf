// defines the assume role policy to define which service account can assume the role

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition { 
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" 
      values   = ["system:serviceaccount:default:${var.project_name}-alb-controller-sa-${var.environment}"] // service acc name and namespace
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}


resource "aws_iam_role" "aws_load_balancer_controller" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "${var.project_name}-alb-controller-rol-${var.environment}"
}


resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = file("./policies/load_balancer_controller.json")
  name   = "${var.project_name}-alb-controller-pol-${var.environment}"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

// allow you to tag the alb created by the controller

resource "aws_iam_policy" "load_balancer_controller_pol" {
  name   = "${var.project_name}-inline-pol-tags-${var.environment}"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "elasticloadbalancing:AddTags",
        Resource = "*"
      }
    ]
  })
  
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller_pol.arn
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

// this helm chart will be deployed on the same namespace as the application

resource "helm_release" "aws-load-balancer-controller" {
  name = "${var.project_name}-alb-controller-${var.environment}"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "default"
  version    = "1.4.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks-cluster.id
  }

  set {
    name  = "image.tag"
    value = "v2.4.2"
  }

  set {
    name  = "serviceAccount.name"
    value = "${var.project_name}-alb-controller-sa-${var.environment}" // creates service account
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" // passes anotation to sa
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  depends_on = [
    aws_eks_node_group.private-nodes,
    aws_iam_role_policy_attachment.aws_load_balancer_controller_attach
  ]
}