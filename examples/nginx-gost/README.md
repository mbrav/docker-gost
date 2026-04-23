# Nginx with GOST TLS example

An end-to-end example of an nginx server that serves HTML content secured with
a self-signed GOST 2012 certificate, plus a cleartext proxy so a standard
browser can reach the page without needing native GOST cipher support.

## Architecture

```
Browser / curl
    │  HTTP :8080
    ▼
┌─────────┐    GOST TLS :443    ┌─────────┐
│  proxy  │ ──────────────────► │  server │
│ (nginx) │                     │ (nginx) │
└─────────┘                     └─────────┘
mbrav/docker-gost:bookworm-nginx (both services)
```

- **server** — nginx listening on port 443 with GOST TLS. Serves `html/index.html`.
  A self-signed GOST 2012 certificate is generated automatically on first start
  and stored in a named Docker volume (`certs`).
- **proxy** — nginx listening on port 8080 (plain HTTP). Connects to `server:443`
  over GOST TLS and re-serves the content in cleartext for regular clients.

## Running

```shell
docker compose up
```

Then open <http://localhost:8080> in a browser.

## Direct GOST TLS access

To connect directly to the server over GOST TLS (requires a GOST-capable
OpenSSL, e.g. inside the container):

```shell
docker compose exec server openssl s_client \
  -connect localhost:443 \
  -cipher GOST2012-KUZNYECHIK-KUZNYECHIKOMAC \
  </dev/null
```

## File layout

```
examples/nginx-gost/
├── docker-compose.yml          # service definitions
├── entrypoint.sh               # cert generation + nginx start for the server
├── nginx/
│   ├── server.nginx.conf       # GOST TLS server config
│   └── proxy.nginx.conf        # cleartext reverse-proxy config
└── html/
    └── index.html              # page served by the server
```

## Certificate details

The entrypoint generates a GOST 2012 self-signed certificate on first start:

| Field     | Value                         |
|-----------|-------------------------------|
| Algorithm | `gost2012_256`                |
| Paramset  | `A`                           |
| Validity  | 365 days                      |
| Subject   | `CN=localhost, O=docker-gost` |

To regenerate the certificate, remove the Docker volume:

```shell
docker compose down -v
docker compose up
```
