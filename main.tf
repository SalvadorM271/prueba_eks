# --------------------------------- providers --------------------------

provider "aws" {
  region = "us-east-1"
}

terraform {

  required_version = ">= 1.3.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
    
  }

  // after adding this block, run terraform init to create the workspace if there arent any with this tags

  cloud {
    hostname     = "app.terraform.io"
    organization = "personal_demos"

    workspaces {
      tags = ["prueba", "cuscatlan"]
    }
  }

}

provider "helm" { 
  kubernetes {
    host                   = aws_eks_cluster.eks-cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks-cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks-cluster.id]
      command     = "aws"
    }
  }
}

## creates a file with what is needed to use kubernetes in our cluster

data "aws_eks_cluster_auth" "cluster_kube_config" {
  name = aws_eks_cluster.eks-cluster.id // this one needs to change for multi env since it uses cluster as ref
  depends_on = [aws_eks_cluster.eks-cluster]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks-cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster_kube_config.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks-cluster.certificate_authority.0.data)
}