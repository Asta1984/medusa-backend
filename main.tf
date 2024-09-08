provider "aws" {
  region = var.region
}

# Create a VPC
resource "aws_vpc" "tf_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tf-vpc"
  }
}

# Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "tf_igw" {
  vpc_id = aws_vpc.tf_vpc.id

  tags = {
    Name = "tf-igw"
  }
}

# Create a route table for the public subnets
resource "aws_route_table" "tf_route_table" {
  vpc_id = aws_vpc.tf_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_igw.id
  }

  tags = {
    Name = "tf-public-route-table"
  }
}

# Associate the route table with the public subnets
resource "aws_route_table_association" "tf_subnet_1_assoc" {
  subnet_id      = aws_subnet.tf_subnet_1.id
  route_table_id = aws_route_table.tf_route_table.id
}

resource "aws_route_table_association" "tf_subnet_2_assoc" {
  subnet_id      = aws_subnet.tf_subnet_2.id
  route_table_id = aws_route_table.tf_route_table.id
}

# Create two public subnets
resource "aws_subnet" "tf_subnet_1" {
  vpc_id                  = aws_vpc.tf_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "tf-subnet-1"
  }
}

resource "aws_subnet" "tf_subnet_2" {
  vpc_id                  = aws_vpc.tf_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"

  tags = {
    Name = "tf-subnet-2"
  }
}

# Create an IAM role for Elastic Beanstalk
resource "aws_iam_role" "role-elb" {
  name = "role-elb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
  role       = aws_iam_role.role-elb.name
}

resource "aws_iam_role_policy_attachment" "beanstalk_web_tier" {
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
  role       = aws_iam_role.role-elb.name
}

resource "aws_iam_role_policy_attachment" "rds_data_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
  role       = aws_iam_role.role-elb.name
}


# Create an IAM instance profile
resource "aws_iam_instance_profile" "tf-ellb" {
  name = "role-elb-role"

  role = aws_iam_role.role-elb.name
}

# Create an Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "tf-test" {
  name        = "test-app"
  description = "Testing tf-elb"
}


# Create an Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "tf-test-env" {
  name                = "test-env"
  application         = aws_elastic_beanstalk_application.tf-test.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.2.0 running Node.js 20"
  tier                = "WebServer"


  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.tf-ellb.name  
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCID"
    value     = aws_vpc.tf_vpc.id
  }



  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.tf_subnet_1.id, aws_subnet.tf_subnet_2.id])
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "public"
  }
  # Enable database settings
  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBInstanceClass"
    value     = "db.t3.small"  # Updated instance class
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBEngine"
    value     = "postgres"
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBEngineVersion"
    value     = "16.3"  # Updated engine version
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBAllocatedStorage"
    value     = "15"  # Updated storage size
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBName"
    value     = "mydb"
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBUser"
    value     = "salil"  # Updated username
  }

  setting {
    namespace = "aws:rds:dbinstance"
    name      = "DBPassword"
    value     = var.db_password  # Ensure this variable is defined
  }
}

output "url" {
  value = aws_elastic_beanstalk_environment.tf-test-env.endpoint_url
}