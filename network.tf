// -----------------------------------vpc---------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-main-${var.environment}"
  }
}

// -----------------------------------igw---------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

// ---------------------------------subnets--------------------------------------

// One public and one private subnet in each availability zone

resource "aws_subnet" "private-us-east-1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_blocks[0]
  availability_zone = "us-east-1a"

  tags = {
    "Name"                                                                          = "private-us-east-1a" // alb controller uses this tag to discover subnets
    "kubernetes.io/role/internal-elb"                                               = "1"
    "kubernetes.io/cluster/${var.project_name}-eks-cluster-${var.environment}"      = "owned"
  }
}

resource "aws_subnet" "private-us-east-1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_blocks[1]
  availability_zone = "us-east-1b"

  tags = {
    "Name"                                                                          = "private-us-east-1b"
    "kubernetes.io/role/internal-elb"                                               = "1"
    "kubernetes.io/cluster/${var.project_name}-eks-cluster-${var.environment}"      = "owned"
  }
}

resource "aws_subnet" "public-us-east-1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_blocks[2]
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                                                     = "public-us-east-1a"
    "kubernetes.io/role/elb"                                                   = "1"
    "kubernetes.io/cluster/${var.project_name}-eks-cluster-${var.environment}" = "owned"
  }
}

resource "aws_subnet" "public-us-east-1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr_blocks[3]
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                                                     = "public-us-east-1b"
    "kubernetes.io/role/elb"                                                   = "1"
    "kubernetes.io/cluster/${var.project_name}-eks-cluster-${var.environment}" = "owned"
  }
}

// ----------------------------------nat-----------------------------------

resource "aws_eip" "nat_a_eip" {
  vpc = true

  tags = {
    Name = "${var.project_name}-nat-a-eip-${var.environment}"
  }
}

resource "aws_eip" "nat_b_eip" {
  vpc = true

  tags = {
    Name = "${var.project_name}-nat-b-eip-${var.environment}"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a_eip.id
  subnet_id     = aws_subnet.public-us-east-1a.id

  tags = {
    Name = "${var.project_name}-nat-a-${var.environment}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b_eip.id
  subnet_id     = aws_subnet.public-us-east-1b.id

  tags = {
    Name = "${var.project_name}-nat-b-${var.environment}"
  }

  depends_on = [aws_internet_gateway.igw]
}

// --------------------------------route tables----------------------------------

// We assosiate one table per private subnet, sinse a nat gateway is tied to an Az, if Az fails so will the nat gateway

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-a-${var.environment}"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-b-${var.environment}"
  }
}

resource "aws_route_table_association" "private-us-east-1a" {
  subnet_id      = aws_subnet.private-us-east-1a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private-us-east-1b" {
  subnet_id      = aws_subnet.private-us-east-1b.id
  route_table_id = aws_route_table.private_b.id
}

// igw does not live on a particular Az, so we can use the same route table for both public subnets

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
  }
}

resource "aws_route" "route_to_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public-us-east-1a" {
  subnet_id      = aws_subnet.public-us-east-1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-us-east-1b" {
  subnet_id      = aws_subnet.public-us-east-1b.id
  route_table_id = aws_route_table.public.id
}



