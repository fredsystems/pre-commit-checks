{
  pkgs,
  extraExcludes ? [ ],
}:

let
  baseExcludes = [
    "^.*\\.png$"
    "^.*\\.jpg$"
  ];

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

    black.enable = true;
    flake8.enable = true;
    nixfmt.enable = true;
    hadolint.enable = true;
    shellcheck.enable = true;
    prettier.enable = true;

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
