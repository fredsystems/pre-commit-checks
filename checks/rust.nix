{
  pkgs,
  extraExcludes ? [ ],
  extraLibPathPkgs ? [ ],
  extraPackages ? [ ],
  enableXtask ? false,
  xtaskType ? "ci",
}:

let
  defaultExcludes = [
    "^target/"
    "^Cargo.lock$"
    "\\.profraw$"
  ];

  excludes = defaultExcludes ++ extraExcludes;

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
        xtaskType
      ];
      pass_filenames = false;
    };
  };
in
{
  inherit hooks excludes;

  enabledPackages = [ ];
  passthru = {
    inherit rustToolchain;
    devPackages = [ rustToolchain ] ++ extraPackages;
    libPath = extraLibPathPkgs;
  };
}
