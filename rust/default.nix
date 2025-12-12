# rust/default.nix
{
  system,
  src,
  pkgs,
  git-hooks,

  extraExcludes ? [ ],
  extraLibPathPkgs ? [ ],
  extraPackages ? [ ],
  enableXtask ? false,
}:

let
  defaultExcludes = [
    "^target/"
    "^Cargo.lock$"
    "\\.profraw$"
    "^dist/"
  ];

  excludes = defaultExcludes ++ extraExcludes;

  libPath = extraLibPathPkgs;

  rustToolchain = pkgs.rust-bin.fromRustupToolchain {
    channel = "stable";
    components = [
      "rustc"
      "cargo"
      "clippy"
      "rustfmt"
      "rust-analyzer"
      "rust-src"
      "llvm-tools-preview"
    ];
  };

  hooks = {
    rustfmt = {
      enable = true;
      entry = "${rustToolchain}/bin/cargo";
      args = [
        "fmt"
        "--all"
      ];
    };

    clippy = {
      enable = true;
      entry = "${rustToolchain}/bin/cargo";
      args = [
        "clippy"
        "--workspace"
        "--all-targets"
      ];
      pass_filenames = false;
    };

    xtask-check = pkgs.lib.optionalAttrs enableXtask {
      enable = true;
      entry = "${rustToolchain}/bin/cargo";
      args = [
        "xtask"
        "ci"
      ];
      pass_filenames = false;
    };
  };

  # Main git-hooks derivation
  run = git-hooks.lib.${system}.run {
    inherit src excludes hooks;
  };

in
{
  inherit (run)
    shellHook
    enabledPackages
    ;

  passthru = {
    inherit rustToolchain libPath;
    devPackages = [ rustToolchain ] ++ extraPackages;
  };
}
