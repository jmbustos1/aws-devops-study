provider "aws" {
  region = "" # Cambia la región si es necesario
}

# Variables para definir la configuración
variable "vpc_id" {
  description = "ID de la VPC para los recursos"
  type        = string
  default     = ""
}

variable "public_subnets" {
  description = "Lista de subnets públicas"
  type        = list(string)
  default     = ["", ""]
}

variable "aws_account_id" {
  description = "ID de la cuenta AWS"
  type        = string
  default     = ""
}

variable "aws_account_region" {
  description = "Región AWS para desplegar"
  type        = string
  default     = ""
}

variable "elb_sg_ingress_ports" {
  type    = list(number)
  default = [80, 443, 8080]
}


# ===== INSTANCIAS EC2 PARA LOS GRUPOS =====
# ROL
resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "EC2_CodeDeploy_Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Service: "ec2.amazonaws.com"
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_ssm" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_agent" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "attach_admin_access" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_iam_instance_profile" "ec2_codedeploy_instance_profile" {
  name = "EC2_CodeDeploy_Instance_Profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}

## Instancias
resource "aws_security_group" "ec2_instance_sg" {
  vpc_id = var.vpc_id
  name   = "ec2-instance-sg"

  # Permitir tráfico HTTP y HTTPS desde el Load Balancer
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    #security_groups = [aws_security_group.application_elb_sg.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    #security_groups = [aws_security_group.application_elb_sg.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir acceso SSH desde tu IP (modifica "X.X.X.X/32" con tu IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regla de salida para permitir que las instancias hagan conexiones salientes (por ejemplo, para instalar paquetes)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

    # # Actualizar la lista de paquetes
    # sudo apt-get update -y

    # # Instalar Nginx
    # sudo apt-get install -y nginx

    # # Iniciar y habilitar el servicio Nginx
    # sudo systemctl start nginx
    # sudo systemctl enable nginx
variable "ec2_user_data_script" {
  description = "User data script for setting up Nginx and enabling port 80"
  default = <<-EOF
    #!/bin/bash -e

    # Instalar Docker
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update -y
    sudo apt-get install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker

    # Instalar CodeDeployAgent
    sudo apt-get update -y
    sudo apt-get install ruby -y
    cd /home/ubuntu
    wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
    chmod +x ./install
    sudo ./install auto
    sudo service codedeploy-agent start

    # Descargar e instalar el agente ECS
    curl -O https://s3.us-west-2.amazonaws.com/amazon-ecs-agent-us-west-2/amazon-ecs-init-latest.amd64.deb
    sudo dpkg -i amazon-ecs-init-latest.amd64.deb
    
    # Configurar para unirse al cluster ECS específico
    echo "ECS_CLUSTER=application-cluster" | sudo tee /etc/ecs/ecs.config

    # Iniciar el servicio ECS
    sudo systemctl enable ecs
    sudo systemctl start ecs
  EOF
}

resource "aws_instance" "ec2_green_1" {
  ami           = "ami-005fc0f236362e99f"
  instance_type = "t3.medium"
  subnet_id     = var.public_subnets[0]
  security_groups = [aws_security_group.ec2_instance_sg.id]
  user_data     = var.ec2_user_data_script
  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy_instance_profile.name

  tags = {
    Name = "Green-Instance-1"
  }
}

resource "aws_instance" "ec2_green_2" {
  ami           = "ami-005fc0f236362e99f"
  instance_type = "t3.medium"
  subnet_id     = var.public_subnets[1]
  security_groups = [aws_security_group.ec2_instance_sg.id]
  user_data     = var.ec2_user_data_script
  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy_instance_profile.name

  tags = {
    Name = "Green-Instance-2"
  }
}

resource "aws_instance" "ec2_blue_1" {
  ami           = "ami-005fc0f236362e99f"
  instance_type = "t3.medium"
  subnet_id     = var.public_subnets[0]
  security_groups = [aws_security_group.ec2_instance_sg.id]
  user_data     = var.ec2_user_data_script
  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy_instance_profile.name

  tags = {
    Name = "Blue-Instance-1"
  }
}

resource "aws_instance" "ec2_blue_2" {
  ami           = "ami-005fc0f236362e99f"
  instance_type = "t3.medium"
  subnet_id     = var.public_subnets[1]
  security_groups = [aws_security_group.ec2_instance_sg.id]
  user_data     = var.ec2_user_data_script
  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy_instance_profile.name

  tags = {
    Name = "Blue-Instance-2"
  }
}


# Security Groups for ALB
resource "aws_security_group" "application_elb_sg" {
  vpc_id = var.vpc_id
  name   = "application_elb_sg"
    # Regla de salida para permitir que el LB se comunique con las instancias en el puerto 80
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # O puedes restringir a las IPs de tus subredes si es más seguro
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
variable "certificate_arn" {
  description = "The ARN of the SSL/TLS certificate for HTTPS. Leave empty if not using HTTPS."
  type        = string
  default     = ""
}
resource "aws_security_group_rule" "application_elb_sg_ingress" {
  count             = length(var.elb_sg_ingress_ports)
  type              = "ingress"
  from_port         = var.elb_sg_ingress_ports[count.index]
  to_port           = var.elb_sg_ingress_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.application_elb_sg.id
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "application-load-balancer"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  idle_timeout       = 60
  security_groups    = [aws_security_group.application_elb_sg.id]
}

# Target Groups for Blue/Green Deployment
locals {
  target_groups = ["blue", "green"]
}

resource "aws_lb_target_group" "tg" {
  count       = length(local.target_groups)
  name        = "tg-${element(local.target_groups, count.index)}"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  health_check {
    interval            = 20   # Hacer el check cada 60 segundos
    timeout             = 10   # Esperar hasta 10 segundos por una respuesta
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher = "200,301,302,404"
    path    = "/"
  }
}



resource "aws_lb_target_group_attachment" "green_target_1" {
  target_group_arn = aws_lb_target_group.tg[0].arn
  target_id        = aws_instance.ec2_green_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "green_target_2" {
  target_group_arn = aws_lb_target_group.tg[0].arn
  target_id        = aws_instance.ec2_green_2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "blue_target_1" {
  target_group_arn = aws_lb_target_group.tg[1].arn
  target_id        = aws_instance.ec2_blue_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "blue_target_2" {
  target_group_arn = aws_lb_target_group.tg[1].arn
  target_id        = aws_instance.ec2_blue_2.id
  port             = 80
}

# ALB Listeners
# resource "aws_alb_listener" "l_80" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }
resource "aws_alb_listener" "l_80" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
  depends_on = [aws_lb_target_group.tg]
}
resource "aws_alb_listener" "l_8080" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[1].arn
  }
}

resource "aws_alb_listener" "l_443" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn # Ingresa tu ARN de certificado SSL
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
  depends_on = [aws_lb_target_group.tg]

  lifecycle {
    ignore_changes = [default_action]
  }

  # Activar solo si hay un certificado ARN presente
  count = var.certificate_arn != "" ? 1 : 0
}
resource "aws_ecr_repository" "app_ecr_repo" {
  name         = "app-ecr-repository"
  force_delete = true
}
# ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "application-cluster"
}

