resource "aws_lb" "main" {
  name            = "${local.default_name}"
  subnets         = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb.id}"]
  ip_address_type = "dualstack"
  tags            = "${local.default_tags}"
}

resource "aws_lb_target_group" "vault" {
  name        = "${local.default_name}"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = "${aws_vpc.main.id}"
  target_type = "ip"
  tags        = "${local.default_tags}"
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = "${aws_lb.main.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.vault.arn}"
  }
}

resource "aws_security_group" "lb" {
  name        = "${local.default_name}-lb"
  description = "controls access to the ${local.default_name} ALB"
  vpc_id      = "${aws_vpc.main.id}"
  tags        = "${local.default_tags}"

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
