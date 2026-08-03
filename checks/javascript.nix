{
  pkgs,
  extraExcludes ? [ ],
  enableBiome ? true,
  enableTsc ? false,
  tsConfig ? "tsconfig.json$",
}:

let
  excludes = extraExcludes;

  hooks =
    { }
    // pkgs.lib.optionalAttrs enableBiome {
      biome = {
        enable = true;
        entry = "${pkgs.biome}/bin/biome";
        files = "\\.(js|jsx|ts|tsx)$";
        args = [
          "check"
        ];
      };
    }
    // pkgs.lib.optionalAttrs enableTsc {
      tsc = {
        enable = true;
        entry = "${pkgs.nodejs}/bin/node";
        args = [
          "${pkgs.typescript-go}/lib/node_modules/typescript/bin/tsc"
          "--build"
          tsConfig
        ];
        # files = tsConfig;
        pass_filenames = false;
      };
    };
in
{
  inherit hooks excludes;

  enabledPackages =
    (pkgs.lib.optional enableBiome pkgs.biome) ++ (pkgs.lib.optional enableTsc pkgs.typescript);

  passthru = {
    devPackages =
      (pkgs.lib.optional enableBiome pkgs.biome) ++ (pkgs.lib.optional enableTsc pkgs.typescript);
    libPath = [ ];
  };
}
