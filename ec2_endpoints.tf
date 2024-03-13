// endpoints to ssh to ec2 (worker nodes)

// sg gets created by managed node group so we need to use data to get it


resource "aws_ec2_instance_connect_endpoint" "ec2_endpoint_a" {
  subnet_id = aws_subnet.private-us-east-1a.id
security_group_ids = [aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id] 

  tags = {
    Name = "${var.project_name}-endpoint-ec2-a-${var.environment}"
  }
}

resource "aws_ec2_instance_connect_endpoint" "ec2_endpoint_b" {
  subnet_id = aws_subnet.private-us-east-1a.id
security_group_ids = [aws_eks_cluster.eks-cluster.vpc_config[0].cluster_security_group_id] 

  tags = {
    Name = "${var.project_name}-endpoint-ec2-b-${var.environment}"
  }
}