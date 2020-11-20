job "jessequinn" {
  datacenters = ["dc1"]
  name = "jessequinn"

  update {
    max_parallel     = 1
    min_healthy_time = "30s"
    healthy_deadline = "5m"
  }

  group "jessequinn" {
    count = 2

    task "jessequinn" {
      env {
        PORT = 3000
      }

      driver = "docker"

      config {
        image = "xxxx"
        network_mode = "host"
        port_map = {
          http = 3000
        }
      }

      service {
        name = "jessequinn"
//        tags = ["urlprefix-jessequinn.info/", "urlprefix-www.jessequinn.info/", "jessequinn"]
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jessequinn.rule=Host(`jessequinn.info`)",
          "traefik.http.routers.jessequinn.entrypoints=websecure",
          "traefik.http.routers.jessequinn.service=jessequinn",
          "traefik.http.services.jessequinn.loadbalancer.server.port=3000",
          "traefik.http.routers.jessequinn.tls=true",
          "traefik.http.routers.jessequinn.tls.certresolver=myresolver",
          "traefik.http.routers.jessequinn.tls.domains[0].main=jessequinn.info",
          "traefik.http.routers.jessequinn.tls.domains[0].sans=*.jessequinn.info",
          "jessequinn"
        ]
        port = "http"

        check {
          type = "http"
          path = "/"
          interval = "2s"
          timeout = "2s"
        }
      }

      resources {
        cpu    = 500
        memory = 500

        network {
          mbits = 10

          port "http" {
            static = 3000
          }
        }
      }
    }
  }
}
