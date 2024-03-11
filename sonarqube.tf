# data "aws_iam_policy_document" "sonar_rol_assume_role_policy" {
#   count = var.project_name == "utility-cluster" ? 1 : 0 // if not utility-cluster create 0 instances of this resource/module
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     effect  = "Allow"

#     condition { 
#       test     = "StringEquals"
#       variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" 
#       values   = ["system:serviceaccount:default:sonar-sa"] // service acc name and namespace
#     }

#     principals {
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#       type        = "Federated"
#     }
#   }
# }


# resource "aws_iam_role" "sonar_rol" {
#   count = var.project_name == "utility-cluster" ? 1 : 0 
#   assume_role_policy = data.aws_iam_policy_document.sonar_rol_assume_role_policy[0].json
#   name               = "${var.project_name}-sonar-rol-${var.environment}"
# }

# resource "aws_iam_role_policy_attachment" "sonar-rds" {
#   count = var.project_name == "utility-cluster" ? 1 : 0
#   policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
#   role       = aws_iam_role.sonar_rol[0].name
# }


// dont forget to set the service type to NodePort in the values

resource "helm_release" "sonarqube" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name       = "${var.project_name}-sonarqube-${var.environment}"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  version    = "10.4.1+2389"

  values = [
    file("${path.module}/sonarqube-values.yml")
  ]

#   set {
#     name  = "serviceAccount.create"
#     value = true
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "sonar-sa"
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = aws_iam_role.sonar_rol[0].arn
#   }

  set {
    name  = "jdbcOverwrite.enable"
    value = true
  }

  set {
    name  = "jdbcOverwrite.jdbcUrl"
    value = "jdbc:postgresql://${aws_db_instance.rds[0].endpoint}/sonardb" // 11.0.11.187 enpoint returns adress:port
  }

  set {
    name  = "jdbcOverwrite.jdbcUsername"
    value = var.sonar_db_username
  }

  set {
    name  = "jdbcOverwrite.jdbcPassword"
    value = var.sonar_db_password
  }


  depends_on = [
    aws_eks_node_group.private-nodes, aws_db_instance.rds[0]
  ]
}
