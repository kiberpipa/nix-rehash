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

  startContainer = writeTextFile {
    name = "${name}-container-start";
    text = ''
      #!${pkgs.bash}/bin/bash
      mkdir -p -m 0755 ${container_root}/etc
      mkdir -p /var/log/containers
      if ! [ -e ${container_root}/etc/os-release ]; then
        touch ${container_root}/etc/os-release
      fi
      rm ${container_root}/old_config && ln -fs ${container} ${container_root}/old_config
      rm ${container_root}/new_config && ln -fs ${container} ${container_root}/new_config
      nohup ${pkgs.systemd}/bin/systemd-nspawn -M ${name} -D ${container_root} --bind-ro=/nix ${container}/init > /var/log/containers/${name}.log &
    '';
    executable = true;
    destination = "/bin/${name}-container-start";
  };

  stopContainer = writeTextFile {
    name = "${name}-container-stop";
    text = ''
      #!${pkgs.bash}/bin/bash
      pid="$(cat /sys/fs/cgroup/systemd/machine/${name}.nspawn/system/tasks 2> /dev/null)"
      if [ -n "$pid" ]; then
          # Send the RTMIN+3 signal, which causes the container
          # systemd to start halt.target.
          echo "killing container systemd, PID = $pid"
          kill -RTMIN+3 $pid
          # Wait for the container to exit.  We can't let systemd
          # do this because it will send a signal to the entire
          # cgroup.
          for ((n = 0; n < 180; n++)); do
          if ! kill -0 $pid 2> /dev/null; then break; fi
          sleep 1
          done
      fi
    '';
    executable = true;
    destination = "/bin/${name}-container-stop";
  };

  updateContainer = writeTextFile {
    name = "${name}-container-update";
    text = ''
      #!${pkgs.bash}/bin/bash
      rm ${container_root}/new_config && ln -fs ${container} ${container_root}/new_config
    '';
    executable = true;
    destination = "/bin/${name}-container-update";
  };
in buildEnv {
  name = "${name}-container";
  paths = [ startContainer stopContainer updateContainer ];
}
