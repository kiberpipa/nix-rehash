{ config, pkgs, ... }:
with pkgs.lib;
let
  serviceOpts = { name, config, ...}: {
    options = {
      command = mkOption {
        description = "The command to execute";
      };
      directory = mkOption {
        default = "/";
        description = "Current directory when running the command";
      };
      environment = mkOption {
        default = {};
        example = {
          PATH = "/some/path";
        };
      };
      startsecs = mkOption {
        default = 1;
        example = 0;
      };
    };
  };
  services = config.supervisord.services;
in {
  options = {
    supervisord = {
      enable = mkOption {
        default = true;
        type = types.bool;
      };

      services = mkOption {
        default = {};
        type = types.loaOf types.optionSet;
        description = ''
          Supervisord services to start
        '';
        options = [ serviceOpts ];
      };

      tailLogs = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether or not to tail all logs to standard out.
        '';
      };

      configFile = mkOption {};
    };
  };

  config = mkIf config.supervisord.enable {
    supervisord.configFile = pkgs.writeText "supervisord.conf" ''
      [supervisord]
      logfile=/tmp/supervisor/var/log/supervisord/supervisord.log

      ${concatMapStrings (name:
        let
          cfg = getAttr name services;
        in
          ''
          [program:${name}]
          command=${cfg.command}
          environment=${concatMapStrings (name: "${name}=\"${toString (getAttr name cfg.environment)}\",") (attrNames cfg.environment)}
          directory=${cfg.directory}
          redirect_stderr=true
          stdout_logfile=/tmp/supervisor/var/log/supervisord/${name}.log
          startsecs=${toString cfg.startsecs}
          ''
        ) (attrNames services)
      }
    '';

    userNix.startScript = let
      systemPackages = config.environment.systemPackages;
      systemEnv = pkgs.buildEnv { name = "system-env"; paths = systemPackages; };
    in ''
      mkdir -p /tmp/supervisor/var/log/supervisord
      export PATH="${systemEnv}/bin:${systemEnv}/sbin"
      ${pkgs.pythonPackages.supervisor}/bin/supervisord -c ${config.supervisord.configFile} ${if config.supervisord.tailLogs then ''

        sleep 2
        touch $(pwd)/var/log/supervisord/test.log
        tail -n 100 -f /var/log/supervisord/*.log
      '' else "-n"}
    '';
  };
}
