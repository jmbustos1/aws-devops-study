provider "aws" {
  region = "us-east-1"
}

# Reemplaza estos valores con los IDs de tu VPC y subnets predeterminadas
variable "default_vpc_id" {
  description = "ID de la VPC predeterminada"
  type        = string
  default     = ""  # ID de tu VPC
}

variable "default_subnets_ids" {
  description = "IDs de las subnets predeterminadas"
  type        = list(string)
  default     = ["", ""]  # IDs de tus subnets
}

# Crear un rol de IAM para CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "CodeDeployServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# Agregar políticas a ese rol de IAM
resource "aws_iam_role_policy" "codedeploy_role_policy" {
  name = "CodeDeployPolicy"
  role = aws_iam_role.codedeploy_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:DeleteLifecycleHook",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:PutLifecycleHook",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:RecordLifecycleActionHeartbeat"  # Agrega este permiso
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Crear un balanceador de carga
resource "aws_lb" "example_lb" {
  name = "example-lb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.lb_sg.id]
  subnets = var.default_subnets_ids  # Usar las subnets predeterminadas
}

# Crear un grupo de destino para el balanceador de carga
resource "aws_lb_target_group" "example_tg" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.default_vpc_id  # Usar la VPC predeterminada
}

# Auto Scaling Group para instancias EC2
resource "aws_autoscaling_group" "example_asg" {
  launch_template {
    id      = aws_launch_template.example_lt.id
    version = "$Latest"
  }
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = var.default_subnets_ids  # Usar las subnets predeterminadas
  target_group_arns    = [aws_lb_target_group.example_tg.arn]
  health_check_type    = "ELB"
}

# Crear la configuración de lanzamiento de EC2
resource "aws_launch_template" "example_lt" {
  name          = "example-lt"
  image_id      = "ami-005fc0f236362e99f" # Cambia esta AMI según tu región
  instance_type = "t2.micro"

  # Agregar la interfaz de red con los grupos de seguridad
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.ec2_sg.id]  # Aquí se colocan los grupos de seguridad
  }
}

# Seguridad del balanceador de carga
resource "aws_security_group" "lb_sg" {
  name = "lb_sg"
  description = "Security group for load balancer"
  vpc_id = var.default_vpc_id  # Usar la VPC predeterminada

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Seguridad de las instancias EC2
resource "aws_security_group" "ec2_sg" {
  name = "ec2_sg"
  description = "Security group for EC2 instances"
  vpc_id = var.default_vpc_id  # Usar la VPC predeterminada

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear la aplicación en CodeDeploy
resource "aws_codedeploy_app" "example" {
  name = "example-app"
  compute_platform = "Server"
}

# Crear el grupo de despliegue en CodeDeploy
resource "aws_codedeploy_deployment_group" "example" {
  app_name               = aws_codedeploy_app.example.name
  deployment_group_name  = "example-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  
  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }


    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"  # Opción para continuar el despliegue si no hay acción en el tiempo límite
      # wait_time_in_minutes = 10                  # El tiempo de espera antes de cambiar el tráfico
    }
  }



  autoscaling_groups = [aws_autoscaling_group.example_asg.name]

  load_balancer_info {
    elb_info {
      name = aws_lb.example_lb.name
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
}