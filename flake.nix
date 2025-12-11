{
  description = "Fred's shared base + rust pre-commit flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
      flake-utils,
      rust-overlay,
      ...
    }:
    let
      systems = flake-utils.lib.defaultSystems;
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {

      ##########################################################################
      ## Library exports (this is what consumer repos import)
      ##########################################################################

      lib = {

        supportedSystems = systems;

        mkPrecommitCheck =
          {
            system,
            src,
            extraExcludes ? [ ],
          }:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          import ./base/default.nix {
            inherit
              system
              src
              pkgs
              git-hooks
              extraExcludes
              ;
          };

        mkRustPrecommitCheck =
          {
            system,
            src,
            extraExcludes ? [ ],
            extraLibPathPkgs ? [ ],
            extraPackages ? [ ],
            enableXtask ? false,
          }:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ (import rust-overlay) ];
            };
          in
          import ./rust/default.nix {
            inherit
              system
              src
              pkgs
              git-hooks
              extraExcludes
              extraLibPathPkgs
              extraPackages
              enableXtask
              ;
          };
      };

      ##########################################################################
      ## Checks for *this repo only*
      ## (Only run base precommit, no rust)
      ##########################################################################

      checks = forAllSystems (system: {
        pre-commit-check = self.lib.mkPrecommitCheck {
          inherit system;
          src = ./.;
        };
      });

      ##########################################################################
      ## DevShells for this repo (auto-generates .pre-commit-config.yaml)
      ##########################################################################

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
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
              ${shellHook}
              alias pre-commit="pre-commit run --all-files"
            '';
          };
        }
      );
    };
}
