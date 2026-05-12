{
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      name = "euler-dev";
      packages = with pkgs; [
        # Nix tooling
        nil # LSP
        statix # static analyser
        deadnix # dead code analyser
        alejandra # formatter

        npins # As a replacement for package-vc

        grim
        slurp
        swappy
        defuddle-cli
      ];
    };
  };
}
