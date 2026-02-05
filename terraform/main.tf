terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

resource "kubernetes_namespace" "assignment" {
  metadata {
    name = "assignment-4"
  }
}

resource "kubernetes_secret" "jwt_secret" {
  metadata {
    name      = "jwt-secret"
    namespace = kubernetes_namespace.assignment.metadata[0].name
  }

  data = {
    JWT_SECRET = "super-secret-key-from-terraform"
  }
}
