{
  description = "Fred's shared base pre-commit flake";

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
      supportedSystems = systems;
      ##########################################################################
      ## Library exports
      ##########################################################################
      lib.mkPrecommitCheck =
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
            git-hooks
            extraExcludes
            pkgs
            ;
        };

      ##########################################################################
      ## Checks for this flake
      ##########################################################################
      checks = forAllSystems (system: {
        supportedSystems = systems;

        pre-commit-check = self.lib.mkPrecommitCheck {
          inherit system;
          src = ./.;
          extraExcludes = [ ];
        };

        lib.mkRustPrecommitCheck =
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
              overlays = [
                (import rust-overlay)
              ];
            };
          in
          import ./rust/default.nix {
            inherit
              system
              src
              pkgs
              extraExcludes
              extraLibPathPkgs
              extraPackages
              enableXtask
              git-hooks
              ;
          };
      });

      ##########################################################################
      ## DevShells for this flake (auto-generate .pre-commit-config.yaml)
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
