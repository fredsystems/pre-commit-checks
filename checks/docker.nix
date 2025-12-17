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
        - DL3007  # don't use latest tag
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

      files = "(^|/)Dockerfile.*+$|\\.Dockerfile$";
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
