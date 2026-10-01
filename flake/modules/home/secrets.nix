{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The workstation's trust group: one file, one anchor. Never the host files.
  #
  # Absolute path on purpose. The accessors read this at runtime, so editing the
  # secrets repo takes effect immediately; a `path:` flake input would instead
  # freeze a copy into the store and require a flake update on every edit.
  secretsFile = "/home/rytter/src/secrets/secrets/personal.enc.yaml";

  # The one anchor. Its public half is the &admin recipient in .sops.yaml.
  anchorPubkey = "age12kpcm6rfmeftlfg57f9wr8k8c0420jd574hsrraknsxrzkwn4fgqdaner5";

  # Under model B a locked anchor is the *normal* failure, not an exceptional
  # one, so every accessor has to fail loudly: an empty credential handed to a
  # consumer looks like an auth bug somewhere else entirely.
  preamble = ''
    anchor="''${SOPS_AGE_KEY_FILE:-''${XDG_RUNTIME_DIR}/sops/age/keys.txt}"
    if [ ! -s "$anchor" ]; then
      echo "anchor not unlocked: nothing at $anchor — run 'unlock'" >&2
      exit 1
    fi
    export SOPS_AGE_KEY_FILE="$anchor"
  '';

  # sec <name> — the value on stdout. For consumers that want an env var.
  sec = pkgs.writeShellApplication {
    name = "sec";
    runtimeInputs = [ pkgs.sops ];
    text = ''
      ${preamble}
      if [ "$#" -ne 1 ]; then
        echo "usage: sec <name>" >&2
        exit 2
      fi
      exec sops --decrypt --extract "[\"$1\"]" ${secretsFile}
    '';
  };

  # secfile <name> — write it to tmpfs and print the path. Only for the few
  # consumers that cannot take a value (dnsthing wants a path; grafana wants a
  # file). Mode 0400 because everything that reads it runs as this user.
  secfile = pkgs.writeShellApplication {
    name = "secfile";
    runtimeInputs = [
      pkgs.sops
      pkgs.coreutils
    ];
    text = ''
      ${preamble}
      if [ "$#" -ne 1 ]; then
        echo "usage: secfile <name>" >&2
        exit 2
      fi
      dir="''${XDG_RUNTIME_DIR}/secrets"
      mkdir -p "$dir"
      chmod 700 "$dir"
      out="$dir/$1"
      # Write beside the target and rename over it. Writing in place fails on
      # the second call: the previous run left the file at 0400, and the owner
      # has no write bit either — rename(2) only needs the directory writable.
      # secfile has to be re-runnable; shell hooks call it on every entry.
      tmp="$(mktemp "$dir/.$1.XXXXXX")"
      # Value goes straight through the shell, never to a terminal or a log.
      if ! sops --decrypt --extract "[\"$1\"]" ${secretsFile} > "$tmp"; then
        rm -f "$tmp"
        echo "secfile: no such key: $1" >&2
        exit 1
      fi
      chmod 400 "$tmp"
      mv -f "$tmp" "$out"
      echo "$out"
    '';
  };

  # unlock — paste the anchor from the clipboard into tmpfs, verify it, and load
  # the ssh key into the agent.
  #
  # The verification is the point. `clip.exe` cannot read the clipboard (it only
  # writes), so the read goes through WSLg's wl-paste, falling back to PowerShell
  # Get-Clipboard, which is famous for appending CRLF. A stray \r inside an age
  # key is not a subtle failure — it produces "malformed secret key" and cost an
  # hour once already — so: strip \r, keep only the key line, derive the public
  # half, and refuse unless it matches the anchor we expect.
  unlock = pkgs.writeShellApplication {
    name = "unlock";
    runtimeInputs = [
      pkgs.age
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.openssh
      pkgs.wl-clipboard
    ];
    text = ''
      anchor_dir="''${XDG_RUNTIME_DIR}/sops/age"
      anchor="$anchor_dir/keys.txt"
      mkdir -p "$anchor_dir"
      chmod 700 "$anchor_dir"

      raw="$(mktemp)"
      key="$(mktemp)"
      cleanup() {
        shred -u "$raw" 2>/dev/null || rm -f "$raw"
        shred -u "$key" 2>/dev/null || rm -f "$key"
      }
      trap cleanup EXIT INT TERM

      # Read the clipboard, and when running interactively keep asking until the
      # anchor is there. The prompt is what makes the boot sequence possible:
      # WezTerm runs `unlock` before it starts herdr, so there has to be a moment
      # to go and fetch the key. Interactive-only, so a script calling unlock
      # still fails fast rather than hanging on a prompt nobody can answer.
      while :; do
        if command -v wl-paste >/dev/null 2>&1; then
          wl-paste > "$raw" 2>/dev/null || true
        fi
        if [ ! -s "$raw" ] && command -v powershell.exe >/dev/null 2>&1; then
          powershell.exe -NoProfile -Command Get-Clipboard > "$raw" 2>/dev/null || true
        fi

        tr -d '\r' < "$raw" | grep -oE 'AGE-SECRET-KEY-1[A-Z0-9]+' | head -n1 > "$key" || true
        if [ -s "$key" ]; then
          break
        fi

        if [ ! -t 0 ]; then
          echo "unlock: no age secret key on the clipboard" >&2
          echo "        copy the AGE-SECRET-KEY-1... line from Bitwarden first" >&2
          exit 1
        fi

        echo "unlock: no age key on the clipboard yet." >&2
        echo "        Copy the AGE-SECRET-KEY-1... line from Bitwarden, then press Enter." >&2
        echo "        (Ctrl-C to cancel)" >&2
        read -r _ || exit 1
      done
      chmod 600 "$key"

      if ! got="$(age-keygen -y "$key" 2>/dev/null)"; then
        echo "unlock: clipboard text is not a valid age key" >&2
        exit 1
      fi
      if [ "$got" != "${anchorPubkey}" ]; then
        echo "unlock: wrong key — clipboard is ''${got:0:24}..., expected ${anchorPubkey}" >&2
        exit 1
      fi

      install -m 600 "$key" "$anchor"
      echo "anchor unlocked: $anchor"

      if [ -S "''${SSH_AUTH_SOCK:-}" ]; then
        ${sec}/bin/sec ssh-ed25519 | ssh-add - 2>/dev/null \
          && echo "ssh key loaded into the agent" \
          || echo "unlock: could not add the ssh key to the agent" >&2
      else
        echo "unlock: no ssh-agent in this shell, ssh key not loaded" >&2
      fi
    '';
  };
in
{
  home.packages = [
    sec
    secfile
    unlock
  ];

  # Point sops at the tmpfs anchor. Declared as a conf.d snippet rather than
  # home.sessionVariables so the value is written verbatim and expanded by fish
  # at source time — conf.d also runs before config.fish, ahead of hm-session-vars.
  xdg.configFile."fish/conf.d/20-sops-anchor.fish".text = ''
    if set -q XDG_RUNTIME_DIR
      set -gx SOPS_AGE_KEY_FILE "$XDG_RUNTIME_DIR/sops/age/keys.txt"
    end
  '';

  # sops-nix's own keyFile, for consistency. Nothing declares sops.secrets on
  # this machine (the accessors do the work), so this is inert — but pointing it
  # at the same anchor keeps the two from disagreeing if a sops.secrets is ever
  # added here.
  sops.age.keyFile = lib.mkForce "$XDG_RUNTIME_DIR/sops/age/keys.txt";
}
