{
  pkgs,
  extraExcludes ? [ ],
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

    prettier.enable = true;
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
