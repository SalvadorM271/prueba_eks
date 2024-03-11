// --------------------------------rol for eks cluster----------------------------

// the policy in this rol allows the EKS service to assume this role

resource "aws_iam_role" "eks-cluster-rol" {
  name = "${var.project_name}-eks-rol-${var.environment}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

}

resource "aws_iam_role_policy_attachment" "eks-cluster-pol-attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster-rol.name
}

// --------------------------------eks cluster------------------------------------

resource "aws_eks_cluster" "eks-cluster" {
  name     = "${var.project_name}-eks-cluster-${var.environment}"
  role_arn = aws_iam_role.eks-cluster-rol.arn
  # version  = "1.28" // 1.29 version does not work with sonarqube

  vpc_config {
    subnet_ids = [
      aws_subnet.private-us-east-1a.id,
      aws_subnet.private-us-east-1b.id,
      aws_subnet.public-us-east-1a.id,
      aws_subnet.public-us-east-1b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks-cluster-pol-attachment]
}

// --------------------------------node groups------------------------------------

// the policy in this rol allows the ec2 instances (manage worker nodes) to assume this role

resource "aws_iam_role" "nodes_rol" {
  name = "${var.project_name}-eks-nodes-rol-${var.environment}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# resource "aws_iam_role_policy_attachment" "nodes-rds" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
#   role       = aws_iam_role.nodes_rol.name
# }

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes_rol.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes_rol.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes_rol.name
}

// managed nodes configuration (worker nodes)

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${var.project_name}-private-nodes-${var.environment}"
  node_role_arn   = aws_iam_role.nodes_rol.arn

  subnet_ids = [
    aws_subnet.private-us-east-1a.id,
    aws_subnet.private-us-east-1b.id
  ]

  capacity_type  = var.instance_mode // ON_DEMAND
  instance_types = [var.instance_type] // t3.small

  scaling_config {
    desired_size = 4
    max_size     = 10
    min_size     = 1 
  }

  // during an update to the worker nodes (EC2) only one can be unavailable at a time

  update_config {
    max_unavailable = 1
  }

  // like tags in aws

  labels = {
    role = "general"
  }


  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]

}



// ---------------------------------IAM OIDC provider-----------------------------------------

// makes service accounts able to use IAM roles

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

// ------------------------------rol for node autoscaler--------------------------------------

// this create an assume rol policy that lets only a service account named cluster-autoscaler assume this rol by using the OIDC provider

data "aws_iam_policy_document" "eks_cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"] // service account can only use role when in kube-system namespace
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cluster_autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_autoscaler_assume_role_policy.json
  name               = "${var.project_name}-autoscaler-rol-${var.environment}" // this is the name to pass to the service account
}

resource "aws_iam_policy" "eks_cluster_autoscaler" {
  name = "${var.project_name}-autoscaler-pol-${var.environment}"

  policy = jsonencode({
    Statement = [{
      Action = [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_attach" {
  role       = aws_iam_role.eks_cluster_autoscaler.name
  policy_arn = aws_iam_policy.eks_cluster_autoscaler.arn
}

output "eks_cluster_autoscaler_arn" {
  value = aws_iam_role.eks_cluster_autoscaler.arn
}
