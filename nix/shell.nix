{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      name = "euler-dev";
      packages = [
        # Nix tooling
        pkgs.nil # LSP
        pkgs.statix # static analyser
        pkgs.deadnix # dead code analyser
        pkgs.alejandra # formatter

        pkgs.npins # As a replacement for package-vc

        pkgs.grim
        pkgs.slurp
        pkgs.swappy
        pkgs.defuddle-cli

        config.packages.ellsp
      ];
    };
  };
}
