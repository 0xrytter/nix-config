# nix-config

NixOS + home-manager configuration for T480 and other machines.

## First-time setup after deploy

### pi sandbox

The `pi` command runs inside a Docker-in-Docker sandbox — filesystem access is restricted to the current directory, with no access to the host system outside it.

The Docker image is not managed by Nix. Build it once after the first deploy:

```
docker build -t pi-sandbox ~/.config/pi-sandbox/
```

After that, running `pi` in any project directory will use the sandbox automatically. The image auto-builds if missing.

To rebuild after a Dockerfile change:
```
docker rmi pi-sandbox && docker build -t pi-sandbox ~/.config/pi-sandbox/
```
