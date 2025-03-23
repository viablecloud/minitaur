# Create a namespace for a standalong nginx server
resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}

# Create the vanilla nginx deployment
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Create a service for nginx
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

//Create a standalone Jenkins server deployment to demonstrate TLS via ingress.

# Create namespace for Jenkins
resource "kubernetes_namespace" "nginxssl" {
  metadata {
    name = "jenkins"
  }
}

# Create the vanilla nginx deployment to "mock" jenkins
resource "kubernetes_deployment" "nginxssl" {
  metadata {
    name      = "nginxssl"
    namespace = kubernetes_namespace.nginxssl.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginxssl"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginxssl"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginxssl"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Create a service for jenkins
resource "kubernetes_service" "nginxssl" {
  metadata {
    name      = "nginxssl-service"
    namespace = kubernetes_namespace.nginxssl.metadata[0].name
  }

  spec {
    selector = {
      app = "nginxssl"
    }

    port {
      port        = 80 //port connected to by the ingress
      target_port = 80
    }

    type = "ClusterIP"
  }
}