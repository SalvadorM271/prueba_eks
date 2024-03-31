// assume policy for external dns rol to be assume by a service account

data "aws_iam_policy_document" "external_dns_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition { 
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" 
      values   = ["system:serviceaccount:kube-system:external-dns"] // namespace and service account
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external_dns" {
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role_policy.json
  name               = "${var.project_name}-external-dns-rol-${var.environment}"
}

resource "aws_iam_policy" "external_dns" {
  policy = file("./policies/external_dns.json") // this is more in case i wanted to use route 53
  name   = "${var.project_name}-ext-dns-pol-${var.environment}"
}

resource "aws_iam_role_policy_attachment" "external-dns_attach" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

// deployed in same namespace as the app

resource "helm_release" "external_dns" {
  name       = "${var.project_name}-external-dns-${var.environment}"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "external-dns"
  version    = "6.28.1"

  namespace = "kube-system"

  set {
    name = "provider"
    value = "cloudflare"
  }

  set {
    name = "cloudflare.email"
    value = var.cloudflare_email // saved as sensitive in terraform cloud
  }

  set {
    name = "cloudflare.apiKey"
    value = var.cloudflare_api_key // saved as sensitive in terraform cloud
  }

  depends_on = [aws_eks_node_group.private-nodes]

}