{
  pkgs,
  extraExcludes ? [ ],
  enableBiome ? true,
  enableTsc ? false,
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
          "--apply=false"
        ];
      };
    }
    // pkgs.lib.optionalAttrs enableTsc {
      tsc = {
        enable = true;
        entry = "${pkgs.nodejs}/bin/node";
        args = [
          "${pkgs.typescript}/lib/node_modules/typescript/bin/tsc"
          "--noEmit"
        ];
        files = "tsconfig\\.json$";
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
