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

        grim
        slurp
        swappy
        defuddle-cli
      ];
    };
  };
}
