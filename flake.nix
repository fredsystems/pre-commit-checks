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

      inherit (nixpkgs) lib;

      # ──────────────────────────────────────────────────────────────
      # Normalize + merge helpers
      # ──────────────────────────────────────────────────────────────
      normalize = m: {
        hooks = m.hooks or { };
        excludes = m.excludes or [ ];
        passthru = {
          devPackages = m.passthru.devPackages or [ ];
          libPath = m.passthru.libPath or [ ];
        };
      };

      mergeModules =
        modules:
        let
          ms = map normalize modules;
        in
        {
          hooks = lib.foldl' (a: b: a // b.hooks) { } ms;
          excludes = lib.concatLists (map (m: m.excludes) ms);
          passthru = {
            devPackages = lib.concatLists (map (m: m.passthru.devPackages) ms);
            libPath = lib.concatLists (map (m: m.passthru.libPath) ms);
          };
        };
    in
    {
      # ──────────────────────────────────────────────────────────────
      # Public library
      # ──────────────────────────────────────────────────────────────
      lib = {
        supportedSystems = systems;

        mkBaseCheck =
          {
            system,
            extraExcludes ? [ ],
          }:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          import ./checks/base.nix { inherit pkgs extraExcludes; };

        mkRustCheck =
          {
            system,
            extraExcludes ? [ ],
            enableXtask ? false,
            xtaskType ? "ci",
            extraLibPathPkgs ? [ ],
          }:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ (import rust-overlay) ];
            };
          in
          import ./checks/rust.nix {
            inherit
              pkgs
              extraExcludes
              enableXtask
              xtaskType
              extraLibPathPkgs
              ;
          };

        mkDockerCheck =
          {
            system,
            extraExcludes ? [ ],
          }:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          import ./checks/docker.nix { inherit pkgs extraExcludes; };

        mkPythonCheck =
          {
            system,
            extraExcludes ? [ ],
            enableBlack ? true,
            enableFlake8 ? true,
          }:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          import ./checks/python.nix {
            inherit
              pkgs
              extraExcludes
              enableBlack
              enableFlake8
              ;
          };

        mkJavascriptCheck =
          {
            system,
            extraExcludes ? [ ],
            enableBiome ? true,
            enableTsc ? false,
            tsConfig ? "tsconfig.json",
          }:
          let
            pkgs = import nixpkgs { inherit system; };
          in
          import ./checks/javascript.nix {
            inherit
              pkgs
              extraExcludes
              enableBiome
              enableTsc
              tsConfig
              ;
          };

        # ──────────────────────────────────────────────────────────────
        # MASTER ENTRY POINT
        # ──────────────────────────────────────────────────────────────
        mkCheck =
          {
            system,
            src,
            extraExcludes ? [ ],
            extraLibPathPkgs ? [ ],

            check_rust ? false,
            check_docker ? false,
            check_python ? false,
            check_javascript ? false,

            enableXtask ? false,

            rust_options ? {
              xtaskCheck = "ci";
            },

            python ? {
              enableBlack = true;
              enableFlake8 = true;
            },

            javascript ? {
              enableBiome = true;
              enableTsc = false;
              tsConfig = "tsconfig.json";
            },
          }:
          let
            base = self.lib.mkBaseCheck { inherit system extraExcludes; };

            rust =
              if check_rust then
                self.lib.mkRustCheck {
                  inherit
                    system
                    extraExcludes
                    enableXtask
                    extraLibPathPkgs
                    ;
                  xtaskType = rust_options.xtaskCheck or "ci";
                }
              else
                null;

            docker = if check_docker then self.lib.mkDockerCheck { inherit system extraExcludes; } else null;

            pythonCheck =
              if check_python then
                self.lib.mkPythonCheck {
                  inherit system extraExcludes;
                  inherit (python) enableBlack enableFlake8;
                }
              else
                null;

            javascriptCheck =
              if check_javascript then
                self.lib.mkJavascriptCheck {
                  inherit system extraExcludes;
                  inherit (javascript) enableBiome enableTsc tsConfig;
                }
              else
                null;

            modules = [
              base
            ]
            ++ lib.optionals (rust != null) [ rust ]
            ++ lib.optionals (docker != null) [ docker ]
            ++ lib.optionals (pythonCheck != null) [ pythonCheck ]
            ++ lib.optionals (javascriptCheck != null) [ javascriptCheck ];

            merged = mergeModules modules;

            run = git-hooks.lib.${system}.run {
              inherit src;
              inherit (merged) hooks;
              inherit (merged) excludes;
            };
          in
          run
          // {
            inherit (merged) passthru;
            shellHook = run.shellHook or "";
            enabledPackages = run.enabledPackages or [ ];
          };
      };

      ##############################################################################
      ## CHECKS FOR *THIS* REPO
      ##
      ## These double as a "does the exported hook suite still build?" gate.
      ## Every variant a consumer can request via `lib.mkCheck` is instantiated
      ## here against this repo's own source, so CI (linux + darwin) proves that
      ## a PR will not break the hook suite for downstream consumers: every hook
      ## binary must resolve and the git-hooks run derivation must build.
      ##############################################################################
      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          mk =
            args:
            self.lib.mkCheck (
              {
                inherit system;
                src = ./.;
              }
              // args
            );
        in
        {
          # Back-compat: the original python variant.
          pre-commit = mk { check_python = true; };

          # Base hooks only (no language bundles).
          suite-base = mk { };

          # Each language bundle layered on top of the base.
          suite-python = mk { check_python = true; };
          suite-rust = mk { check_rust = true; };
          suite-docker = mk { check_docker = true; };
          suite-javascript = mk { check_javascript = true; };

          # Everything at once: the maximal hook set a consumer could enable.
          suite-all = mk {
            check_rust = true;
            check_docker = true;
            check_python = true;
            check_javascript = true;
          };
        }
      );

      ##############################################################################
      ## DEV SHELL FOR THIS REPO
      ##############################################################################
      devShells = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          chk = self.checks.${system}.pre-commit;
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              chk.enabledPackages
              ++ (with pkgs; [
                pre-commit
                check-jsonschema
                codespell
                typos
                nixfmt
                markdownlint-cli2
              ]);

            shellHook = ''
              ${chk.shellHook}
              alias pre-commit="pre-commit run --all-files"
            '';
          };
        }
      );
    };
}
