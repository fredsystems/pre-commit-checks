{
  pkgs,
  extraExcludes ? [ ],
}:

let
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
    check-added-large-files.enable = true;
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

    shellcheck = {
      enable = true;
      entry = "${pkgs.shellcheck}/bin/shellcheck";

      # Match:
      #  - *.sh
      #  - files with bash/sh shebangs
      files = ''
        (
          \.sh$ |
          ^.*$
        )
      '';

      # Let shellcheck decide based on shebang
      args = [
        "--external-sources"
      ];

      # This is the important part: rely on shebangs
      types = [ "shell" ];
    };

    prettier.enable = true;
    check-toml.enable = true;
    check-vcs-permalinks.enable = true;

    markdownlint = {
      enable = true;
      entry = "${pkgs.nodePackages.markdownlint-cli2}/bin/markdownlint-cli2";
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
