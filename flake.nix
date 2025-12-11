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
      self,
      nixpkgs,
      git-hooks,
      flake-utils,
      ...
    }:
    let
      systems = flake-utils.lib.defaultSystems;
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {

      ############################################################################
      ## Library: reusable pre-commit generator                                 ##
      ############################################################################
      lib.mkPrecommitCheck =
        {
          system,
          src,
          extraExcludes ? [ ],
        }:

        let
          pkgs = import nixpkgs { inherit system; };

          baseExcludes = [
            "^.*\\.png$"
            "^.*\\.jpg$"
          ];

          excludes = baseExcludes ++ extraExcludes;

        in
        git-hooks.lib.${system}.run {
          inherit src excludes;

          hooks = {
            ############################################################
            ## Basic fixers                                           ##
            ############################################################
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

            ############################################################
            ## Linters / Formatters                                   ##
            ############################################################
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

            ############################################################
            ## GitHub Actions schema validation                       ##
            ############################################################
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

      ############################################################################
      ## Checks for *this* flake (consuming its own mkPrecommitCheck)
      ## This allows devShell to inherit shellHook and enabledPackages.
      ############################################################################
      checks = forAllSystems (system: {
        pre-commit-check = self.lib.mkPrecommitCheck {
          inherit system;
          src = ./.;
          extraExcludes = [ ];
        };
      });

      ############################################################################
      ## DevShells: generate .pre-commit-config.yaml on nix develop
      ############################################################################
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          # This is now guaranteed to exist because we defined checks above
          inherit (self.checks.${system}.pre-commit-check)
            shellHook
            enabledPackages
            ;
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              enabledPackages
              ++ (with pkgs; [
                pre-commit
                check-jsonschema
                codespell
                typos
                nixfmt
                nodePackages.markdownlint-cli2
              ]);

            shellHook = ''
              # Automatically generate .pre-commit-config.yaml
              ${shellHook}

              alias pre-commit="pre-commit run --all-files"
            '';
          };
        }
      );
    };
}
