# Conch Docker

A minimal Docker image for [Conch](https://github.com/newo-ether/conch) — a lightweight, zero-dependency shell execution server with SSE streaming and end-to-end encryption.

## Configuration (environment variables)

| Variable                | Default          | Description                                                        |
| ----------------------- | ---------------- | ------------------------------------------------------------------ |
| `CONCH_API_KEY`         | _(required)_     | Pre-shared key for HMAC signing + key exchange.[^1]                |
| `CONCH_HOST`            | `0.0.0.0`        | Listen address.                                                    |
| `CONCH_PORT`            | `14216`          | HTTP listen port.                                                  |
| `CONCH_TIMEOUT`         | `30`             | Default command timeout (seconds).                                 |
| `CONCH_MAX_TIMEOUT`     | `1800`           | Max allowed timeout (seconds).                                     |
| `CONCH_ALLOW_NO_AUTH`   | `false`          | Start without an API key (disables encryption/signing — dev only). |
| `CONCH_JOB_DIR`         | `/var/lib/conch` | Directory for durable background-job snapshots.                    |
| `CONCH_TRUSTED_PROXIES` | _(empty)_        | Comma-separated IPs/CIDRs allowed to send `X-Forwarded-For`.       |

See the [upstream README](https://github.com/newo-ether/conch#configuration) for the full list.

## Build

```sh
docker build -t conch:latest .
```

Build a specific release:

```sh
docker build --build-arg CONCH_VERSION=v1.0.17 -t conch:v1.0.17 .
```

Build for a specific architecture (e.g. on an x86 host targeting ARM):

```sh
docker build --platform linux/arm64 -t conch:arm64 .
```

## Run with `docker`

```sh
docker run -d \
  --name conch \
  -p 14216:14216 \
  -e CONCH_API_KEY="your-secret-key" \
  -v conch-jobs:/var/lib/conch \
  --restart unless-stopped \
  conch:latest
```

Verify it's up:

```sh
curl -s http://localhost:14216/health
# {"status":"ok", ...}
```

To publish on a different host port, change the left side of `-p`, e.g. `-p 8080:14216`.

## Run with Docker Compose

```sh
cp .env.example .env
# edit .env and set CONCH_API_KEY
docker compose up -d --build
```

Then check health:

```sh
curl -s http://localhost:14216/health
```

Stop and remove:

```sh
docker compose down
```

The `conch-jobs` named volume persists durable background-job snapshots across rebuilds.

## Notes

- **Security:** Conch exposes a remote shell. Keep `CONCH_API_KEY` strong and only expose the port to networks you trust. Do not set `CONCH_ALLOW_NO_AUTH=true` on an untrusted network.
- **Upgrading:** bump `CONCH_VERSION` in the `Dockerfile` (or pass `--build-arg CONCH_VERSION=...`) and rebuild.
- **MCP bridge:** the `conch-mcp` binary is a separate stdio bridge for Claude Desktop and is not included in this image. Run it on the client machine and point it at this server with `CONCH_SERVER_URL` and `CONCH_API_KEY`.

[^1]: Conch **refuses to start without an API key** unless you set `CONCH_ALLOW_NO_AUTH=true`. Always supply `CONCH_API_KEY`.
