# Monorail by Ashforde® for Nix on macOS: `nix profile install github:ashfordeOU/monorail`,
# or with nix-darwin: environment.systemPackages = [ inputs.monorail.packages.${system}.default ];
{ lib, stdenvNoCC, fetchurl, unzip }:

stdenvNoCC.mkDerivation rec {
  pname = "monorail";
  version = "1.7.8";

  src = fetchurl {
    url = "https://github.com/ashfordeOU/monorail/releases/download/v${version}/Monorail-${version}.zip";
    hash = "sha256-ssvI0sJjlmLvKWJn+GDeIBzMnIfjRzu3Xnb1MvG5EPw=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontBuild = true;
  dontFixup = true; # keep the app's code signature intact

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -R Monorail.app $out/Applications/
    runHook postInstall
  '';

  meta = {
    description = "Scrolling window manager for macOS where nothing ever shrinks";
    homepage = "https://ashfordeou.github.io/monorail/";
    license = lib.licenses.unfreeRedistributable; # Functional Source License 1.1
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "Monorail";
  };
}
