{ agents, config, lib, pkgs, ... }:
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

  # crush 0.92.0 rejects the contentless (reasoning-only) assistant turns an
  # interrupted prompt leaves persisted in the session, so every later request
  # 400s and the session is bricked (crush-empty-assistant-message-bug.md,
  # upstream #3734). 0.65.3 tolerates those turns, so pin the package itself from
  # the nixpkgs rev that carried it: a `nix flake update` cannot drag it forward.
  #
  # Upstream fixed it afterwards: commit 066f4444d086 ("openaicompat: bump fantasy
  # to fix regression around reasoning-only turns"), first released in v0.94.2
  # (2026-09-14). #3734 is still open but was last touched 2026-09-12, before
  # that fix shipped, so its state is not a useful signal. Drop this pin once the
  # `crush95` probe below passes.
  crush = (import (builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "781b68f9d51b37ecdd5ef0ddd666ff4d5b7118e0";
  }) {
    system = pkgs.system;
    config.allowUnfreePredicate = pkg: lib.getName pkg == "crush";
  }).crush;

  # crush 0.95.0 built from source so the cancelled-turn fix can be applied
  # locally. nixpkgs still only carries 0.92.0, and upstream's 0.94.2 fantasy
  # bump did not cover this path: a turn cancelled while the model is thinking
  # is persisted with only reasoning, and the OpenAI-compatible converter then
  # sends it as an assistant message with `content: null`, which the gateway
  # rejects -- every later request in that session 400s. The patch drops the
  # reasoning exemption in preparePrompt's contentless-assistant guard
  # (internal/agent/agent.go:1599), restoring 0.65.3 behaviour. Verified with
  # crush-cancel-repro; drop the patch once upstream lands it.
  crush95 = pkgs.buildGo127Module {
    pname = "crush";
    version = "0.95.0";

    src = pkgs.fetchFromGitHub {
      owner = "charmbracelet";
      repo = "crush";
      tag = "v0.95.0";
      hash = "sha256-4JbJOP5hIc1bpga84bium7QEzFJj9jjjojfpG/hbjCg=";
    };

    vendorHash = "sha256-HktSB71scE55BG3TzJyDbAV1j+T8+DDxMTAiomeLbgc=";

    patches = [
      ../../patches/crush-0.95.0-reasoning-only.patch
      ../../patches/crush-0.95.0-diff-render.patch
    ];

    # Only the root main package: the tree also carries
    # internal/ui/logo/example, which would install a `bin/example` that
    # collides with the pinned 0.65.3 build in the profile.
    subPackages = [ "." ];

    ldflags = [
      "-s"
      "-X=github.com/charmbracelet/crush/internal/version.Version=0.95.0"
    ];

    # The package tests are run in crush-cancel-repro; skipping them here keeps
    # a home-manager switch from paying for a Go test run on every rebuild.
    doCheck = false;

    postInstall = ''
      mv $out/bin/crush $out/bin/crush95
    '';
  };

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
      model = "opencode-go/deepseek-v4.1-flash";
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

  # Generated per-workspace shorthands (occgo1..N, occodex1..N, ocgoose1..N)
  # mirror the generic functions below, written as fish function files since
  # programs.fish.functions keys must be static. Each harness carries the key
  # in the OPENCODE_API_KEY env var (codex's env_key, goose's key, crush's
  # built-in OpenCode Zen & Go auth). Shorthands exec the bare binary (command)
  # so they never recurse into the generic <harness> N fish functions.
  harnessShorthand = harness: env: bin: n: lib.nameValuePair "fish/functions/${harness}${toString n}.fish" {
    text = ''
      function ${harness}${toString n} --description "${harness} on go-workspace-${toString n}"
        if not test -f ${cfgBase}/secrets/go-workspace-${toString n}.key
          echo "no key for workspace: ${toString n}"
          return 1
        end
        set -lx ${env} (cat ${cfgBase}/secrets/go-workspace-${toString n}.key)
        command ${bin} $argv
      end
    '';
  };

  shorthandFor = harness: env: bin: map (harnessShorthand harness env bin) ids;
  crushShorthands = shorthandFor "occgo" "OPENCODE_API_KEY" "crush";
  codexShorthands = shorthandFor "occodex" "OPENCODE_API_KEY" "codex";
  gooseShorthands = shorthandFor "ocgoose" "OPENCODE_API_KEY" "goose";

  # OpenCode Go models are served over OpenAI-compatible APIs at this base;
  # codex (wire_api responses) points here and authenticates with the
  # workspace key as a Bearer token.
  goBase = "https://opencode.ai/zen/go/v1";

  # Stable gateway session id for crush (extra_headers below). Generated only
  # deliberately, never on rebuilds. Codex and goose >=1.51 send their own
  # native session ids; goose 1.47 (nixpkgs) could not, which is why it rides
  # the llm-agents flake input.
  goSessionId = "94b0447f-a5b3-47c2-bc8d-853148b17a3e";

  # Codex reads ~/.codex/config.toml. The provider entry replaces the built-in
  # OpenAI one; the key comes from OPENCODE_API_KEY set by the shorthands.
  # codex >=0.154 only speaks wire_api responses, which the Go gateway accepts
  # for deepseek-v4.1-flash even though its docs list the model under
  # chat/completions (verified with a real request, 2026-09-18).
  #
  # ponytail: this file is a writable real file, not a hm link — codex
  # persists directory-trust entries into it and fails on the read-only store
  # symlink. Installed once by installCodexConfig below; editing the
  # declaration later means deleting ~/.codex/config.toml to re-seed.
  codexConfigFile = pkgs.writeText "codex-config.toml" ''
    model = "deepseek-v4.1-flash"
    model_provider = "opencode-go"

    [model_providers.opencode-go]
    name = "OpenCode Go"
    base_url = "${goBase}"
    env_key = "OPENCODE_API_KEY"
    wire_api = "responses"
  '';

  # Goose reads ~/.config/goose/config.yaml. It ships a native declarative
  # provider `opencode_go` (OpenCode Go base URL, OPENCODE_API_KEY auth, and
  # the x-opencode-session header the gateway requires — supported from
  # 1.51.0; nixpkgs' pinned 1.47.0 build lacks the session header override,
  # so goose comes from the llm-agents flake input instead). Only the
  # provider/model selection is needed here; the key stays env-only.
  #
  # ponytail: like codex's config, installed as a writable real file, not a
  # hm link — goose resolves its config write target allowing at most one
  # symlink hop (MAX_SYMLINK_HOPS in config/base.rs) and the home-manager
  # link chain is two. Editing the declaration later means deleting
  # ~/.config/goose/config.yaml to re-seed.
  gooseConfigFile = pkgs.writeText "goose-config.yaml" ''
    GOOSE_PROVIDER: opencode_go
    GOOSE_MODEL: ${defaultGoModel}
  '';

  # Default model for every opencode-go harness (codex, goose, crush below).
  defaultGoModel = "deepseek-v4.1-flash";

  # Static crush config so it rides the home-manager declaration — the session
  # header is a stable identifier, regenerated only deliberately, not on
  # rebuilds. Headers are per-provider in crush, so they ride the opencode-go
  # provider entry (matches OPENCODE_API_KEY auth in occurrence.sh functions).
  crushConfig = lib.nameValuePair "crush/crush.json" {
    text = builtins.toJSON {
      "$schema" = "https://charm.land/crush.json";
      models = {
        large = { model = defaultGoModel; provider = "opencode-go"; };
        small = { model = defaultGoModel; provider = "opencode-go"; };
      };
      providers = {
        "opencode-go" = {
          extra_headers = {
            "x-opencode-session" = goSessionId;
          };
        };
      };
      # Same ruleset as opencode: agent-rules.md as session context, plus a
      # PreToolUse hook that denies sops/age/leagueos access (mirrors the
      # opencode permission profile; opencode has no hook equivalent in crush,
      # and crush permissions have no command-pattern denies, so a hook is the
      # mechanism that makes banned calls literally fail).
      hooks.PreToolUse = [
        {
          matcher = "^(bash|edit|write|multiedit|view)$";
          command = "${config.xdg.configHome}/crush/hooks/protect-secrets.sh";
        }
      ];
      options = {
        context_paths = [
          "${config.xdg.configHome}/crush/agent-rules.md"
        ];
        attribution = {
          trailer_style = "none";
          generated_with = false;
        };
      };
    };
  };

  crushHook = lib.nameValuePair "crush/hooks/protect-secrets.sh" {
    text = builtins.readFile ../../config/crush-hooks/protect-secrets.sh;
    executable = true;
  };
