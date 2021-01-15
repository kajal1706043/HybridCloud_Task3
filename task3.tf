provider "aws"  {
	profile = "Kajal_043"
	region = "ap-south-1"
}	 
resource "aws_vpc" "lwvpc" {
	cidr_block       = "10.0.0.0/16"
	instance_tenancy = "default"
	enable_dns_hostnames = true
	tags = {
		Name = "lwvpc"
  	}
}

resource "aws_subnet" "lwsubnet1" {
	depends_on = [aws_vpc.lwvpc ]
	vpc_id     = "${aws_vpc.lwvpc.id}"
	cidr_block = "10.0.1.0/24"
	availability_zone = "ap-south-1a"
	map_public_ip_on_launch = "true"
	tags = {
    		Name = "lwsubnet1"
  	}
}

resource "aws_subnet" "lwsubnet2" {
	depends_on = [aws_vpc.lwvpc]
	vpc_id     = "${aws_vpc.lwvpc.id}"
	availability_zone = "ap-south-1b"
	cidr_block = "10.0.2.0/24"
	map_public_ip_on_launch = "false"
	tags = {
    		Name = "lw  subnet2"
  	}
}
resource "aws_route_table" "lw_route_table" {
	vpc_id = "${aws_vpc.lwvpc.id}"
	tags = {
		Name ="lw_route_table"
	}
}
resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.lwsubnet1.id
  route_table_id = aws_route_table.lw_route_table.id
}
resource "aws_internet_gateway" "lw_internet_gateway" {
  vpc_id = "${aws_vpc.lwvpc.id}"
  tags = {
    Name = "main"
  }
  depends_on = [aws_vpc.lwvpc ] 
}
resource "aws_route" "default_route" {
	route_table_id = aws_route_table.lw_route_table.id
	destination_cidr_block = "0.0.0.0/0"
	gateway_id = aws_internet_gateway.lw_internet_gateway.id
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow_tls"
  vpc_id      = "${aws_vpc.lwvpc.id}"
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "ping-icmp"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls1"
  }
}
resource "aws_security_group" "allow_tls2" {
  name        = "allow_tls2"
  description = "Allow_tls2"
  vpc_id      = "${aws_vpc.lwvpc.id}"
  
ingress {
    description = "Mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.allow_tls.id]
  #rule is mapped with respect to ingress. When i attach a security group mean all systems that have app security enabled can connect #to my database. 
  }
ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.allow_tls.id]
  }
ingress {
    description = "icmp"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    security_groups = [aws_security_group.allow_tls.id]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls2"
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "aws_key_pair" "MyKey" {
   key_name   = "MyKey"
  public_key = "${tls_private_key.this.public_key_openssh}"
  
  depends_on = [
	tls_private_key.this
   ]
}

resource "local_file" "private-key" {
    content     = "${tls_private_key.this.private_key_pem}"
    filename = "MyKey.pem"


    depends_on = [
	tls_private_key.this
    ]
}
resource "aws_instance" "web1" {
	depends_on = [aws_internet_gateway.lw_internet_gateway, aws_security_group.allow_tls]
	ami = "ami-000cbce3e1b899ebd"
	instance_type = "t2.micro"
	key_name = "MyKey"
	subnet_id = aws_subnet.lwsubnet1.id
	security_groups = [aws_security_group.allow_tls.id]
	tags = {
		Name = "lwos1"
	}
}
resource "aws_instance" "web2" {
	depends_on = [aws_internet_gateway.lw_internet_gateway,aws_security_group.allow_tls2 ]
	ami = "ami-0019ac6129392a0f2"
	instance_type = "t2.micro"
	subnet_id = aws_subnet.lwsubnet2.id
	key_name = "MyKey"
	security_groups = [aws_security_group.allow_tls2.id]
	tags = {
		Name = "lwos2"
	}
}
resource "null_resource" "launch_wordpress"  {
	depends_on = [aws_instance.web1,aws_instance.web2]
	provisioner "local-exec"  {
		command = "start chrome ${aws_instance.web1.public_ip}/admin"
	}
}
