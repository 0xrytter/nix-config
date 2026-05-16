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
  && mkdir -p /home/node/.claude /home/node/.config/tmux /home/node/.pi \
  && chown -R node:node /home/node \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g @earendil-works/pi-coding-agent
WORKDIR /work
ENTRYPOINT ["pi"]