in {
  # Applies to every opencode invocation (all workspace profiles).
  xdg.configFile = lib.listToAttrs (profiles ++ crushShorthands ++ codexShorthands ++ gooseShorthands ++ [ crushConfig crushHook ]) // {
    # Global config — always-on ruleset (agent-rules.md: concise comms, Nix
    # env, lazy-senior-dev code discipline, tests, types, language tree).
    # Plain markdown, no plugin, travels to any harness.
    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      instructions = [ "${config.xdg.configHome}/opencode/agent-rules.md" ];
    };
    "opencode/agent-rules.md".source = ../../config/agent-rules.md;
    # Crush mirror of the same ruleset (loaded via crush.json context_paths).
    "crush/agent-rules.md".source = ../../config/agent-rules.md;
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
    crush
    crush95
    pkgs.codex
    agents.goose-cli
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

  # Same launcher as `occgo`, but the 0.95.0 probe binary (see crush95 above).
  # Reads the same workspace key file. Deliberately generic rather than a
  # generated occgo951..5 set: this is a test vehicle, and if the probe passes
  # the pin goes away and this goes with it.
  programs.fish.functions.occgo95 = ''
    set -l n $argv[1]
    if test -z "$n"
      echo "usage: occgo95 <N>"
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
    crush95 $argv[2..-1]
  '';

  # Generic <harness> <N> launchers, matching the generated shorthands above.

  programs.fish.functions.occodex = ''
    set -l n $argv[1]
    if test -z "$n"
      echo "usage: occodex <N>"
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
    codex $argv[2..-1]
  '';

  programs.fish.functions.ocgoose = ''
    set -l n $argv[1]
    if test -z "$n"
      echo "usage: ocgoose <N>"
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
    goose $argv[2..-1]
  '';

  # Crush writes OSC 12 (cursor colour) and OSC 11 (background) but only undoes
  # the cursor colour when its last rendered frame still had a themed cursor
  # (bubbletea/v2 cursed_renderer.go), and tmux replays a pane's remembered
  # colour every time that pane is active. Scrub on the way out so crush only
  # themes its own pane, and only while it is running. Root fix is upstream.
  programs.fish.functions.crush = ''
    command crush $argv
    printf '\e]112\a\e]111\a'
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

  home.activation.installGooseConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e ${config.home.homeDirectory}/.config/goose/config.yaml ]; then
      $DRY_RUN_CMD install -D -m 600 ${gooseConfigFile} \
        ${config.home.homeDirectory}/.config/goose/config.yaml
    fi
  '';

  home.activation.installCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e ${config.home.homeDirectory}/.codex/config.toml ]; then
      $DRY_RUN_CMD install -D -m 600 ${codexConfigFile} \
        ${config.home.homeDirectory}/.codex/config.toml
    fi
  '';

  home.activation.createOpencodeSecretDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/opencode/secrets
    $DRY_RUN_CMD chmod 700 ${config.xdg.configHome}/opencode/secrets
  '';
}