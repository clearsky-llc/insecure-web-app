provider "aws" {
  region = "us-east-1"
}

# VPC and Network Configuration
resource "aws_vpc" "insecure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "InsecureAppVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.insecure_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.insecure_vpc.id

  tags = {
    Name = "InsecureAppIGW"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.insecure_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_route_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group (intentionally permissive)
resource "aws_security_group" "insecure_sg" {
  name        = "insecure-security-group"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.insecure_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "InsecureSecurityGroup"
  }
}

# Frontend S3 Bucket with public access
resource "aws_s3_bucket" "frontend_bucket" {
  bucket_prefix = "insecure-frontend-"
  force_destroy = true

  tags = {
    Name = "InsecureFrontendBucket"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Principal = "*"
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]
}

# IAM Roles with excessive permissions
resource "aws_iam_role" "web_server_role" {
  name = "insecure-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "web_admin_policy" {
  role       = aws_iam_role.web_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # Intentional weakness: excessive permissions
}

resource "aws_iam_instance_profile" "web_instance_profile" {
  name = "insecure-web-profile"
  role = aws_iam_role.web_server_role.name
}

resource "aws_iam_role" "app_server_role" {
  name = "insecure-app-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_admin_policy" {
  role       = aws_iam_role.app_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # Intentional weakness: excessive permissions
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "insecure-app-profile"
  role = aws_iam_role.app_server_role.name
}

# Web Server EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 (update with current AMI for your region)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.insecure_sg.id]
  key_name               = "insecure-key-pair"  # Make sure to create this key pair in AWS before deployment
  iam_instance_profile   = aws_iam_instance_profile.web_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash -xe
    yum update -y
    yum install -y git docker
    service docker start
    chkconfig docker on
    
    # Clone the application repository
    git clone https://github.com/yourusername/insecure-web-app.git
    cd insecure-web-app/web-tier
    
    # Start the web server
    docker build -t web-tier .
    docker run -d -p 80:80 -p 22:22 -p 3389:3389 web-tier
    
    # Print environment variables with sensitive info (intentional weakness)
    echo "DB_PASSWORD=insecure_password" >> /etc/environment
    echo "API_KEY=12345abcde" >> /etc/environment
  EOF

  tags = {
    Name = "WebServerInstance"
  }
}

# Application Server EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 (update with current AMI for your region)
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id  # Intentional weakness: app tier in public subnet
  vpc_security_group_ids = [aws_security_group.insecure_sg.id]
  key_name               = "insecure-key-pair"
  iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name

  user_data = <<-EOF
    #!/bin/bash -xe
    yum update -y
    yum install -y git docker
    service docker start
    chkconfig docker on
    
    # Clone the application repository
    git clone https://github.com/yourusername/insecure-web-app.git
    cd insecure-web-app/app-tier
    
    # Start the application server
    docker build -t app-tier .
    docker run -d -p 8080:8080 -e "DB_HOST=${aws_db_instance.insecure_db.address}" -e "DB_USER=admin" -e "DB_PASSWORD=insecure_password" app-tier
  EOF

  tags = {
    Name = "AppServerInstance"
  }

  depends_on = [aws_db_instance.insecure_db]
}

# RDS Database subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "insecure-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet.id]  # Ideally multiple subnets in different AZs
}

# Database tier
resource "aws_db_instance" "insecure_db" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_name                = "insecureapp"
  username               = "admin"
  password               = "insecure_password"  # Intentional weakness: hardcoded password
  publicly_accessible    = true  # Intentional weakness: publicly accessible database
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.insecure_sg.id]
  skip_final_snapshot    = true
  storage_encrypted      = false  # Intentional weakness: unencrypted storage

  tags = {
    Name = "InsecureRDSInstance"
  }
}

# Outputs
output "website_url" {
  value = "http://${aws_s3_bucket.frontend_bucket.website_endpoint}"
}

output "web_server_ip" {
  value = aws_instance.web_server.public_ip
}

output "app_server_ip" {
  value = aws_instance.app_server.public_ip
}

output "database_endpoint" {
  value = aws_db_instance.insecure_db.address
}
