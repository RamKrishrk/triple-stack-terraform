# Traffic flow: Internet -> web ALB -> web -> app ALB -> app -> DB

resource "aws_security_group" "web_alb" {
  name_prefix = "${local.name}-web-alb-"
  description = "Public web load balancer"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-web-alb-sg" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "web" {
  name_prefix = "${local.name}-web-"
  description = "Web tier instances"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-web-sg" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "app_alb" {
  name_prefix = "${local.name}-app-alb-"
  description = "Internal app load balancer"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-app-alb-sg" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-"
  description = "App tier instances"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-app-sg" }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "Database tier"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-db-sg" }

  lifecycle { create_before_destroy = true }
}

# ---------- Ingress ----------
resource "aws_vpc_security_group_ingress_rule" "web_alb_http" {
  for_each          = toset(var.allowed_http_cidrs)
  security_group_id = aws_security_group.web_alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from allowed CIDR"
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.web_alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "HTTP from web ALB"
}

resource "aws_vpc_security_group_ingress_rule" "app_alb_from_web" {
  security_group_id            = aws_security_group.app_alb.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "HTTP from web tier"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.app_alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "App port from app ALB"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "MySQL from app tier"
}

# ---------- Egress ----------
resource "aws_vpc_security_group_egress_rule" "web_alb_to_web" {
  security_group_id            = aws_security_group.web_alb.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound via NAT (packages, SSM, app ALB)"
}

resource "aws_vpc_security_group_egress_rule" "app_alb_to_app" {
  security_group_id            = aws_security_group.app_alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Outbound via NAT (packages, SSM, DB)"
}
