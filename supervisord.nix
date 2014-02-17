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
      stopsignal = mkOption {
        default = "TERM";
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

      [supervisorctl]
      serverurl = http://localhost:64125

      [inet_http_server]
      port = 127.0.0.1:64125

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

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
          startsecs=${toString cfg.startsecs}
          stopsignal=${cfg.stopsignal}
          stopasgroup=true
          ''
        ) (attrNames services)
      }
    '';
  };
}
