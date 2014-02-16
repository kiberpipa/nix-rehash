{ pkgs ? import <nixpkgs> { system = "x86_64-linux"; }
, name
, configuration ? <configuration>
, baseImage ? "busybox"
}:
with pkgs.lib;
let
  moduleList = [
    ./user.nix ./supervisord.nix ./systemd.nix ./environment.nix

    <nixpkgs/nixos/modules/config/users-groups.nix>
    <nixpkgs/nixos/modules/misc/ids.nix>
    <nixpkgs/nixos/modules/misc/assertions.nix>
    <nixpkgs/nixos/modules/services/databases/redis.nix>
    <nixpkgs/nixos/modules/services/databases/mysql.nix>
    <nixpkgs/nixos/modules/services/databases/postgresql.nix>
    <nixpkgs/nixos/modules/testing/service-runner.nix>
  ];

  config = (evalModules {
    modules = [configuration] ++ moduleList;
    args = { inherit pkgs; };
  }).config;

  systemd = import ./systemd.nix { inherit pkgs config; };

  startScript = pkgs.writeScript "build" ''
    #!/bin/sh
    ${config.userNix.startScript}
  '';

in pkgs.stdenv.mkDerivation {
  inherit name;
  src = ./.;

  phases = [ "installPhase" ];

  installPhase = ''
      mkdir -p $out/etc/start
      ln -s ${startScript} $out/etc/start
  '';
}
