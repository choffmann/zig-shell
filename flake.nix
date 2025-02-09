{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    overlays = [
      # Other overlays
      (final: prev: {
        zigpkgs = inputs.zig.packages.${prev.system};
      })
    ];

    systems = builtins.attrNames inputs.zig.packages;
  in (flake-utils.lib.eachSystem systems
    (
      system: let
        pkgs = import nixpkgs {inherit overlays system;};
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            zigpkgs.master
          ];
        };
      }
    ));
}
