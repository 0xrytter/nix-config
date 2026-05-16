FROM docker:dind
RUN apk add --no-cache nodejs npm git python3
RUN mkdir -p /root/.claude /root/.config/tmux /root/.pi
RUN npm install -g @earendil-works/pi-coding-agent
WORKDIR /work
ENTRYPOINT ["pi"]
