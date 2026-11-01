{
  description = "Monorail by Ashforde®: the scrolling window manager for macOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: (nixpkgs.lib.getName pkg) == "monorail";
      }));
    in {
      packages = forAll (pkgs: rec {
        monorail = pkgs.callPackage ./packaging/nix/monorail.nix { };
        default = monorail;
      });
    };
}
