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
    hadolint.enable = true;
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
