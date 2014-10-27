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
      path = mkOption {
        default = [];
        description = "Current directory when running the command";
      };
      stopsignal = mkOption {
        default = "TERM";
      };
      startsecs = mkOption {
        default = 1;
        example = 0;
      };
      pidfile = mkOption {
        default = null;
      };
    };
  };
  
  services = config.supervisord.services;
  
  supervisor = config.supervisord.package;

  supervisordWrapper = pkgs.writeScript "supervisord-wrapper" ''
    #!${pkgs.stdenv.shell}
    extraFlags=""
    if [ -n "$STATEDIR" ]; then
      extraFlags="-j $STATEDIR/run/supervisord.pid -d $STATEDIR -q $STATEDIR/log/ -l $STATEDIR/log/supervisord.log"
      mkdir -p "$STATEDIR"/{run,log}
    else
      mkdir -p "${config.supervisord.stateDir}"/{run,log}
    fi
        
    export PATH="${pkgs.coreutils}/bin"
        
    # Run start scripts first
    ${config.userNix.startScript}
        
    # Run supervisord
    ${supervisor}/bin/supervisord -c ${config.supervisord.configFile} $extraFlags $@
  '';

  supervisorctlWrapper = pkgs.writeScript "supervisorctl-wrapper" ''
  	#!/usr/bin/env bash
    ${supervisor}/bin/supervisorctl -c ${config.supervisord.configFile} $@
  '';

in {
  options = {
    supervisord = {
      enable = mkOption {
        default = true;
        type = types.bool;
      };

      port = mkOption {
        default = 65123;
        type = types.int;
      };

      package = mkOption {
        default = pkgs.pythonPackages.supervisor;
        type = types.package;
        description = ''
          Supervisord package to use.
        '';
      };

      services = mkOption {
        default = {};
        type = types.loaOf types.optionSet;
        description = ''
          Supervisord services to start.
        '';
        options = [ serviceOpts ];
      };

      stateDir = mkOption {
        default = "./var";
        type = types.str;
        description = ''
          Supervisord state directory.
        '';
      };

      tailLogs = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether or not to tail all logs to standard out.
        '';
      };

      configFile = mkOption {
        internal = true;
      };

      bin = mkOption {
        internal = true;
      };
    };
  };

  config = mkIf config.supervisord.enable {
    supervisord.configFile = pkgs.writeText "supervisord.conf" ''
      [supervisord]
      pidfile=${config.supervisord.stateDir}/run/supervisord.pid
      childlogdir=${config.supervisord.stateDir}/log/
      logfile=${config.supervisord.stateDir}/log/supervisord.log

      [supervisorctl]
      serverurl = http://localhost:${toString config.supervisord.port}

      [inet_http_server]
      port = 127.0.0.1:${toString config.supervisord.port}

      [rpcinterface:supervisor]
      supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

      ${concatMapStrings (name:
        let
          cfg = getAttr name services;
		  path = if isList cfg.path then concatStringsSep ":" cfg.path else cfg.path;
        in
          ''
          [program:${name}]
          command=${if cfg.pidfile == null then cfg.command else "${supervisor}/bin/pidproxy ${cfg.pidfile} ${cfg.command}"}
          environment=${concatStrings
            (mapAttrsToList (name: value: "${name}=\"${value}\",") (
              cfg.environment // { PATH = concatStringsSep ":"
                [("%(ENV_PATH)s") (path) (maybeAttr "PATH" "" cfg.environment)];
              }
            )
          )}
          directory=${cfg.directory}
          redirect_stderr=true
          startsecs=${toString cfg.startsecs}
          stopsignal=${cfg.stopsignal}
          stopasgroup=true
          ''
        ) (attrNames services)
      }
    '';

    supervisord.bin = pkgs.stdenv.mkDerivation {
      name = "${supervisor.name}-wrapper";

      phases = [ "installPhase" ];

      installPhase = ''
        mkdir -p $out/bin/
        ln -s -T ${supervisordWrapper} $out/bin/supervisord
        ln -s -T ${supervisorctlWrapper} $out/bin/supervisorctl
      '';

    };

  };
}
  