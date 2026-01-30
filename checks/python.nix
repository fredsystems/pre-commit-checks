{
  extraExcludes ? [ ],
  enableBlack ? true,
  enableFlake8 ? true,
  ...
}:

let
  baseExcludes = [
    "^.*\\.png$"
    "^.*\\.jpg$"
  ];

  excludes = baseExcludes ++ extraExcludes;

  hooks = {
    black = {
      enable = enableBlack;
    };

    flake8 = {
      enable = enableFlake8;

      # This is the important part
      args = [
        "--ignore=E501,W503"
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
