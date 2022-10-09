provider "aws" {
  #region     = "us-east-1"
  #access_key = "#####################"
 # secret_key = "#####################"
  profile = "default"

}

# 1.Create VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

    tags = {
      Name = "Production VPC"
    }
}

# 2. Create Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

}

# 3.Create Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}


# 4.Create Subnet
resource "aws_subnet" "subnet_1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
      Name = "prod-subnet"
  }
}

# 5.Associate subnet with Route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.prod-route-table.id
}


# 6.Create Security group to allow port 22.80.443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]   #restrict to who can use internet/connect to it, 0.0.0.0 means everyone can
   
  }

 

ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]   #restrict to who can use internet/connect to it, 0.0.0.0 means everyone can
    
  }

 


ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]   #restrict to who can use internet/connect to it, 0.0.0.0 means everyone can
    
  }


   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

   egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"   #ANY Protocol
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  
  }



  tags = {
    Name = "allow_web"
  }
}



# 7.Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8.Assign an elastic IP to network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}


# 9.Create ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"

  key_name = "main-key"


  network_interface {
    device_index = 0 #First network interface
    network_interface_id = aws_network_interface.web-server-nic.id

  }


  #Commands as user

  user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo your very first web server > /var/www/html/index.html'

        EOF
    tags = {
      Name = "web-server" }
}




