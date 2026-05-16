FROM node:lts-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    fd-find \
    git \
    openssh-client \
    python3 \
    ripgrep \
    tmux \
  && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
  && mkdir -p /home/node/.config/tmux \
  && chown -R node:node /home/node/.config \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code
WORKDIR /work
ENTRYPOINT ["claude"]
