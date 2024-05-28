{
  description = "A very basic flake";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    unstable-nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    crane = {
      url = "github:ipetkov/crane/v0.17.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = inputs: inputs.flake-utils.lib.eachSystem [ "x86_64-linux" ]
    (system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
              (import inputs.rust-overlay)
            ];
        };

        rustTarget = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustTarget;

        tomlInfo = craneLib.crateNameFromCargoToml { cargoToml = ./Cargo.toml; };
        inherit (tomlInfo) version;
        pname = "test-crane-gitrev";

        src =
          let
            nixFilter = path: _type: !pkgs.lib.hasSuffix ".nix" path;
            extraFiles = path: _type: !(builtins.any (n: pkgs.lib.hasSuffix n path) [ ".github" ".sh" ]);
            filterPath = path: type: builtins.all (f: f path type) [
              nixFilter
              extraFiles
              pkgs.lib.cleanSourceFilter
            ];
          in
          pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = filterPath;
          };

        cargoArtifacts = craneLib.buildDepsOnly {
          inherit src pname;
          buildInputs = [];
        };

        binary = craneLib.buildPackage {
          inherit cargoArtifacts src pname version;
          cargoExtraArgs = "--all-features";
          buildInputs = [];
        };

      in
      rec {
        checks = {
          inherit binary;
        };

        packages = {
          default = packages.binary;
          inherit binary;
        };

        devShells.default = devShells.shell;
        devShells.shell = pkgs.mkShell {
          nativeBuildInputs = [
            rustTarget
          ];
        };
      }
    );
}
