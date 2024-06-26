// simple database for sonarqube

resource "aws_security_group" "rds_sg" {
  count = var.project_name == "utility-cluster" ? 1 : 0 // if not utility-cluster create 0 instances of this resource/module
  name   = "${var.project_name}-rds-sg-${var.environment}"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol         = "tcp"
    from_port        = 5432
    to_port          = 5432
    # cidr_blocks      = ["11.0.0.0/16"]
    security_groups  = [aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id] // worker node security group
  }


  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }

}


// -------------------------------DB subnet group----------------------------

resource "aws_db_subnet_group" "rds_eks" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name       = "${var.project_name}-subnet-gr-${var.environment}"
  subnet_ids = [aws_subnet.private-us-east-1a.id,
    aws_subnet.private-us-east-1b.id]
}

resource "aws_kms_key" "db_key" {
  description         = "KMS key for RDS Postgres"
  key_usage           = "ENCRYPT_DECRYPT"
  enable_key_rotation = true
}



// --------------------------------RDS database------------------------------

resource "aws_db_instance" "rds" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  identifier              = "sonardb1" // name chage broke app
  db_name                 = "sonardb"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = var.rds_instance // db.t2.micro
  allocated_storage       = 20
  storage_type            = var.rds_storage_type // gp2
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.db_key.arn
  username                = var.sonar_db_username
  password                = var.sonar_db_password
  publicly_accessible     = false
  backup_retention_period = 30
  backup_window           = "21:00-23:00"
  maintenance_window      = "Sun:00:00-Sun:03:00"
  skip_final_snapshot     = false 
  final_snapshot_identifier = "${var.project_name}-rds-final-snapshot2-${var.environment}"
  vpc_security_group_ids  = [aws_security_group.rds_sg[0].id]
  db_subnet_group_name    = aws_db_subnet_group.rds_eks[0].name
}
