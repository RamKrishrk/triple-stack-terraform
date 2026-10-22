data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- IAM (SSM Session Manager, no SSH needed) ----------
resource "aws_iam_role" "instance" {
  name_prefix = "${local.name}-ec2-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${local.name}-ec2-"
  role        = aws_iam_role.instance.name
}

# =====================================================================
# TIER 1 - WEB (public ALB -> nginx reverse proxy in private subnets)
# =====================================================================
resource "aws_lb" "web" {
  name               = "${local.name}-web-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.web_alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${local.name}-web-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.web_instance_type

  iam_instance_profile { name = aws_iam_instance_profile.instance.name }
  vpc_security_group_ids = [aws_security_group.web.id]

  metadata_options {
    http_tokens = "required"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y nginx
    cat > /etc/nginx/conf.d/app.conf <<'CONF'
    server {
      listen 80 default_server;
      location = /healthz { return 200 'ok'; add_header Content-Type text/plain; }
      location / {
        proxy_pass http://${aws_lb.app.dns_name};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
      }
    }
    CONF
    rm -f /etc/nginx/conf.d/default.conf
    systemctl enable --now nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-web", Tier = "web" }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "web" {
  name                = "${local.name}-web-asg"
  min_size            = var.web_asg_min
  desired_capacity    = var.web_asg_desired
  max_size            = var.web_asg_max
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }
}

# =====================================================================
# TIER 2 - APP (internal ALB -> python service in private subnets)
# =====================================================================
resource "aws_lb" "app" {
  name               = "${local.name}-app-alb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.app_alb.id]
  subnets            = aws_subnet.private[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "${local.name}-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-app-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.app_instance_type

  iam_instance_profile { name = aws_iam_instance_profile.instance.name }
  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens = "required"
  }

  # Placeholder app: replace with your real service / container.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    mkdir -p /opt/app
    cat > /opt/app/server.py <<'PY'
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import socket

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                body = b"ok"
            else:
                body = f"app tier on {socket.gethostname()} | db endpoint: ${aws_db_instance.main.address}\n".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body)

    HTTPServer(("0.0.0.0", ${var.app_port}), H).serve_forever()
    PY
    cat > /etc/systemd/system/app.service <<'UNIT'
    [Unit]
    Description=Sample app tier
    After=network.target
    [Service]
    ExecStart=/usr/bin/python3 /opt/app/server.py
    Restart=always
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now app
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app", Tier = "app" }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "app" {
  name                = "${local.name}-app-asg"
  min_size            = var.app_asg_min
  desired_capacity    = var.app_asg_desired
  max_size            = var.app_asg_max
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }
}
