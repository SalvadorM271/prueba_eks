// dont forget to set the service type to NodePort in the values

resource "helm_release" "sonarqube" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name       = "${var.project_name}-sonarqube-${var.environment}"
  repository = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart      = "sonarqube"
  version    = "10.0.0+521"

  values = [
    file("${path.module}/sonarqube-values.yml")
  ]


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
