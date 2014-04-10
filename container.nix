{ system ? builtins.currentSystem
, pkgs ? import <nixpkgs> { inherit system; }
, name
, configuration
}:
  with pkgs;
  with pkgs.lib;

let
  container_root = "/var/lib/containers/${name}";

  switchScript = writeScript "${name}-switch" ''
    #!${pkgs.bash}/bin/bash
    old_gen="$(readlink -f /old_config)"
    new_gen="$(readlink -f /new_config)"
    [ "x$old_gen" != "x$new_gen" ] || exit 0
    $new_gen/bin/switch-to-configuration switch
    rm /old_config && ln -fs $new_gen /old_config
  '';

  container = (import <nixpkgs/nixos/lib/eval-config.nix> {
    modules =
      let extraConfig = {
        boot.isContainer = true;
        networking.hostName = mkDefault name;
        security.pam.services.sshd.startSession = mkOverride 50 false;
        services.cron.systemCronJobs = [
          "* * * * * root ${switchScript} > /var/log/switch-config.log 2>&1"
        ];
      };
      in [ extraConfig ] ++ configuration;
    prefix = [ "systemd" "containers" name ];
  }).config.system.build.toplevel;

  containerConfig = ''
    lxc.utsname = ${name}
    lxc.arch = ${if system == "x86_64-linux" then "x86_64" else "i686"}
    lxc.tty = 6
    lxc.pts = 1024

    ## Capabilities
    lxc.cap.drop = audit_control audit_write mac_admin mac_override mknod setfcap
    lxc.cap.drop = sys_boot sys_module sys_pacct sys_rawio sys_time

    ## Devices
    lxc.cgroup.devices.deny = a # Deny access to all devices

    # Allow to mknod all devices (but not using them)
    lxc.cgroup.devices.allow = c *:* m
    lxc.cgroup.devices.allow = b *:* m

    lxc.cgroup.devices.allow = c 1:3 rwm
    lxc.cgroup.devices.allow = c 1:5 rwm
    lxc.cgroup.devices.allow = c 1:8 rwm
    lxc.cgroup.devices.allow = c 1:9 rwm
    lxc.cgroup.devices.allow = c 4:0 rwm
    lxc.cgroup.devices.allow = c 4:1 rwm
    lxc.cgroup.devices.allow = c 4:2 rwm
    lxc.cgroup.devices.allow = c 4:3 rwm
    lxc.cgroup.devices.allow = c 5:0 rwm
    lxc.cgroup.devices.allow = c 5:1 rwm
    lxc.cgroup.devices.allow = c 5:2 rwm
    lxc.cgroup.devices.allow = c 10:229 rwm
    lxc.cgroup.devices.allow = c 136:* rwm
    lxc.cgroup.devices.allow = c 254:0 rwm

    ## Mounts
    lxc.mount.auto = proc sys cgroup
    lxc.mount.entry = /nix/store nix/store none defaults,bind.ro 0.0
    lxc.autodev = 1

    ## Network
    lxc.network.type = veth
    lxc.network.name = eth0
    lxc.network.flags = up
    '';

  startContainer = writeTextFile {
    name = "${name}-container-start";
    text = ''
      #!${pkgs.bash}/bin/bash
      if [ -z "$CONTAINER_ROOT" ]; then
          export CONTAINER_ROOT="/var/lib/containers/${name}"
      fi
      echo "Using $CONTAINER_ROOT as rootfs"
      mkdir -p $CONTAINER_ROOT/{proc,sys,dev,nix/store,etc}
      mkdir -p /run/lxc/rootfs
      chmod 0755 $CONTAINER_ROOT/etc
      if ! [ -e $CONTAINER_ROOT/etc/os-release ]; then
        touch $CONTAINER_ROOT/etc/os-release
      fi
      rm $CONTAINER_ROOT/old_config && ln -fs "${container}" $CONTAINER_ROOT/old_config
      rm $CONTAINER_ROOT/new_config && ln -fs "${container}" $CONTAINER_ROOT/new_config
      ${pkgs.lxc}/bin/lxc-start -n "${name}" \
        -f "${pkgs.writeText "container.conf" containerConfig}" \
        -s lxc.rootfs=$CONTAINER_ROOT \
        "$@" "${container}/init"
    '';
    executable = true;
    destination = "/bin/${name}-container-start";
  };

  stopContainer = writeTextFile {
    name = "${name}-container-stop";
    text = ''
      #!${pkgs.bash}/bin/bash
      ${pkgs.lxc}/bin/lxc-stop -n "${name}" "$@"
    '';
    executable = true;
    destination = "/bin/${name}-container-stop";
  };

  updateContainer = writeTextFile {
    name = "${name}-container-update";
    text = ''
      #!${pkgs.bash}/bin/bash
      if [ -z "$CONTAINER_ROOT" ]; then
          export CONTAINER_ROOT="/var/lib/containers/${name}"
      fi
      rm $CONTAINER_ROOT/new_config && ln -fs ${container} $CONTAINER_ROOT/new_config
    '';
    executable = true;
    destination = "/bin/${name}-container-update";
  };
in buildEnv {
  name = "${name}-container";
  paths = [ startContainer stopContainer updateContainer ];
}
