provider "aws" {
  region = "eu-west-1"
}

# Variables normalement dans un autre fichier (variables.tf) mais pour faire simple.... ca marche aussi !!!
variable "env" {
  type    = string
  default = "dev"
}


# On recupere les ressources reseau
## VPC
data "aws_vpc" "selected" {
  tags = {
    Name = "${var.env}-vpc"
  }
}

## Subnets
data "aws_subnet" "subnet-public-1" {
  tags = {
    Name = "${var.env}-subnet-public-1"
  }
}

data "aws_subnet" "subnet-public-2" {
  tags = {
    Name = "${var.env}-subnet-public-2"
  }
}

data "aws_subnet" "subnet-public-3" {
  tags = {
    Name = "${var.env}-subnet-public-3"
  }
}

data "aws_subnet" "subnet-private-1" {
  tags = {
    Name = "${var.env}-subnet-private-1"
  }
}

data "aws_subnet" "subnet-private-2" {
  tags = {
    Name = "${var.env}-subnet-private-2"
  }
}

data "aws_subnet" "subnet-private-3" {
  tags = {
    Name = "${var.env}-subnet-private-3"
  }
}

# data "aws_security_group" "web-sg-elb" {
#   name = "allow_web"
# }

## AZ zones de disponibilités dans la région
data "aws_availability_zones" "all" {}

########################################################################
# Security Groups

## ASG
resource "aws_security_group" "web-sg-asg" {
  name   = "${var.env}-sg-asg"
  vpc_id = data.aws_vpc.selected.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 443
    protocol        = "tcp"
    to_port         = 443
    security_groups = [aws_security_group.web-sg-elb.id] # on authorise en entrée de l'ASG que le flux venant de l'ELB
  }
  lifecycle {
    create_before_destroy = true
  }
}
## retrieve RDS SG and change rule to authorize previous
## ELB
resource "aws_security_group" "web-sg-elb" {
  name   = "${var.env}-sg-elb"
  vpc_id = data.aws_vpc.selected.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]   # Normalement Ouvert sur le web sauf dans le cas d'un site web Privé(Exemple Intranet ou nous qui ne voulons pas exposer le site)
  }
  lifecycle {
    create_before_destroy = true
  }
}

## RDS
resource "aws_security_group" "web-sg-rds" {
  name   = "${var.env}-sg-rds"
  vpc_id = data.aws_vpc.selected.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 3306
    protocol        = "tcp"
    to_port         = 3306
    security_groups = [aws_security_group.web-sg-asg.id]
  }
  lifecycle {
    create_before_destroy = true
  }
}
###############################################
## DB INSTANCE
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [data.aws_subnet.subnet-private-1.id, data.aws_subnet.subnet-private-2.id, data.aws_subnet.subnet-private-3.id] # TODO quel subnet mettre 🤔

  tags = {
    Name = "DB subnet group for symfony"
  }
}

resource "aws_db_instance" "db_instance" {
  allocated_storage    = 20
  storage_type         = "gp2" #basic default
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "dbforsymfony"
  username             = "admin"
  password             = "password" # TODO cacher mdp
  backup_retention_period = 0
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.web-sg-rds.id]

  tags = {
    Name = "dbforsymfony"
  }
}