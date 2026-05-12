{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.lychee;
  pkg = cfg.package.override { inherit (cfg) dataDir; };
  php = pkg.passthru.phpPackage;

  envFile = pkgs.writeText "lychee-env" (lib.generators.toKeyValue { } cfg.settings);
in
{
  options.services.lychee = {
    enable = lib.mkEnableOption "Lychee photo gallery";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lycheePhotos;
      defaultText = lib.literalExpression "pkgs.lycheePhotos";
      description = "The Lychee package to use.";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "FQDN for the Lychee instance.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lychee";
      description = "Directory for Lychee writable data (uploads, storage, cache).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "lychee";
      description = "User account under which Lychee runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "lychee";
      description = "Group under which Lychee runs.";
    };

    maxUploadSize = lib.mkOption {
      type = lib.types.str;
      default = "100M";
      description = "Maximum upload size for photos. Applied to both nginx and PHP.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int lib.types.bool ]);
      default = { };
      description = ''
        Key-value pairs for the Lychee .env file.
        These are non-secret configuration values. For secrets like APP_KEY,
        use the {option}`secretsFile` option.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing secret environment variables (one per line).
        This file should contain at minimum `APP_KEY=base64:...`.
        Generate a key with: `php artisan key:generate --show`
        The file is appended to the .env at runtime, keeping secrets out of the Nix store.
      '';
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create a local PostgreSQL database for Lychee.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "/run/postgresql";
        description = "Database host. Use a socket path for local connections.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Database port.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "lychee";
        description = "Database name.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "lychee";
        description = "Database user.";
      };
    };

    poolConfig = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int lib.types.bool ]);
      default = { };
      description = "Additional PHP-FPM pool configuration for Lychee.";
    };

    nginx = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Extra nginx virtualHost configuration for the Lychee vhost.
        Use this to enable ACME, SSL, or other nginx settings.
        Example: `{ enableACME = true; forceSSL = true; }`
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    services.lychee.settings = {
      APP_ENV = lib.mkDefault "production";
      APP_DEBUG = lib.mkDefault "false";
      APP_URL = lib.mkDefault "https://${cfg.hostName}";
      DB_CONNECTION = lib.mkDefault "pgsql";
      DB_HOST = lib.mkDefault cfg.database.host;
      DB_PORT = lib.mkDefault cfg.database.port;
      DB_DATABASE = lib.mkDefault cfg.database.name;
      DB_USERNAME = lib.mkDefault cfg.database.user;
      CACHE_DRIVER = lib.mkDefault "file";
      SESSION_DRIVER = lib.mkDefault "file";
      QUEUE_CONNECTION = lib.mkDefault "sync";
      LYCHEE_UPLOADS = lib.mkDefault "${cfg.dataDir}/public/uploads";
      LYCHEE_UPLOADS_URL = lib.mkDefault "uploads";
      LYCHEE_DIST = lib.mkDefault "${cfg.dataDir}/public/dist";
      LYCHEE_DIST_URL = lib.mkDefault "dist";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = { };

    users.users.${config.services.nginx.user}.extraGroups = [ cfg.group ];

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.tmpfiles.settings."10-lychee" =
      let
        dir = {
          user = cfg.user;
          group = cfg.group;
          mode = "0750";
        };
      in
      {
        "${cfg.dataDir}".d = dir;
        "${cfg.dataDir}/storage".d = dir;
        "${cfg.dataDir}/storage/app".d = dir;
        "${cfg.dataDir}/storage/framework".d = dir;
        "${cfg.dataDir}/storage/framework/cache".d = dir;
        "${cfg.dataDir}/storage/framework/sessions".d = dir;
        "${cfg.dataDir}/storage/framework/views".d = dir;
        "${cfg.dataDir}/storage/logs".d = dir;
        "${cfg.dataDir}/bootstrap-cache".d = dir;
        "${cfg.dataDir}/public".d = dir;
        "${cfg.dataDir}/public/uploads".d = dir;
        "${cfg.dataDir}/public/uploads/big".d = dir;
        "${cfg.dataDir}/public/uploads/medium".d = dir;
        "${cfg.dataDir}/public/uploads/small".d = dir;
        "${cfg.dataDir}/public/uploads/thumb".d = dir;
        "${cfg.dataDir}/public/uploads/import".d = dir;
        "${cfg.dataDir}/public/uploads/raw".d = dir;
        "${cfg.dataDir}/public/dist".d = dir;
        "${cfg.dataDir}/public/dist/fonts".d = dir;
        "${cfg.dataDir}/public/dist/resources".d = dir;
      };

    systemd.services.lychee-setup = {
      description = "Lychee setup and migration";
      wantedBy = [ "multi-user.target" ];
      before = [ "phpfpm-lychee.service" ];
      after = lib.optional cfg.database.createLocally "postgresql.service";
      requires = lib.optional cfg.database.createLocally "postgresql.service";

      path = [
        php
        pkgs.ffmpeg
        pkgs.exiftool
      ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = pkg;
        RemainAfterExit = true;
        PrivateTmp = true;
      };

      script = ''
        # Generate .env file
        install -m 0600 ${envFile} ${cfg.dataDir}/.env

        ${lib.optionalString (cfg.secretsFile != null) ''
          cat ${cfg.secretsFile} >> ${cfg.dataDir}/.env
        ''}

        # Run Laravel setup commands
        php ${pkg}/artisan migrate --force
        php ${pkg}/artisan config:cache
        php ${pkg}/artisan route:cache
        php ${pkg}/artisan view:cache
      '';
    };

    services.phpfpm.pools.lychee = {
      user = cfg.user;
      group = cfg.group;
      phpPackage = php;

      phpOptions = ''
        upload_max_filesize = ${cfg.maxUploadSize}
        post_max_size = ${cfg.maxUploadSize}
        memory_limit = 300M
        max_execution_time = 200
      '';

      settings = {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
        "listen.mode" = "0660";
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
        "catch_workers_output" = true;
      } // cfg.poolConfig;

      phpEnv = {
        PATH = lib.makeBinPath [
          php
          pkgs.ffmpeg
          pkgs.exiftool
        ];
      };
    };

    systemd.services.phpfpm-lychee = {
      after = [ "lychee-setup.service" ];
      requires = [ "lychee-setup.service" ];
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.hostName} = lib.mkMerge [
        cfg.nginx
        {
          root = lib.mkForce "${pkg}/public";

          extraConfig = ''
            client_max_body_size ${cfg.maxUploadSize};
            index index.php;
          '';

          locations."/" = {
            tryFiles = "$uri $uri/ /index.php?$query_string";
          };

          locations."~ \\.php$" = {
            extraConfig = ''
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_pass unix:${config.services.phpfpm.pools.lychee.socket};
              fastcgi_index index.php;
              include ${config.services.nginx.package}/conf/fastcgi_params;
              include ${config.services.nginx.package}/conf/fastcgi.conf;
              fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
            '';
          };

          locations."/uploads/" = {
            alias = "${cfg.dataDir}/public/uploads/";
          };

          locations."/dist/" = {
            alias = "${cfg.dataDir}/public/dist/";
          };

          locations."~ /\\.(?!well-known).*" = {
            extraConfig = "deny all;";
          };
        }
      ];
    };
  };
}
