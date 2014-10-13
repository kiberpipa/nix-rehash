==========
nix-rehash
==========


Nix development utils that will blow up your mind


reService - fullstack@dev
--------------------------

reService takes your nixos config of services and creates user-enabled supervisord
config that you can use for development or deployment on non nixos systems.
Having deterministic fullstack in development has never been more awesome.

- Create `default.nix`

  ```
  { pkgs ? import <nixpkgs> {}
  , projectName ? "myProject"
  , nix-rehash ? import <nix-rehash> }:
    with pkgs.lib;
    with pkgs;

  let
    services = nix-rehash.reService {
      name = "${projectName}";
      configuration = let servicePrefix = "/tmp/${projectName}/services"; in [
        ({ config, pkgs, ...}: {
          services.postgresql.enable = true;
          services.postgresql.package = pkgs.postgresql92;
          services.postgresql.dataDir = "${servicePrefix}/postgresql";
        })
      ];
    };
  in myEnvFun {
    name = projectName;
    buildInputs = [ services ];
  }
  ```

- install `nix-env -f default.nix -i`
- load environemnt `load-env-myProject`
- start services `myProject-start-services`, control services `myProject-control-services`,
  stop services `myProject-stop-services`

Now build this with hydra and pass the environment around :)

Alternative using nix-shell:

- set `buildInputs = [ services.config.supervisord.bin ];`
- run `nix-shell`
- use `supervisord` and `supervisorctl` as you wish

reContain - heroku@home
-----------------------

reContain makes nixos enabled installable container that can auto-update
itself. Now you can build container on hydra and auto update it on
host machine. Staging or deployments have never been easier :)

- Create `default.nix`

  ```
  { pkgs ? import <nixpkgs>
  , name ? "myProject"
  , nix-rehash ? import <nix-rehash> }:
    with pkgs.lib;
    with pkgs;

  {
    container = nix-rehash.reContain {
      inherit name;
      configuration = [{
      services.openssh.enable = true;
      services.openssh.ports = [ 25 ];
      users.extraUsers.root.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
      }];
    };
  }
  ```
- do `nix-env [-f default.nix] -i myProject-container` or build with hydra and add a channel
- start container: `sudo myProject-start-container`
- ssh to container: `ssh localhost -p 25`
- enable auto updates with cron:
  ```
  * * * * * nix-env -i myProject-container && sudo $HOME/.nix-profile/bin/myProject-update-container
  ```
- stop container: `sudo myProject-stop-container`
