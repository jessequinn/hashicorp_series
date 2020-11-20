job "scidoc" {
  datacenters = ["dc1"]
  name = "scidoc"

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
  }

  group "scidoc" {
    count = 2

    task "scidoc" {
      env {
        PORT = 4000
      }

      driver = "docker"

      config {
        image = "xxxx"
        network_mode = "host"
        port_map = {
          http = 4000
        }
      }

      service {
        name = "scidoc"
//        tags = ["urlprefix-scidoc.dev/", "urlprefix-www.scidoc.dev/", "scidoc"]
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.scidoc.rule=Host(`scidoc.dev`)",
          "traefik.http.routers.scidoc.entrypoints=websecure",
          "traefik.http.routers.scidoc.service=scidoc",
          "traefik.http.services.scidoc.loadbalancer.server.port=4000",
          "traefik.http.routers.scidoc.tls=true",
          "traefik.http.routers.scidoc.tls.certresolver=myresolver",
          "traefik.http.routers.scidoc.tls.domains[0].main=scidoc.dev",
          "traefik.http.routers.scidoc.tls.domains[0].sans=*.scidoc.dev",
          "scidoc"
        ]
        port = "http"

        check {
          type     = "http"
          path     = "/"
          interval = "2s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 400
        memory = 300

        network {
          mbits = 10

          port "http" {
            static = 4000
          }
        }
      }
    }
  }
}
