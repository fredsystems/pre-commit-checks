{
  description = "Fred's shared base pre-commit flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      git-hooks,
      flake-utils,
      ...
    }:
    let
      # All “normal” systems flake-utils cares about.
      systems = flake-utils.lib.defaultSystems;
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      ##########################################################################
      ## Library: reusable pre-commit generator                               ##
      ## - Consumers call: precommit-base.lib.mkPrecommitCheck { ... }        ##
      ## - Supports per-repo extraExcludes that extend base excludes          ##
      ##########################################################################
      lib.mkPrecommitCheck =
        {
          system,
          src,
          extraExcludes ? [ ],
        }:

        let
          pkgs = import nixpkgs { inherit system; };

          # Base excludes for THIS flake only.
          baseExcludes = [
            "^.*\\.png$"
            "^.*\\.jpg$"
          ];

          # Consumers extend these via extraExcludes.
          excludes = baseExcludes ++ extraExcludes;

        in
        git-hooks.lib.${system}.run {
          inherit src excludes;

          hooks = {
            ####################################################################
            ## Simple / builtin hooks                                         ##
            ####################################################################
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

            ####################################################################
            ## Formatters & linters                                           ##
            ####################################################################
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
              files = "\\.([ch]|cpp|rs|py|sh|txt|md|toml|yaml|yml)$";
            };

            ####################################################################
            ## GitHub Actions / Workflow validation                           ##
            ####################################################################
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
        };

      ##########################################################################
      ## DevShells for THIS flake (not consumers)                             ##
      ## - direnv / `nix develop` look for devShells.${system}.default        ##
      ##########################################################################
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          # This is devShells.${system}.default
          default = pkgs.mkShell {
            packages = [
              pkgs.pre-commit
              pkgs.deadnix
              pkgs.statix
              pkgs.nixfmt
              pkgs.check-jsonschema
              pkgs.codespell
              pkgs.nodePackages.markdownlint-cli2
            ];
          };
        }
      );
    };
}
