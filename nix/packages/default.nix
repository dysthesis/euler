{
  perSystem = {pkgs, ...}: {
    packages = rec {
      euler = pkgs.callPackage ./euler.nix {};
      default = euler;
    };
  };
}
