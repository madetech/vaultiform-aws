resource "aws_ecs_cluster" "vault" {
  name = "${local.default_name}"
  tags = "${local.default_tags}"
}

resource "aws_ecs_service" "vault" {
  name            = "${local.default_name}"
  cluster         = "${aws_ecs_cluster.vault.id}"
  task_definition = "${aws_ecs_task_definition.vault.arn}"
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = ["${aws_subnet.private.*.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_lb_target_group.vault.arn}"
    container_name   = "vault"
    container_port   = 443
  }

  depends_on = [
    "aws_lb_listener.main",
  ]
}

resource "aws_ecs_task_definition" "vault" {
  family                   = "${local.default_name}"
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  tags                     = "${local.default_tags}"

  container_definitions = <<DEFINITION
[
  {
    "name": "vault",
    "essential": true,
    "image": "vault",
    "cpu": 256,
    "memory": 512,
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 443,
        "hostPort": 443
      }
    ]
  }
]
DEFINITION
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.default_name}-ecs-task"
  description = "Allow ${local.default_name} to talk to the ALB"
  vpc_id      = "${aws_vpc.main.id}"
  tags        = "${local.default_tags}"

  ingress {
    protocol        = "tcp"
    from_port       = 443
    to_port         = 443
    security_groups = ["${aws_security_group.lb.id}"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
