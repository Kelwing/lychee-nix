{
  description = "Self-hosted photo-management done right";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          lychee = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.lychee;
        });

      nixosModules = {
        lychee = import ./module.nix;
        default = self.nixosModules.lychee;
      };

      overlays = {
        default = final: prev: {
          lychee = self.packages.${final.system}.lychee;
        };
      };

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          integration = pkgs.callPackage ./test.nix {
            lycheeModule = self.nixosModules.lychee;
            lycheePackage = self.packages.${system}.lychee;
          };
        });
    };
}
