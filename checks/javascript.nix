{
  pkgs,
  extraExcludes ? [ ],
  enableBiome ? true,
  enableTsc ? false,
  tsConfig ? "tsconfig.json$",
}:

let
  excludes = extraExcludes;

  # TypeScript 7 (the Go port) is what this ruleset targets. Which attribute
  # carries it depends on the consumer's nixpkgs, because consumers set
  # `inputs.nixpkgs.follows` and therefore pick the attribute set, not us:
  #
  #   * newer nixpkgs — `typescript` IS the Go port (7.x) and `typescript-go`
  #     was removed, so referencing the latter is a fatal eval error.
  #   * older nixpkgs — `typescript` is the 5.x TypeScript and the Go port
  #     lives under `typescript-go`.
  #
  # Select on the version rather than on attribute existence: the removed
  # `typescript-go` alias still *exists* as an attribute whose value throws,
  # so `pkgs ? typescript-go` and `or` fallbacks do not help. Testing
  # `typescript.version` first keeps the throwing branch unevaluated.
  tscPackage =
    if pkgs.lib.versionAtLeast pkgs.typescript.version "7" then pkgs.typescript else pkgs.typescript-go;

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
        entry = "${tscPackage}/bin/tsc";
        args = [
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
    (pkgs.lib.optional enableBiome pkgs.biome) ++ (pkgs.lib.optional enableTsc tscPackage);

  passthru = {
    devPackages =
      (pkgs.lib.optional enableBiome pkgs.biome) ++ (pkgs.lib.optional enableTsc tscPackage);
    libPath = [ ];
  };
}
