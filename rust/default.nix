# rust/default.nix
{
  system,
  src,
  pkgs,
  git-hooks,

  # Optional: extra excludes appended to default Rust ignores
  extraExcludes ? [ ],

  # Optional: extra runtime library deps (only needed for GUI, eframe, wgpu)
  extraLibPathPkgs ? [ ],

  # Optional: extra dev packages (cargo-deny, cargo-llvm-cov, etc.)
  extraPackages ? [ ],

  # Optional: enable xtask (off by default)
  enableXtask ? false,
}:

let
  # Default Rust excludes — generic + extendable
  defaultExcludes = [
    "^target/"
    "^Cargo.lock$"
    "\\.profraw$"
    "^dist/"
  ];

  excludes = defaultExcludes ++ extraExcludes;

  # Optional LD_LIBRARY_PATH construction
  libPath = pkgs.lib.makeLibraryPath extraLibPathPkgs;

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

    # Optional xtask hook
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

  # 👈 Run the real git-hooks derivation
  run = git-hooks.lib.${system}.run {
    inherit src excludes hooks;
  };

in
# 👈 Extend the result SAFELY using //
run
// {
  passthru = {
    inherit rustToolchain libPath;
    devPackages = [ rustToolchain ] ++ extraPackages;
  };
}
