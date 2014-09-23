{ system ? builtins.currentSystem
, pkgs ? import <nixpkgs> {
  inherit system;
  # Darwin needs a few packages overrides
  config = if system == "x86_64-darwin" then {
    packageOverrides = pkgs: {
      shadow = pkgs.stdenv.mkDerivation {
        name="shadow"; outputs=["out" "su"];
        buildCommand="touch $out; touch $su";
      };
    };
  } else {};
}
, name
, configuration
}:
  with pkgs.lib;

let
  moduleList = [
    ./user.nix ./supervisord.nix ./systemd.nix ./environment.nix

    <nixpkgs/nixos/modules/config/users-groups.nix>
    <nixpkgs/nixos/modules/misc/ids.nix>
    <nixpkgs/nixos/modules/misc/assertions.nix>
    <nixpkgs/nixos/modules/config/timezone.nix>

    <nixpkgs/nixos/modules/services/databases/redis.nix>
    <nixpkgs/nixos/modules/services/databases/mysql.nix>
    <nixpkgs/nixos/modules/services/databases/postgresql.nix>
    <nixpkgs/nixos/modules/services/databases/mongodb.nix>
    <nixpkgs/nixos/modules/services/databases/couchdb.nix>
    <nixpkgs/nixos/modules/services/databases/neo4j.nix> 
    <nixpkgs/nixos/modules/services/search/elasticsearch.nix>
    <nixpkgs/nixos/modules/services/monitoring/graphite.nix>
    <nixpkgs/nixos/modules/services/monitoring/statsd.nix>
    <nixpkgs/nixos/modules/services/amqp/rabbitmq.nix>
    <nixpkgs/nixos/modules/services/logging/logstash.nix>
    #<nixpkgs/nixos/modules/services/misc/bitcoin.nix>
  ];

  config = (evalModules {
    modules = configuration ++ moduleList;
    args = { inherit pkgs; };
  }).config;

  systemd = import ./systemd.nix { inherit pkgs config; };

  startServices = pkgs.writeScript "startServices" ''
    #!/bin/sh
    export STATEDIR="${"\$"}{STATEDIR-$(pwd)/var}"
    export PATH="${pkgs.coreutils}/bin"

    mkdir -p $STATEDIR/{run,log}

    # Run start scripts first
    ${config.userNix.startScript}

    # Run supervisord
    ${pkgs.pythonPackages.supervisor}/bin/supervisord -c ${config.supervisord.configFile} -j $STATEDIR/run/supervisord.pid -d $STATEDIR -q $STATEDIR/log/ -l $STATEDIR/log/supervisord.log
  '';

  stopServices = pkgs.writeScript "stopServices" ''
    #!/bin/sh
    ${pkgs.pythonPackages.supervisor}/bin/supervisorctl -c ${config.supervisord.configFile} shutdown
  '';

  controlServices = pkgs.writeScript "controlServices" ''
    #!/bin/sh
    ${pkgs.pythonPackages.supervisor}/bin/supervisorctl -c ${config.supervisord.configFile}
  '';

  servicesControl  = pkgs.stdenv.mkDerivation {
    name = "${name}-servicesControl";
    src = ./.;

    phases = [ "installPhase" ];

    installPhase = ''
        ensureDir $out/bin/
        ln -s ${startServices} $out/bin/${name}-start-services
        ln -s ${stopServices} $out/bin/${name}-stop-services
        ln -s ${controlServices} $out/bin/${name}-control-services
    '';

    passthru.config = config;
  };

in pkgs.buildEnv {
  name = "${name}-services";
  paths = [ servicesControl ] ++ config.environment.systemPackages;
}
