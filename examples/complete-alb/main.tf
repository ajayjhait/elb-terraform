provider "aws" {
  region = "us-east-1"
  
}

locals {
  domain_name = "terraform-aws-modules.modules.tf"
}

##################################################################
# Data sources to get VPC and subnets
##################################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "random_pet" "this" {
  length = 2
}

/*data "aws_route53_zone" "this" {
  name = local.domain_name
}
*/
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = "alb-sg-${random_pet.this.id}"
  description = "Security group for example usage with ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

# module "log_bucket" {
#   source  = "terraform-aws-modules/s3-bucket/aws"
#   version = "~> 1.0"
#
#   bucket                         = "logs-${random_pet.this.id}"
#   acl                            = "log-delivery-write"
#   force_destroy                  = true
#   attach_elb_log_delivery_policy = true
# }

/*module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 2.0"

  domain_name = local.domain_name # trimsuffix(data.aws_route53_zone.this.name, ".") # Terraform >= 0.12.17
  zone_id     = data.aws_route53_zone.this.id
}
*/
##################################################################
# AWS Cognito User Pool
##################################################################
/* resource "aws_cognito_user_pool" "this" {
  name = "user-pool-${random_pet.this.id}"
}

resource "aws_cognito_user_pool_client" "this" {
  name                                 = "user-pool-client-${random_pet.this.id}"
  user_pool_id                         = aws_cognito_user_pool.this.id
  generate_secret                      = true
  allowed_oauth_flows                  = ["code", "implicit"]
  callback_urls                        = ["https://${local.domain_name}/callback"]
  allowed_oauth_scopes                 = ["email", "openid"]
  allowed_oauth_flows_user_pool_client = true
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = random_pet.this.id
  user_pool_id = aws_cognito_user_pool.this.id
}
*/
##################################################################
# Application Load Balancer
##################################################################
module "alb" {
  source = "../../"
  #source = "terraform-aws-modules/alb/aws"

 # name = "complete-alb-${random_pet.this.id}"
  name = "Testing"
  load_balancer_type = "application"
  
  vpc_id          = data.aws_vpc.default.id
  security_groups = [module.security_group.this_security_group_id]
  subnets         = data.aws_subnet_ids.all.ids

  #   # See notes in README (ref: https://github.com/terraform-providers/terraform-provider-aws/issues/7987)
  #   access_logs = {
  #     bucket = module.log_bucket.this_s3_bucket_id
  #   }

  http_tcp_listeners = [
    # Forward action is default, either when defined or undefined
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
      action_type        = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "Fixed message"
        status_code  = "503"
        }
    } 
  /* ,
    {
      port        = 81
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }, */
   /* {
      port        = 82
      protocol    = "HTTP"
      action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "Fixed message"
        status_code  = "200"
      }
    }, */
  ]
  
  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
     # priority                = 3
      actions = [{
        type         = "forward"
        target_group_index = 0
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["auditor.example.com"]
      }]
    },
    {
      http_tcp_listener_index = 0
     # priority                = 3
      actions = [{
        type         = "forward"
        target_group_index = 1
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["billdesk.example.com"]
      }]
    },
    {
      http_tcp_listener_index = 0
     # priority                = 3
      actions = [{
        type         = "forward"
        target_group_index = 2
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["lens.example.com"]
      }]
    },
    {
      http_tcp_listener_index = 0
     # priority                = 3
      actions = [{
        type         = "forward"
        target_group_index = 3
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["notification.example.com"]
      }]
    },
    {
      http_tcp_listener_index = 0
     # priority                = 3
      actions = [{
        type         = "forward"
        target_group_index = 4
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["scheduler.example.com"]
      }]
    },
    {
      http_tcp_listener_index = 0
     # priority                = 5
      actions = [{
        type         = "forward"
        target_group_index = 5
       # content_type = "/*"
       # status_code  = 200
       # message_body = "This is a fixed response"
      }]

      conditions = [{
        host_headers = ["frontend.example.com"]
      }]
    }
  ]
  target_groups = [
    {
      name = "cloudonomic-dev1-java-auditor"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/auditor/actuator/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    }, 
     {
      name = "cloudonomic-dev1-java-billdesk"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/billdesk/actuator/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    },
    {
      name = "cloudonomic-dev1-java-lens"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/lens/actuator/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    },
    {
      name = "cloudonomic-dev1-java-scheduler"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/scheduler/actuator/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    },
    {
      name = "cloudonomic-dev1-java-notificati"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/notification/actuator/health"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    },
    {
      name = "cloudonomic-dev1-java-frontend"
      #name_prefix          = "audit"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/cloudonomic-ecs-dev-node-frontend"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200"
      } 
   tags = {
        InstanceTargetGroupTag = "cloudonomic"
      }
    },
   ]
  
  tags = {
    Project = "Unknown"
  }
  lb_tags = {
    MyLoadBalancer = "foo"
  }
}

#########################
# LB will not be created
#########################
module "lb_disabled" {
  source = "../../"

  create_lb = false
}
