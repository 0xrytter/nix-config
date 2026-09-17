{ config, lib, pkgs, ... }:
let
  cfgBase = "${config.xdg.configHome}/opencode";
  workspaceCount = 5;
  ids = lib.range 1 workspaceCount;
  ws = n: "go-workspace-${toString n}";
  profilePath = n: "opencode/profiles/${ws n}.json";

  # graphify is too new for the pinned nixpkgs in this flake's lock. Pull it from
  # a newer nixpkgs rev instead of bumping the whole lock (which broke fish
  # completions). Only this package uses the newer rev.
  graphifyNixpkgs = import (builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "422d1ae605d7fcd9896412b37dc065c456c0eefb";
  }) { system = pkgs.system; };
  graphify = graphifyNixpkgs.graphify;

  # Graphify ships the opencode skill (SKILL.md) inside its Python package.
  graphifySkill = "${graphify}/lib/python3.14/site-packages/graphify/skill-opencode.md";

  # Provider routing to the local llama.cpp server (strix-halo-llm).
  # Model id "local" is accepted because serve.sh passes --alias local.
  localProvider = {
    npm = "@ai-sdk/openai-compatible";
    name = "Local llama.cpp";
    options = {
      baseURL = "http://localhost:8080/v1";
      apiKey = "not-needed";
    };
    models = {
      local = { name = "Local (llama.cpp)"; };
      "qwen3.6-35b-a3b" = { name = "Qwen 3.6 35B A3B (local)"; };
      "deepseek-v4-flash" = { name = "DeepSeek V4 Flash (local)"; };
    };
  };

  profiles = map (n: lib.nameValuePair (profilePath n) {
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = "opencode-go/qwen3.8-flash";
      provider = {
        opencode-go.options.apiKey =
          "{file:${config.xdg.configHome}/opencode/secrets/${ws n}.key}";
        local = localProvider;
      };
      permission = {
        read = "ask";
        bash = {
          "sops *" = "deny";
          "*sops*" = "deny";
          "*age/keys.txt*" = "deny";
          "*sops/age/keys.txt*" = "deny";
          "aws --endpoint-url*" = "ask";
          "cat /var/lib/leagueos/.env" = "deny";
          "*leagueos.enc.yaml*" = "ask";
        };
        # Deny by default unless explicitly allowed — secrets stay out of the
        # session unless the user makes a deliberate exception.
        external_directory = {
          "~/.config/sops/**" = "deny";
          "~/.config/leagueos/**" = "deny";
          "~/.sops/**" = "deny";
          "/var/lib/leagueos/**" = "deny";
          "**/secrets/**" = "ask";
        };
      };
    };
  }) ids;

  # Crush (charmbracelet TUI harness) reuses the same opencode-go workspace
  # keys; OPENCODE_API_KEY is its env var for the OpenCode Zen & Go provider.
  # Generated shorthands occgo1..occgoN mirror the generic `occgo N`, written
  # as fish function files since programs.fish.functions keys must be static.
  occgoShorthand = n: lib.nameValuePair "fish/functions/occgo${toString n}.fish" {
    text = ''
      function occgo${toString n} --description "crush on go-workspace-${toString n}"
        if not test -f ${cfgBase}/secrets/go-workspace-${toString n}.key
          echo "no key for workspace: ${toString n}"
          return 1
        end
        set -lx OPENCODE_API_KEY (cat ${cfgBase}/secrets/go-workspace-${toString n}.key)
        crush $argv
      end
    '';
  };

  crushShorthands = map occgoShorthand ids;

  # Static crush config so it rides the home-manager declaration — the session
  # header is a stable identifier, regenerated only deliberately, not on
  # rebuilds. Headers are per-provider in crush, so they ride the opencode-go
  # provider entry (matches OPENCODE_API_KEY auth in occurrence.sh functions).
  crushConfig = lib.nameValuePair "crush/crush.json" {
    text = builtins.toJSON {
      "$schema" = "https://charm.land/crush.json";
      providers = {
        "opencode-go" = {
          extra_headers = {
            "x-opencode-session" = "94b0447f-a5b3-47c2-bc8d-853148b17a3e";
          };
        };
      };
    };
  };
in {
  # Applies to every opencode invocation (all workspace profiles).
  xdg.configFile = lib.listToAttrs (profiles ++ crushShorthands ++ [ crushConfig ]) // {
    # Global config — always-on ruleset (agent-rules.md: concise comms, Nix
    # env, lazy-senior-dev code discipline, tests, types, language tree).
    # Plain markdown, no plugin, travels to any harness.
    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      instructions = [ "${config.xdg.configHome}/opencode/agent-rules.md" ];
    };
    "opencode/agent-rules.md".source = ../../config/agent-rules.md;
    "opencode/tui.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      attention = {
        enabled = true;
        notifications = true;
        sound = true;
        volume = 0.5;
      };
    };
    # Global graphify skill — /graphify available in every opencode workspace.
    "opencode/skills/graphify/SKILL.md".source = graphifySkill;
  };

  home.packages = [
    graphify
    pkgs.crush
  ];

  programs.fish.functions.ocgo = ''
    set -l n $argv[1]
    if test -z "$n"
      echo "usage: ocgo <N>"
      echo "available:" (ls ${cfgBase}/profiles)
      return 1
    end
    set -l prof ${cfgBase}/profiles/go-workspace-$n.json
    if not test -f $prof
      echo "unknown workspace: $n"
      echo "available:" (ls ${cfgBase}/profiles)
      return 1
    end
    set -lx OPENCODE_CONFIG $prof
    opencode $argv[2..-1]
  '';

  # Crush (charmbracelet TUI harness) reuses the same opencode-go workspace
  # keys; OPENCODE_API_KEY is its env var for the OpenCode Zen & Go provider.
  # Generated shorthands occgo1..occgoN mirror the generic `occgo N`, kept as
  # generated fish function files (occgo1..occgoN via crushShorthands).

  programs.fish.functions.occgo = ''
    set -l n $argv[1]
    if test -z "$n"
      echo "usage: occgo <N>"
      echo "available:" (ls ${cfgBase}/profiles)
      return 1
    end
    set -l key ${cfgBase}/secrets/go-workspace-$n.key
    if not test -f $key
      echo "no key for workspace: $n"
      echo "available:" (ls ${cfgBase}/profiles)
      return 1
    end
    set -lx OPENCODE_API_KEY (cat $key)
    crush $argv[2..-1]
  '';

  programs.fish.functions.ocgolist = ''
    echo "go workspaces:"
    for f in ${cfgBase}/profiles/go-workspace-*.json
      set -l n (basename $f .json)
      set -l has "no"
      test -f ${cfgBase}/secrets/$n.key && set has "yes"
      echo "  $n (key present: $has)"
    end
  '';

  home.activation.createOpencodeSecretDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/opencode/secrets
    $DRY_RUN_CMD chmod 700 ${config.xdg.configHome}/opencode/secrets
  '';
}