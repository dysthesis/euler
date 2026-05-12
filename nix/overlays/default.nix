{withSystem, ...}: {
  flake.overlays.default = final: prev:
    withSystem prev.stdenv.hostPlatform.system (
      # perSystem parameters. Note that perSystem does not use `final` or `prev`.
      {config, ...}: {
        emacsPackages = prev.emacsPackages // config.packages.emacsPackages;
      }
    );
}
