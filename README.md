==========
nix-rehash
==========


Nix development utils that will blow up your mind


Nix services
------------

Nix services takes your nixos services config and creates supervisord config
that you can use for development or deployment on non nixos systems.

- Create `default.nix`

  ```
  { pkgs ? import <nixpkgs>
  , projectName ? "myProject"
  , nix-rehash ? import <nix-rehash> }:
    with pkgs.lib;
    with pkgs;

  let
    services = nix-rehash.buildServices {
      name = "${projectName}";
      configuration = let servicePrefix = "/tmp/${projectName}/services"; in [
        ({ config, pkgs, ...}: {
          services.postgresql.enable = true;
          services.postgresql.package = pkgs.postgresql92;
          services.postgresql.dataDir = "${servicePrefix}/postgresql";
        })
      ];
    };
  in rec myEnvFun {
    name = projectName;
    buildInputs = [ services ];
  }
  ```

- do nix-build
- load environemnt `load-env-myProject`
- start services `myProject-start-services`, control services `myProject-control-services`,
  stop services `myProject-stop-services`
