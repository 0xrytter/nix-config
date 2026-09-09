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
    };
  }) ids;
in {
  # Applies to every opencode invocation (all workspace profiles).
  xdg.configFile = lib.listToAttrs profiles // {
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