FROM docker:dind
RUN apk add --no-cache nodejs npm git
RUN npm install -g @earendil-works/pi-coding-agent
WORKDIR /work
ENTRYPOINT ["pi"]
