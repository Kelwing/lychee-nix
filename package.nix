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

  postInstall = let appDir = "$out/share/php/${finalAttrs.pname}"; in ''
    # Remove writable directories and replace with symlinks to dataDir
    rm -rf ${appDir}/storage
    ln -s ${dataDir}/storage ${appDir}/storage

    rm -rf ${appDir}/bootstrap/cache
    ln -s ${dataDir}/bootstrap-cache ${appDir}/bootstrap/cache

    rm -rf ${appDir}/public/uploads
    ln -s ${dataDir}/public/uploads ${appDir}/public/uploads

    rm -rf ${appDir}/public/dist
    ln -s ${dataDir}/public/dist ${appDir}/public/dist

    # Symlink .env to dataDir
    ln -s ${dataDir}/.env ${appDir}/.env
  '';

  meta = {
    description = "Self-hosted photo-management done right";
    homepage = "https://lycheeorg.github.io/";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
