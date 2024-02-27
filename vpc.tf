# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Wordpress-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "Wordpress-igw"
  }
}

# Public Subnets 
resource "aws_subnet" "public_subnet_AZ1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-Subnet-AZ1"
  }
}
resource "aws_subnet" "public_subnet_AZ2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"


  tags = {
    Name = "Public-Subnet-AZ2"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table_association" "public_route_AZ1" {
  subnet_id      = aws_subnet.public_subnet_AZ1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_AZ2" {
  subnet_id      = aws_subnet.public_subnet_AZ2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Subnets
resource "aws_subnet" "private_app_subnet_AZ1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-App-Subnet-AZ1"
  }
}

resource "aws_subnet" "private_app_subnet_AZ2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-App-Subnet-AZ2"
  }
}

resource "aws_subnet" "private_data_subnet_AZ1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-Data-Subnet-AZ1"
  }
}

resource "aws_subnet" "private_data_subnet_AZ2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Private-Data-Subnet-AZ2"
  }

}

# Public NAT Gateway AZ1
resource "aws_nat_gateway" "NAT_AZ1" {
  allocation_id = aws_eip.eip_nat_az1.id
  subnet_id     = aws_subnet.public_subnet_AZ1.id

  tags = {
    Name = "NAT-Gateway-AZ1"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public NAT Gateway AZ2
resource "aws_nat_gateway" "NAT_AZ2" {
  allocation_id = aws_eip.eip_nat_az2.id
  subnet_id     = aws_subnet.public_subnet_AZ2.id

  tags = {
    Name = "NAT-Gateway-AZ2"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Private route table AZ1
resource "aws_route_table" "private_route_table_AZ1" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT_AZ1.id
  }

  tags = {
    Name = "Private-Route-Table-AZ1"
  }
}

resource "aws_route_table_association" "NAT_route_app_AZ1" {
  subnet_id      = aws_subnet.private_app_subnet_AZ1.id
  route_table_id = aws_route_table.private_route_table_AZ1.id
}

resource "aws_route_table_association" "NAT_route_data_AZ1" {
  subnet_id      = aws_subnet.private_data_subnet_AZ1.id
  route_table_id = aws_route_table.private_route_table_AZ1.id
}

# Private route table AZ2
resource "aws_route_table" "private_route_table_AZ2" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT_AZ2.id
  }

  tags = {
    Name = "Private-Route-Table-AZ2"
  }
}

resource "aws_route_table_association" "NAT_route_app_AZ2" {
  subnet_id      = aws_subnet.private_app_subnet_AZ2.id
  route_table_id = aws_route_table.private_route_table_AZ2.id
}

resource "aws_route_table_association" "NAT_route_data_AZ2" {
  subnet_id      = aws_subnet.private_data_subnet_AZ2.id
  route_table_id = aws_route_table.private_route_table_AZ2.id
}

# RDS Subnet groups (specify subnets to create DB) 
resource "aws_db_subnet_group" "DB_subnet_group" {
  name       = "database-subnets"
  subnet_ids = [aws_subnet.private_data_subnet_AZ1.id, aws_subnet.private_data_subnet_AZ2.id]

  tags = {
    Name = "DB-subnets"
  }

}
