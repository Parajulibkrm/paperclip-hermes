FROM node:20-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PAPERCLIP_HOME=/data/paperclip
ENV HERMES_HOME=/data/hermes
# Hermes install lands binaries (uv, hermes, node-from-hermes) under
# /opt/hermes/.local/bin. We expose them on PATH so both root (entrypoint
# setup) and the node user (paperclipai run) can call them.
ENV PATH="/opt/hermes/.local/bin:${PATH}"

# System deps:
#  - build-essential/python3*: native modules + uv tool builds
#  - sudo/xz-utils/ripgrep/ffmpeg: parity with hermes-dokploy reference
#  - libnss3/libatk*/fonts-liberation/etc.: Playwright/Chromium runtime deps
#    so the browser-harness skill can drive a local browser without a cloud
#    fallback. (Cloud providers via BROWSER_USE_API_KEY / BROWSERBASE_*
#    still work; these just remove the local-only blocker.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash build-essential ca-certificates curl git \
        python3 python3-pip python3-venv \
        sudo xz-utils ripgrep ffmpeg \
        libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
        libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
        libxrandr2 libgbm1 libasound2 libpango-1.0-0 libcairo2 \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# --- Hermes Agent ---
# Install to /opt/hermes (not /root) so the unprivileged `node` user can read
# the binaries and skill tree at runtime. The install script ends with an
# interactive setup wizard; we redirect /dev/null so it exits on EOF, and
# `|| true` swallows the wizard's non-zero exit. We then verify the critical
# bits landed on disk so silent breakage still fails the build. The install
# script links `hermes` into /usr/local/bin itself — don't re-link.
RUN mkdir -p /opt/hermes \
 && export HOME=/opt/hermes \
 && curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh -o /tmp/hermes-install.sh \
 && bash /tmp/hermes-install.sh </dev/null || true \
 && rm -f /tmp/hermes-install.sh \
 && test -x /opt/hermes/.local/bin/uv \
 && test -d /opt/hermes/.hermes/hermes-agent \
 && command -v hermes >/dev/null \
 && chmod -R a+rX /opt/hermes

# --- Browser Harness (browser-use's hermes skill) ---
WORKDIR /opt
RUN git clone https://github.com/browser-use/browser-harness \
 && cd browser-harness \
 && export HOME=/opt/hermes \
 && /opt/hermes/.local/bin/uv tool install -e . \
 && chmod -R a+rX /opt/hermes /opt/browser-harness

# --- Register browser-harness as a hermes skill at the image level ---
# We symlink into /opt/hermes/.hermes/skills so the install is self-contained;
# entrypoint.sh re-creates the same symlinks under $HERMES_HOME/skills on the
# persistent volume on first boot.
RUN mkdir -p /opt/hermes/.hermes/skills/browser-harness \
 && ln -sf /opt/browser-harness/SKILL.md            /opt/hermes/.hermes/skills/browser-harness/SKILL.md \
 && ln -sf /opt/browser-harness/interaction-skills  /opt/hermes/.hermes/skills/browser-harness/interaction-skills \
 && ln -sf /opt/browser-harness/domain-skills       /opt/hermes/.hermes/skills/browser-harness/domain-skills

# Seed defaults — entrypoint copies these to $HERMES_HOME on first boot.
COPY hermes-config.yaml /etc/hermes/config.yaml
RUN touch /etc/hermes/.env

# --- Paperclip web app ---
RUN npm install -g paperclipai

# Data dirs (paperclipai writes its postgres + instances under PAPERCLIP_HOME;
# hermes config + .env live under HERMES_HOME). Owned by node so the
# unprivileged run user can write to them.
RUN mkdir -p /data/paperclip /data/hermes /workspace \
 && chown -R node:node /data/paperclip /data/hermes /workspace

WORKDIR /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3100

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["paperclip"]
