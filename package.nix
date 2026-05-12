{
  lib,
  fetchzip,
  php84,
  dataDir ? "/var/lib/lychee",
}:

let
  php = php84.buildEnv {
    extensions = { enabled, all }:
      enabled
      ++ (with all; [
        bcmath
        exif
        gd
        pdo_pgsql
        pgsql
      ]);
  };
in
php.buildComposerProject2 (finalAttrs: {
  pname = "lycheePhotos";
  version = "7.5.4";

  src = fetchzip {
    url = "https://github.com/LycheeOrg/Lychee/releases/download/v${finalAttrs.version}/Lychee.zip";
    hash = "sha256-3fgAWhEx2oRLrIJwWUqI+4SpscrqnduyPlL7ymw3mqM=";
  };

  vendorHash = "sha256-hqW2yVQeNr7eQPZk3C8M2m4cp4fF8gs1WQVlVi3ItRg=";

  composerNoScripts = true;
  composerNoDev = true;

  passthru.phpPackage = php;

  postInstall = ''
    # Move files out of the default share/php/lychee structure
    mv $out/share/php/${finalAttrs.pname}/* $out/
    rm -rf $out/share

    # Remove writable directories and replace with symlinks to dataDir
    rm -rf $out/storage
    ln -s ${dataDir}/storage $out/storage

    rm -rf $out/bootstrap/cache
    ln -s ${dataDir}/bootstrap-cache $out/bootstrap/cache

    rm -rf $out/public/uploads
    ln -s ${dataDir}/public/uploads $out/public/uploads

    rm -rf $out/public/dist
    ln -s ${dataDir}/public/dist $out/public/dist

    # Symlink .env to dataDir
    ln -s ${dataDir}/.env $out/.env
  '';

  meta = {
    description = "Self-hosted photo-management done right";
    homepage = "https://lycheeorg.github.io/";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