resource "aws_ecs_service" "frontend" {
  name                               = "frontend"
  cluster                            = aws_ecs_cluster.app_cluster.id
  task_definition                    = aws_ecs_task_definition.frontend_task.arn
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 300
  launch_type                        = "EC2"
  scheduling_strategy                = "REPLICA"
  desired_count                      = 1


  force_new_deployment = true
  load_balancer {
    target_group_arn = aws_lb_target_group.tg[0].arn
    container_name   = "app" 
    container_port   = "80" # Application Port
  }
  deployment_controller {
    type = "CODE_DEPLOY"
  }


  # workaround for https://github.com/hashicorp/terraform/issues/12634
  depends_on = [aws_lb.app_lb]
  # we ignore task_definition changes as the revision changes on deploy
  # of a new version of the application
  # desired_count is ignored as it can change due to autoscaling policy
  lifecycle {
    ignore_changes = [task_definition, desired_count, load_balancer]
  }
}
# ECS Task Definition
resource "aws_ecs_task_definition" "frontend_task" {
  family                   = "frontend-task"
  container_definitions    = jsonencode([{
    name      = "app"
    image     = "${var.aws_account_id}.dkr.ecr.${var.aws_account_region}.amazonaws.com/app-ecr-repository:latest"
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80,
        protocol      = "tcp"
      }
    ]
  }])
  requires_compatibilities = ["EC2"]
  memory                   = 1800
  cpu                      = 512
  execution_role_arn       = aws_iam_role.app_task_role.arn
  network_mode = "host" ## clave
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "app_task_role" {
  name = "app-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}


# CodeDeploy Application and Deployment Group
resource "aws_codedeploy_app" "frontend" {
  compute_platform = "ECS"
  name             = "frontend-deploy"
}
# IAM Role Policy for CodeDeploy
data "aws_iam_policy_document" "codedeploy" {
  statement {
    sid    = "AllowLoadBalancingAndECSModifications"
    effect = "Allow"

    actions = [
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:DescribeServices",
      "ecs:UpdateServicePrimaryTaskSet",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyRule",
      "s3:GetObject"
    ]

    resources = ["*"]
  }

    # Permiso adicional específico para ECS
  statement {
    sid    = "AllowECSDescribe"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:ListClusters",
      "ecs:ListServices"
    ]

    resources = ["*"]
  }
  statement {
    sid    = "AllowPassRole"
    effect = "Allow"

    actions = ["iam:PassRole"]

    resources = [
      aws_iam_role.app_task_role.arn
    ]
  }

  statement {
    sid    = "DeployService"
    effect = "Allow"

    actions = ["ecs:DescribeServices",
      "codedeploy:GetDeploymentGroup",
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
    "codedeploy:RegisterApplicationRevision"]

    resources = [
      aws_ecs_service.frontend.id,
      aws_codedeploy_deployment_group.frontend.arn,
      "arn:aws:codedeploy:${var.aws_account_region}:${var.aws_account_id}:deploymentconfig:*",
      aws_codedeploy_app.frontend.arn
    ]
  }


}

resource "aws_iam_role_policy" "codedeploy" {
  role   = aws_iam_role.codedeploy.name
  policy = data.aws_iam_policy_document.codedeploy.json
}
resource "aws_iam_role_policy_attachment" "ECS_task_execution" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_full_access" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}
resource "aws_codedeploy_deployment_group" "frontend" {
  app_name               = aws_codedeploy_app.frontend.name
  deployment_group_name  = "frontend-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.app_cluster.name
    service_name = aws_ecs_service.frontend.name
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        # listener_arns = [length(aws_alb_listener.l_443) > 0 ? aws_alb_listener.l_443[0].arn : aws_alb_listener.l_80.arn]
        listener_arns = [aws_alb_listener.l_80.arn]
      }

      target_group {
        name = aws_lb_target_group.tg[0].name
      }

      target_group {
        name = aws_lb_target_group.tg[1].name
      }
    }
  }
}

data "aws_iam_policy_document" "assume_by_codedeploy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "codedeploy"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codedeploy.json
}



# ===== S3 Bucket para la Aplicación =====
resource "aws_s3_bucket" "snake_app_bucket" {
  bucket         = "snake-app-deployment-bucket"
  force_destroy  = true
  tags = {
    Name = "snake-app-deployment"
  }
}