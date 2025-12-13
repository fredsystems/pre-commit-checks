{
  pkgs,
  extraExcludes ? [ ],
}:

let
  hadolintConfig = pkgs.writeTextFile {
    name = "hadolint.yaml";
    text = ''
      failure-threshold: warning
      ignored:
        - DL3008  # pin versions
        - DL3018  # pin apk versions
    '';
  };

  baseExcludes = [
    "^.*\\.png$"
    "^.*\\.jpg$"
  ];

  excludes = baseExcludes ++ extraExcludes;

  hooks = {
    hadolint = {
      enable = true;
      args = [
        "--config"
        "${hadolintConfig}"
      ];
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
