// ADD CONDITION SO THIS ONLY GET CREATED IF project_name = "utility-cluster"

// create EFS volume for jenkins

resource "aws_efs_file_system" "efs_vol" {
  count = var.project_name == "utility-cluster" ? 1 : 0 // if not utility-cluster create 0 instances of this resource/module
  creation_token = "${var.project_name}-efs_vol-${var.environment}"

  tags = {
    Name = "efs_vol"
  }

  depends_on = [
    aws_eks_node_group.private-nodes, helm_release.aws_efs_csi_driver
  ]

}

// creates security group to allow traffic btw efs and node group

resource "aws_security_group" "efs_sg" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name        = "${var.project_name}-efs-sg-${var.environment}"
  description = "EFS Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 2049 # NFS (Network File System) port
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  
}

// create local to avoid repetition of mount code (only add subnets were node group is deploy)

# locals {
#   count = var.project_name == "utility-cluster" ? 1 : 0
#   subnet_ids = [
#     aws_subnet.private-us-east-1a.id,
#     aws_subnet.private-us-east-1b.id,
#   ]
# }

// mounts efs on each worker node on the node group, this is what worked for me

# resource "aws_efs_mount_target" "efs_vol" {
#   count           = length(local.subnet_ids) // result of count is 2 so two resources are created
#   file_system_id  = aws_efs_file_system.efs_vol.id
#   subnet_id       = local.subnet_ids[count.index] // loops through every subnet
#   security_groups = [aws_security_group.efs_sg.id]

#   depends_on = [
#     aws_eks_node_group.private-nodes, aws_efs_file_system.efs_vol
#   ] 
# }

resource "aws_efs_mount_target" "efs_vol_a" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  file_system_id  = aws_efs_file_system.efs_vol[0].id
  subnet_id       = aws_subnet.private-us-east-1a.id
  security_groups = [aws_security_group.efs_sg[0].id]

  depends_on = [
    aws_eks_node_group.private-nodes, aws_efs_file_system.efs_vol[0]
  ] 
}

resource "aws_efs_mount_target" "efs_vol_b" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  file_system_id  = aws_efs_file_system.efs_vol[0].id
  subnet_id       = aws_subnet.private-us-east-1b.id
  security_groups = [aws_security_group.efs_sg[0].id]

  depends_on = [
    aws_eks_node_group.private-nodes, aws_efs_file_system.efs_vol[0]
  ] 
}

// if your are connecting this volume to a helm chart you would need to create this

resource "kubernetes_storage_class" "efs_jenkins" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  metadata {
    name = "efs-jenkins"
  }
  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap" 
    fileSystemId     = aws_efs_file_system.efs_vol[0].id
    directoryPerms   = "700"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/var/jenkins_home"
  }
}

// dont forget to set the service type to NodePort in the values

resource "helm_release" "jenkins" {
  count = var.project_name == "utility-cluster" ? 1 : 0
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.1.0"

  values = [
    "${file("jenkins-values.yaml")}"
  ]

  set {
    name  = "persistence.storageClass"
    value = "efs-jenkins"
  }

  depends_on = [
    kubernetes_storage_class.efs_jenkins[0],
    aws_efs_mount_target.efs_vol_a[0],
    aws_efs_mount_target.efs_vol_b[0],
    aws_eks_node_group.private-nodes
  ]
  
}