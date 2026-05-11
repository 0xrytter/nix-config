FROM node:lts-alpine
RUN apk add --no-cache git tmux bash python3
RUN npm install -g @anthropic-ai/claude-code
WORKDIR /work
ENTRYPOINT ["claude"]
