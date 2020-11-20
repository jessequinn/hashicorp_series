job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "server-1"
  }

  group "traefik" {
    count = 1

    task "traefik" {
      env {
        DO_AUTH_TOKEN = "xxxx"
      }

      driver = "docker"

      config {
        image        = "traefik:v2.3"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/acme.json:/acme.json",
          "local/dyn/:/dyn/",
        ]
      }

      template {
        data = <<EOF
{
  "myresolver": {
    "Account": {
      "Email": "me@jessequinn.info",
      "Registration": {
        "body": {
          "status": "valid",
          "contact": [
            "mailto:me@jessequinn.info"
          ]
        },
        "uri": "https://acme-v02.api.letsencrypt.org/acme/acct/xxxx"
      },
      "PrivateKey": "xxxx",
      "KeyType": "4096"
    },
    "Certificates": [
      {
        "domain": {
          "main": "jessequinn.info"
        },
        "certificate": "xxxx",
        "key": "xxxx",
        "Store": "default"
      },
      {
        "domain": {
          "main": "scidoc.dev"
        },
        "certificate": "xxxx",
        "key": "xxxx",
        "Store": "default"
      },
      {
        "domain": {
          "main": "*.jessequinn.info"
        },
        "certificate": "xxxx",
        "key": "xxxx",
        "Store": "default"
      },
      {
        "domain": {
          "main": "*.scidoc.dev"
        },
        "certificate": "xxxx",
        "key": "xxxx",
        "Store": "default"
      }
    ]
  }
}
EOF

        destination = "local/acme.json"
        perms = "600"
      }

      template {
        data = <<EOF
# Global redirection: http to https
[http.routers.http-catchall]
  rule = "HostRegexp(`{host:(www\\.)?.+}`)"
  entryPoints = ["web"]
  middlewares = ["wwwtohttps"]
  service = "noop"

# Global redirection: https (www.) to https
[http.routers.wwwsecure-catchall]
  rule = "HostRegexp(`{host:(www\\.).+}`)"
  entryPoints = ["websecure"]
  middlewares = ["wwwtohttps"]
  service = "noop"
  [http.routers.wwwsecure-catchall.tls]

# middleware: http(s)://(www.) to  https://
[http.middlewares.wwwtohttps.redirectregex]
  regex = "^https?://(?:www\\.)?(.+)"
  replacement = "https://${1}"
  permanent = true

# NOOP service
[http.services.noop]
  [[http.services.noop.loadBalancer.servers]]
    url = "http://192.168.0.1:666"
EOF

        destination = "local/dyn/global_redirection.toml"
      }

      template {
        data = <<EOF
[entryPoints]
  [entryPoints.web]
    address = ":80"

    [entryPoints.web.http]
      [entryPoints.web.http.redirections]
        [entryPoints.web.http.redirections.entryPoint]
          to = "websecure"
          scheme = "https"

  [entryPoints.websecure]
    address = ":443"

  [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

[providers.file]
  directory = "dyn/"

# Enable ACME (Let's Encrypt): automatic SSL.
[certificatesResolvers.myresolver.acme]
  email = "me@jessequinn.info"
  storage = "acme.json"

  [certificatesResolvers.myresolver.acme.dnsChallenge]
    provider = "digitalocean"
    delayBeforeCheck = 0

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "127.0.0.1:8500"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 300
        memory = 200

        network {
          mbits = 10

          port "http" {
            static = 80
          }

          port "https" {
            static = 443
          }

          port "api" {
            static = 8081
          }
        }
      }

      service {
        name = "traefik"

        tags = [
//          "traefik.enable=true",
//          # Global redirection: http to https
//          "traefik.http.routers.http-catchall.rule=HostRegexp(`{host:(www\\.)?.+}`)",
//          "traefik.http.routers.http-catchall.entrypoints=web",
//          "traefik.http.routers.http-catchall.middlewares=wwwtohttps",
//          # Global redirection: https (www.) to https
//          "traefik.http.routers.wwwsecure-catchall.rule=HostRegexp(`{host:(www\\.).+}`)",
//          "traefik.http.routers.wwwsecure-catchall.entrypoints=websecure",
//          "traefik.http.routers.wwwsecure-catchall.tls=true",
//          "traefik.http.routers.wwwsecure-catchall.middlewares=wwwtohttps",
//          # middleware: http(s)://(www.) to https://
//          "traefik.http.middlewares.wwwtohttps.redirectregex.regex=^https?://(?:www\\.)?(.+)",
//          "traefik.http.middlewares.wwwtohttps.redirectregex.replacement=https://$${1}",
//          "traefik.http.middlewares.wwwtohttps.redirectregex.permanent=true",
          "traefik"
        ]

        check {
          name     = "alive"
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
