# Configure AWS profile in Terraform
provider "aws" {
 region = "ap-south-1"
 profile = "amar"
}

# Creating VPC
resource "aws_vpc" "task4_vpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
tags = {
  Name = "task4_vpc"
 }
}

# Now we create two subnets in this VPC.One will be public and the other will be private.
resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.task4_vpc.id}"
  cidr_block = "192.168.10.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
tags = {
    Name = "public_subnet"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.task4_vpc.id}"
  cidr_block = "192.168.20.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"
tags = {
    Name = "private_subnet"
  }
}

# After creating the two subnets ,we will create the Internet Gateway so that the public subnet can have connectivity with the outer world.
resource "aws_internet_gateway" "task4_gateway" {
  vpc_id = "${aws_vpc.task4_vpc.id}"
tags = {
    Name = "task4_gateway"
  }
}

# Now we will create routing table for Internet gateway,and we will add route to enter the public world via Internet Gateway.
resource "aws_route_table" "task4_route_public" {
 vpc_id = "${aws_vpc.task4_vpc.id}"
 route {
 cidr_block = "0.0.0.0/0"
 gateway_id = aws_internet_gateway.task4_gateway.id
 }
tags = {
 Name = "task4_route_public"
 }
}

# Now we have to associate the routing table to the public subnet.
resource "aws_route_table_association" "a" {
 subnet_id = aws_subnet.public_subnet.id
 route_table_id = aws_route_table.task4_route_public.id
}
resource "aws_eip" "task4_eip" {
 vpc=true
}

# After Associating the routing table , we will create the NAT Gateway.
resource "aws_nat_gateway" "task4_nat" {
  allocation_id = aws_eip.task4_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = {
    Name = "task4_nat"
  }
}

resource "aws_route_table" "task4_route_private" {
  vpc_id = "${aws_vpc.task4_vpc.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.task4_gateway.id
     }
tags = {
                Name = "task4_route_private"
          }
}
#Associating the routing table to private subnet
resource "aws_route_table_association" "b" {
  subnet_id         = aws_subnet.private_subnet.id
route_table_id = aws_route_table.task4_route_private.id
}

# After that we are going to create the WordPress instance and will allow port 80.
resource "aws_security_group" "wp_sg" {
  name        = "task4_sg"
  description = "Allow ssh-22,http-80 protocols and NFS inbound traffic"
  vpc_id = "${aws_vpc.task4_vpc.id}"
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "wp_sg"
  }
}

# The security group of bastion
resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Bastion host"
  vpc_id      = aws_vpc.task4_vpc.id
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name ="bastion"
  }
}

# Security group of MySQL ,and allowing port 3306
resource "aws_security_group" "sql_sg" {
  name = "sg_mysql"
  vpc_id = "${aws_vpc.task4_vpc.id}"
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = ["${aws_security_group.wp_sg.id}"]
  }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags ={
    Name= "sql_sg"
  }
}

# Security group of bastion that will allow mysql to connect
resource "aws_security_group" "bastion_allow" {
  name        = "bashion_allow"
  description = "Allow bashion"
  vpc_id      = aws_vpc.task4_vpc.id
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
 
 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
  tags = {
    Name ="bastion_allow"
  }
}

# Now creating Wordpress instance.
resource "aws_instance" "task4_wp" {
 ami = "ami-000cbce3e1b899ebd"
 instance_type = "t2.micro"
 associate_public_ip_address = true
 key_name = "key11"
 vpc_security_group_ids = [aws_security_group.wp_sg.id]
 subnet_id = aws_subnet.public_subnet.id
tags = {
 Name = "task4_wp"
 }
}

# Creating Bastion instance
resource "aws_instance" "bastion_" {
  ami           = "ami-0732b62d310b80e97"
  instance_type = "t2.micro"
  key_name = "key11"
  vpc_security_group_ids =[aws_security_group.bastion.id]
  subnet_id = aws_subnet.public_subnet.id
 
  tags = {
    Name = "bastion"
  }
}

# Creating MYSQL database in private subnet
resource "aws_instance" "task4_sql" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name =    "key11"
  vpc_security_group_ids = [aws_security_group.sql_sg.id , aws_security_group.bastion_allow.id]
   subnet_id = aws_subnet.private_subnet.id
tags = {
    Name = "task4_sql"
  }
}