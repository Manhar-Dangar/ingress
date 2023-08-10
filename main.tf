# Kubernetes Provider Configuration
provider "kubernetes" {
  config_path = "~/.kube/config" # Update this with your kubeconfig path
}

# Local Variables
locals {
  application_data = jsondecode(file("../applications.json")) # Load application data from JSON file
}

# Kubernetes Deployment Resource
resource "kubernetes_deployment" "app" {
  for_each = { for app in local.application_data.applications : app.name => app } # Iterate over applications

  metadata {
    name = each.value.name
    labels = {
      app = each.value.name
    }
  }

  spec {
    replicas = each.value.replicas # Set number of replicas

    selector {
      match_labels = {
        app = each.value.name
      }
    }

    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }

      spec {
        container {
          name  = each.value.name
          image = each.value.image
          args  = each.value.args  # Use the updated 'args' field directly as an array of strings
          port {
            container_port = each.value.port # Container port configuration
          }
        }
      }
    }
  }
}


# Kubernetes Service Resource
resource "kubernetes_service" "app" {
  for_each = { for app in local.application_data.applications : app.name => app } # Iterate over applications

  metadata {
    name = each.value.name
  }
  
  spec {
    selector = {
      app = each.value.name
    }

    port {
      protocol    = "TCP"
      port        = each.value.port
      target_port = each.value.port # Target port configuration
    }
  }
}


# Kubernetes Ingress Resource (v1)
resource "kubernetes_ingress_v1" "app" {
  for_each = { for app in local.application_data.applications : app.name => app } # Iterate over applications

  metadata {
    name = "app-ingress-${each.value.name}"

    annotations = merge(
      {
        "kubernetes.io/ingress.class" = "nginx",
        "kubernetes.io/elb.port"     = "80" # ELB port configuration
      },
      contains(keys(each.value), "annotations") ? each.value.annotations : {} # Merge additional annotations if present
    )
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      http {
        path {
          path = "/"
          backend {
            service {
              name = each.value.name
              port {
                number = each.value.port # Backend service port configuration
              }
            }
          }
        }
      }
    }
  }
}
