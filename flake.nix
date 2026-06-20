{
  description = "Self-hosted photo-management done right";

  inputs = {
    nixpkgs.url = "nixpkgs/26.05";
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
          lycheePhotos = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.lycheePhotos;
        });

      nixosModules = {
        lychee = import ./module.nix;
        default = self.nixosModules.lychee;
      };

      overlays = {
        default = final: prev: {
          lycheePhotos = self.packages.${final.system}.lycheePhotos;
        };
      };

      checks = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          integration = pkgs.callPackage ./test.nix {
            lycheeModule = self.nixosModules.lychee;
            lycheePackage = self.packages.${system}.lycheePhotos;
          };
        });
    };
}
