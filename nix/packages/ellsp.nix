{
  fetchFromGitHub,
  buildNpmPackage,
  writeShellScriptBin,
  emacsPackagesFor,
  emacs,
}: let
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "elisp-lsp";
    repo = "Ellsp";
    rev = "master";
		hash = "sha256-oNJtw4/8P5YdD3xRj6r9kMdvVwsbhn6iVOMyJibA0v8=";
  };

  epkgs = emacsPackagesFor emacs;

  msgu = epkgs.trivialBuild {
    pname = "msgu";
    version = "0.1.0";
    src = fetchFromGitHub {
      owner = "jcs-elpa";
      repo = "msgu";
      rev = "0.1.0";
      hash = "sha256-Jnse1nX+NtGbN39P/ug3PdB8/PdrMITFwACPHueOeZU=";
    };
  };

  ellspEl = epkgs.trivialBuild {
    pname = "ellsp";
    inherit version;
    inherit src;
    packageRequires = with epkgs; [
      lsp-mode
      company
      log4e
      dash
      s
      msgu
    ];
  };

  emacsWithEllsp = epkgs.withPackages (_: [
    ellspEl
  ]);

  ellspProxy = buildNpmPackage {
    pname = "ellsp-proxy";
    inherit version src;
    sourceRoot = "${src.name}/proxy";
    npmDepsHash = "sha256-9aIlBRFFgBcXdWfHYarWNSYLV9LPsxytBUr8xPmEp1o=";
    dontNpmBuild = true;
  };
in
  writeShellScriptBin "ellsp" ''
    export ELLSP_EMACS=${emacsWithEllsp}/bin/emacs
    exec ${ellspProxy}/bin/ellsp "$@"
  ''
