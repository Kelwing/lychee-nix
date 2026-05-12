{
  pkgs,
  lycheeModule,
  lycheePackage,
}:

let
  # Pre-generated APP_KEY for testing
  secretsFile = pkgs.writeText "lychee-secrets" "APP_KEY=base64:t3TDcMLCOu/h30gkdPZSTmNJCun7FMaHKjGVMDKYq0Y=\n";
in
pkgs.testers.nixosTest {
  name = "lychee";

  nodes.machine =
    { ... }:
    {
      imports = [ lycheeModule ];

      nixpkgs.overlays = [
        (_final: _prev: {
          lycheePhotos = lycheePackage;
        })
      ];

      services.lychee = {
        enable = true;
        hostName = "localhost";
        secretsFile = secretsFile;
        settings = {
          APP_URL = "http://localhost";
        };
      };

      # Adequate resources for the VM
      virtualisation.memorySize = 1024;
    };

  testScript = ''
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("lychee-setup.service")
    machine.wait_for_unit("phpfpm-lychee.service")
    machine.wait_for_unit("nginx.service")

    # Verify data directories were created
    machine.succeed("test -d /var/lib/lychee/storage")
    machine.succeed("test -d /var/lib/lychee/storage/framework/sessions")
    machine.succeed("test -d /var/lib/lychee/public/uploads/big")
    machine.succeed("test -d /var/lib/lychee/bootstrap-cache")

    # Verify .env was generated
    machine.succeed("test -f /var/lib/lychee/.env")
    machine.succeed("grep -q APP_KEY /var/lib/lychee/.env")

    # Verify Lychee responds. A fresh install redirects to /install/admin,
    # so follow redirects to reach a page that mentions Lychee.
    machine.wait_until_succeeds("curl -sfL http://localhost/ | grep -qi lychee", timeout=30)
  '';
}
