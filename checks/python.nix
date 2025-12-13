{
  extraExcludes ? [ ],
}:

let
  baseExcludes = [
    "^.*\\.png$"
    "^.*\\.jpg$"
  ];

  excludes = baseExcludes ++ extraExcludes;

  hooks = {
    black.enable = true;
    flake8.enable = true;
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
