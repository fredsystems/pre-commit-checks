{
  description = "Fred's shared modular pre-commit framework";

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

      ################################################################################
      ## Helper: merge hook sets safely
      ################################################################################
      mergeHooks = hookSets: nixpkgs.lib.foldl' (acc: elem: acc // elem) { } hookSets;

      mergeExcludes = excludeSets: nixpkgs.lib.concatLists excludeSets;

      mergePassthru =
        passthruSets:
        let
          empty = {
            devPackages = [ ];
            libPath = [ ];
          };
          mergeTwo = a: b: {
            devPackages = a.devPackages or [ ] ++ b.devPackages or [ ];
            libPath = a.libPath or [ ] ++ b.libPath or [ ];
          };
        in
        nixpkgs.lib.foldl' mergeTwo empty passthruSets;
    in
    {
      lib = {

        supportedSystems = systems;

        ############################################################################
        ## BASE CHECKS
        ############################################################################
        mkBaseCheck =
          {
            system,
            extraExcludes ? [ ],
          }:
          let
            pkgs = import nixpkgs { inherit system; };

            # Load base checks file
            base = import ./checks/base.nix {
              inherit
                pkgs
                extraExcludes
                ;
            };
          in
          base
          // {
            shellHook = base.shellHook or "";
            enabledPackages = base.enabledPackages or [ ];
            passthru =
              base.passthru or {
                devPackages = [ ];
                libPath = [ ];
              };
          };

        ############################################################################
        ## RUST CHECKS
        ############################################################################
        mkRustCheck =
          {
            system,
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

            rust = import ./checks/rust.nix {
              inherit
                pkgs
                extraExcludes
                extraLibPathPkgs
                extraPackages
                enableXtask
                ;
            };
          in
          rust
          // {
            shellHook = rust.shellHook or "";
            enabledPackages = rust.enabledPackages or [ ];
            passthru =
              rust.passthru or {
                devPackages = [ ];
                libPath = [ ];
              };
          };

        ############################################################################
        ## MASTER MODULAR CHECK
        ##
        ## Consumer chooses what to enable:
        ##
        ##   lib.mkCheck {
        ##     system = "x86_64-linux";
        ##     src = ./.;
        ##     check_rust = true;
        ##     check_docker = false;
        ##   }
        ############################################################################
        mkCheck =
          {
            system,
            check_rust ? false,
            extraExcludes ? [ ],
          }:
          let
            base = self.lib.mkBaseCheck { inherit system extraExcludes; };
            rust = if check_rust then self.lib.mkRustCheck { inherit system extraExcludes; } else null;

            hooks = mergeHooks ([ base.hooks ] ++ (if rust != null then [ rust.hooks ] else [ ]));

            excludes = mergeExcludes ([ base.excludes ] ++ (if rust != null then [ rust.excludes ] else [ ]));

            passthru = mergePassthru (
              [ base.passthru or { } ] ++ (if rust != null then [ rust.passthru or { } ] else [ ])
            );

            run = git-hooks.lib.${system}.run {
              inherit hooks excludes;

              src = ./.;
            };

          in
          run
          // {
            passthru = passthru // {
              inherit hooks excludes;
            };

            shellHook = run.shellHook or "";
            enabledPackages = run.enabledPackages or [ ];
          };
      };

      ##############################################################################
      ## CHECKS FOR THIS REPO ITSELF (base only)
      ##############################################################################
      checks = nixpkgs.lib.genAttrs systems (system: {
        pre-commit-check = self.lib.mkCheck {
          inherit system;
          check_rust = false;
        };
      });

      #############################################################################
      ## DEV SHELLS — use only base checks for this repo
      #############################################################################
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          chk = self.checks.${system}.pre-commit-check;
          devPkgs =
            (chk.passthru.devPackages or [ ])
            ++ chk.enabledPackages
            ++ (with pkgs; [
              pre-commit
              check-jsonschema
              codespell
              typos
              nixfmt
              nodePackages.markdownlint-cli2
            ]);

          libPath = pkgs.lib.makeLibraryPath (chk.passthru.libPath or [ ]);
        in
        {
          default = pkgs.mkShell {
            buildInputs = devPkgs;

            LD_LIBRARY_PATH = libPath;

            shellHook = ''
              ${chk.shellHook}
              alias pre-commit="pre-commit run --all-files"
            '';
          };
        }
      );
    };
}
