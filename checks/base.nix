{
  pkgs,
  extraExcludes ? [ ],
  enableLinkCheck ? true,
  extraActionlintRunnerLabels ? [ ],
}:

let
  shellcheckWrapper = pkgs.writeShellApplication {
    name = "shellcheck-wrapper";
    runtimeInputs = [
      pkgs.shellcheck
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      bash_files=()
      sh_files=()

      for f in "$@"; do
        [ -f "$f" ] || continue

        # Read first 2 lines only (shebang + shellcheck directive)
        header="$(head -n 2 "$f" 2>/dev/null || true)"

        # 1️⃣ Explicit shellcheck directive wins
        if echo "$header" | grep -Eq '^\s*#\s*shellcheck\s+shell=bash'; then
          bash_files+=("$f")
          continue
        fi

        if echo "$header" | grep -Eq '^\s*#\s*shellcheck\s+shell=sh'; then
          sh_files+=("$f")
          continue
        fi

        # 2️⃣ Shebang-based detection
        if echo "$header" | grep -Eq '^#!.*\b(bash|env[[:space:]]+bash|with-contenv[[:space:]]+bash)\b'; then
          bash_files+=("$f")
          continue
        fi

        if echo "$header" | grep -Eq '^#!.*\b(sh|env[[:space:]]+sh|busybox[[:space:]]+sh|with-contenv[[:space:]]+sh)\b'; then
          sh_files+=("$f")
          continue
        fi
      done

      # Run shellcheck per shell type
      if [ "''${#bash_files[@]}" -gt 0 ]; then
        shellcheck \
          --shell=bash \
          --external-sources \
          "''${bash_files[@]}"
      fi

      if [ "''${#sh_files[@]}" -gt 0 ]; then
        shellcheck \
          --shell=sh \
          --external-sources \
          "''${sh_files[@]}"
      fi
    '';
  };

  baseExcludes = [
    "^.*\\.png$"
    "^.*\\.jpg$"
  ];

  markdownlintConfig = pkgs.writeTextFile {
    name = "config.markdownlint.yaml";
    text = ''
      default: true
      MD013: false
      MD033: false
      # MD060 ("table-column-style") only recognizes three fixed padding
      # conventions (aligned/compact/tight) and *always* enforces one of
      # them, even with `style: any` (the default) -- it just reports
      # whichever style is the closest match. There is no config value that
      # means "don't check table width at all", so the rule must be
      # disabled outright to allow ragged/hand-edited table widths.
      MD060: false
    '';
  };

  # actionlint's built-in runner label list lags GitHub's hosted runners
  # (v1.7.12 does not know ubuntu-26.04), so newer hosted labels are
  # declared here as if they were self-hosted. Repos add the labels of
  # their own self-hosted runners via extraActionlintRunnerLabels, because
  # a repo-local .github/actionlint.yaml is not read (see the hook below).
  actionlintRunnerLabels = [
    "ubuntu-26.04"
    "ubuntu-26.04-arm"
  ]
  ++ extraActionlintRunnerLabels;

  actionlintConfig = pkgs.writeTextFile {
    name = "actionlint.yaml";
    text = ''
      self-hosted-runner:
        labels:
      ${pkgs.lib.concatMapStrings (l: "    - ${builtins.toJSON l}\n") actionlintRunnerLabels}
      # `uses: $/<path>` (self-repository reference at the running commit,
      # Actions runner >= 2.336) is valid but unknown to actionlint 1.7.12.
      paths:
        .github/workflows/**/*.{yml,yaml}:
          ignore:
            - 'specifying action "\$/[^"]*" in invalid format because ref is missing'
    '';
  };

  # Shared lychee defaults. Repos add their own URL exclusions in a
  # `.lycheeignore` at the repo root (one regex per line), which lychee
  # reads from the working directory on its own.
  lycheeConfig = pkgs.writeTextFile {
    name = "lychee.toml";
    text = ''
      no_progress = true
      max_retries = 3
      retry_wait_time = 2
      timeout = 20
      max_concurrency = 16
      host_concurrency = 4

      # 403 and 429 mean the host answered but refused a bot or rate
      # limited us; neither means the link is dead.
      accept = ["200..=206", "403", "429"]

      # A timeout (after retries) says the host or our network was slow, not
      # that the link is dead; dead links fail with DNS, connection or HTTP
      # errors, which still fail the check. Failing on timeouts makes the
      # hook flaky (e.g. www.gnu.org stalls from some networks).
      accept_timeouts = true

      user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.2 Safari/605.1.15"
      header = { "accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", "accept-language" = "en-US,en;q=0.9" }

      exclude_all_private = true

      exclude = [
        # Single-label hostnames (dockerhost, myip, compose service
        # names, ...) are placeholders, never public URLs.
        '^https?://[^./:@]+(:[^/]*)?([/?#]|$)',
        '^https?://([^/]+\.)?(mysite|mydomain)\.',
        'YOUR[-_]?[A-Z]+',
      ]
    '';
  };

  # The mkCheck derivation sets PRE_COMMIT_CHECKS_OFFLINE because the Nix
  # sandbox has no network, so only local file links are checked there.
  # The sandbox also points SSL_CERT_FILE at a missing file, and lychee
  # refuses to start without a CA bundle even when offline. GITHUB_TOKEN,
  # when set, is picked up by lychee to avoid github.com rate limiting.
  lycheeWrapper = pkgs.writeShellApplication {
    name = "lychee-wrapper";
    runtimeInputs = [ pkgs.lychee ];
    text = ''
      args=(--config "${lycheeConfig}")
      if [ -n "''${PRE_COMMIT_CHECKS_OFFLINE:-}" ]; then
        args+=(--offline)
        export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      fi
      exec lychee "''${args[@]}" -- "$@"
    '';
  };

  excludes = baseExcludes ++ extraExcludes;

  hooks = {
    check-yaml.enable = true;
    end-of-file-fixer.enable = true;

    trailing-whitespace = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/trailing-whitespace-fixer";
    };

    mixed-line-ending = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/mixed-line-ending";
      args = [ "--fix=auto" ];
    };

    check-executables-have-shebangs.enable = true;
    check-shebang-scripts-are-executable.enable = true;
    check-added-large-files = {
      enable = true;
      args = [ "--maxkb=600" ];
    };
    check-symlinks.enable = true;
    detect-private-key = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/detect-private-key";
    };

    check-case-conflict = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-case-conflict";
    };

    check-merge-conflict = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-merge-conflict";
    };

    forbid-new-submodules = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/forbid-new-submodules";
    };

    check-json = {
      enable = true;
      entry = "${pkgs.python3Packages.pre-commit-hooks}/bin/check-json";
      files = "\\.json$";
    };

    no-commit-to-branch.enable = true;

    nixfmt.enable = true;
    shellcheck.enable = false;

    shellcheck-bash = {
      enable = true;

      entry = "${shellcheckWrapper}/bin/shellcheck-wrapper";

      # Let wrapper decide; we only need filenames
      types = [ "file" ];
      files = ".*";
      pass_filenames = true;
    };

    prettier = {
      enable = true;
      # Prettier has no config option to leave table formatting alone (it's
      # a long-standing, still-open upstream feature request) -- it always
      # re-pads GFM tables to its "aligned" style on `--write`, silently
      # rewriting files. In a CI-only setup (no local pre-commit hook)
      # contributors don't see that diff except by reading CI logs, so it
      # looks like an opaque failure for something markdownlint (MD060,
      # disabled above) no longer cares about.
      #
      # Markdown is excluded here entirely rather than just tables: the
      # `markdownlint` hook below is check-only (no `--fix`) and already
      # enforces the same style concerns (emphasis style, bullet markers,
      # blank lines, ...) via `default: true`, surfacing them as a named,
      # actionable rule failure instead of a silent rewrite.
      excludes = [ "\\.mdx?$" ];
    };
    check-toml.enable = true;
    check-vcs-permalinks.enable = true;

    markdownlint = {
      enable = true;
      entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2";
      files = "\\.(md|mdx)$";

      args = [
        "--config"
        "${markdownlintConfig}"
        "--no-glob"
      ];
    };

    lychee = {
      enable = enableLinkCheck;
      entry = "${lycheeWrapper}/bin/lychee-wrapper";
      files = "\\.(md|mdx)$";
      pass_filenames = true;
      # One lychee process at a time, so the per-host limits in
      # lycheeConfig are not multiplied by pre-commit's parallel batches.
      require_serial = true;
    };

    deadnix = {
      enable = true;
      entry = "${pkgs.deadnix}/bin/deadnix";
      args = [ "--fail" ];
      files = "\\.nix$";
    };

    statix = {
      enable = true;
      entry = "${pkgs.statix}/bin/statix";
      args = [ "check" ];
      files = "\\.nix$";
    };

    codespell = {
      enable = true;
      entry = "${pkgs.codespell}/bin/codespell";
      args = [ "--ignore-words=.dictionary.txt" ];
      files = "\\.(c|cpp|rs|py|sh|txt|md|toml|yaml|yml)$";
    };

    check-github-actions = {
      enable = true;
      entry = "${pkgs.check-jsonschema}/bin/check-jsonschema";
      args = [
        "--builtin-schema"
        "github-actions"
      ];
      files = "^\\.github/actions/.*\\.ya?ml$";
      pass_filenames = true;
    };

    check-github-workflows = {
      enable = true;
      entry = "${pkgs.check-jsonschema}/bin/check-jsonschema";
      args = [
        "--builtin-schema"
        "github-workflows"
      ];
      files = "^\\.github/workflows/.*\\.ya?ml$";
      pass_filenames = true;
    };

    # Semantic lint for workflows, beyond check-github-workflows' schema
    # validation: expression and context typos, unknown runner labels, and
    # shellcheck on every `run:` block (the nixpkgs actionlint is wrapped
    # with shellcheck). The shared config above is passed explicitly, which
    # means a repo-local .github/actionlint.yaml is NOT read; repos declare
    # their self-hosted runner labels with extraActionlintRunnerLabels.
    actionlint = {
      enable = true;
      entry = "${pkgs.actionlint}/bin/actionlint";
      args = [
        "-config-file"
        "${actionlintConfig}"
      ];
      files = "^\\.github/workflows/.*\\.ya?ml$";
      pass_filenames = true;
    };
  };
in

{
  inherit hooks excludes;

  enabledPackages = [ ];
  passthru = {
    devPackages = [ ];
    libPath = [ ];
  };
}
