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
