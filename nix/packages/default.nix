{
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    emacs = pkgs.emacs-unstable-pgtk;

    emacsPackages = import ./emacsPackages {
      inherit pkgs emacs;
    };
  in {
    packages = rec {
      # Just the config directory
      cfg = pkgs.callPackage ./cfg.nix {};

      # Emacs wrapped with whatever packages it needs
      emacsWithPackages = pkgs.callPackage ./emacsWithPackages.nix {
        inherit
          cfg
          emacs
          ;
      };

      # Emacs with packages and config
      euler = pkgs.callPackage ./euler.nix {inherit emacsWithPackages cfg lib;};

      # Emacs packages that I use that are not in emacs-overlay or nixpkgs
      inherit emacsPackages;

      default = euler;
    };
  };
}
