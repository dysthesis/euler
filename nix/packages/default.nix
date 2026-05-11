{
  perSystem = {pkgs, ...}: {
    packages = rec {
      # Just the config directory
      cfg = pkgs.callPackage ./cfg.nix {};

      # Emacs wrapped with whatever packages it needs
      emacsWithPackages = pkgs.callPackage ./emacsWithPackages.nix {inherit cfg;};

      # Emacs with packages and config
      euler = pkgs.callPackage ./euler.nix {inherit emacsWithPackages cfg;};
      default = euler;
    };
  };
}
