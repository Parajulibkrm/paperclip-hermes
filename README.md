# paperclip-hermes (Dokploy-ready)

A single Docker image that bundles:

- **[Paperclip](https://www.npmjs.com/package/paperclipai)** — the web UI (port 3100) for managing agent instances
- **[Hermes Agent](https://github.com/NousResearch/hermes-agent)** (Nous Research) — the underlying coding agent CLI
- **[Browser Harness](https://github.com/browser-use/browser-harness)** — registered as a Hermes skill so the agent can drive a real browser

Inspired by [`MinuteCode/paperclip-hermes`](https://github.com/MinuteCode/paperclip-hermes) (Paperclip+Hermes packaging) and [`maximilianhagerf/hermes-dokploy`](https://github.com/maximilianhagerf/hermes-dokploy) (Dokploy entrypoint pattern + browser-harness wiring).

## Deploy via Dokploy

1. Push this directory to a git repo Dokploy can read (or paste `docker-compose.yml` directly into a Compose project).
2. Create a **Compose** service in Dokploy pointing at the repo.
3. Set the env vars in the Dokploy UI (only the ones you actually use):

   | Variable | Purpose |
   |---|---|
   | `HERMES_MODEL` | e.g. `openrouter/free`, `anthropic/claude-sonnet-4.6`, `anthropic/claude-opus-4.7` |
   | `OPENROUTER_API_KEY` | required if `HERMES_MODEL` starts with `openrouter/` |
   | `ANTHROPIC_API_KEY` | required for `anthropic/...` models |
   | `OPENAI_API_KEY` / `GOOGLE_API_KEY` | for OpenAI/Google models |
   | `BROWSER_USE_API_KEY` | optional — Browser Use cloud Chromium |
   | `BROWSERBASE_API_KEY` + `BROWSERBASE_PROJECT_ID` | optional — BrowserBase cloud Chromium |
   | `IP_ADDRESS` | public hostname/IP Paperclip should accept (e.g. `paperclip.example.com`) |

4. Expose port `3100` (or, preferably, attach a Traefik domain in Dokploy and let it terminate TLS in front of port 3100).
5. Deploy. First boot runs `paperclipai onboard --yes` automatically.

## Using it

- **Web UI**: hit `http://<your-host>:3100/` (or your Traefik domain). All Paperclip features available.
- **Direct Hermes CLI**: SSH into the box and exec into the container:
  ```bash
  docker exec -it paperclip-hermes /usr/local/bin/entrypoint.sh hermes
  ```
  Or invoke any other command:
  ```bash
  docker exec -it paperclip-hermes bash
  ```

## Switching models

Three tiers, same as the upstream `hermes-dokploy` README:

- **One-off** — `docker exec -it paperclip-hermes /usr/local/bin/entrypoint.sh hermes --model anthropic/claude-haiku-4-5 ...`. Doesn't persist; entrypoint rewrites `.env` on every restart, but `model.default` only changes if `HERMES_MODEL` is set.
- **Semi-permanent** — change `HERMES_MODEL` in Dokploy's env UI, hit restart. Entrypoint patches `model.default` in `config.yaml` on next boot.
- **Permanent** — edit `/data/hermes/config.yaml` directly inside the volume.

A reasonable progression: `openrouter/free` → `qwen/qwen3-coder:free` → `openai/gpt-oss-120b:free` to confirm the agent loop works on free models, then graduate to `anthropic/claude-haiku-4-5` (cheap) or `anthropic/claude-sonnet-4.6` / `claude-opus-4.7` for production-quality agent runs.

## Browser support

The image includes Playwright runtime deps so the browser-harness skill can drive a local Chromium. For most production setups you'll still want to set `BROWSER_USE_API_KEY` or `BROWSERBASE_API_KEY` so the browser runs on a managed cloud — local browsers in containers are fragile and CPU-hungry. Both paths work; pick per use case.

## Layout

```
.
├── Dockerfile          # node:20-bookworm + python + uv + hermes + browser-harness + paperclipai
├── docker-compose.yml  # Dokploy-ready service definition
├── entrypoint.sh       # config seeding, .env rewrite, paperclipai/hermes dispatch
├── hermes-config.yaml  # default seeded config (model.default = openrouter/free)
└── .env.example        # documents the env vars for local docker-compose
```

## Persistent volumes

- `paperclip-data` → `/data/paperclip` — Paperclip's instances + embedded postgres
- `hermes-data` → `/data/hermes` — Hermes config.yaml, .env, and skill symlinks
- `browser-harness-cache` → `/opt/browser-harness/.cache` — browser-harness scratch
