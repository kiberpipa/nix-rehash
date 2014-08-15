{ config, pkgs, ... }:
with pkgs.lib;
{
  options = {
    environment.systemPackages = mkOption {
      default = [];
      description = "Packages to be put in the system profile.";
    };

    environment.umask = mkOption {
      default = "002";
      type = with types; string;
    };

    # HACK HACK
    system.activationScripts.etc = mkOption {}; # Ignore
    system.build.etc = mkOption {}; # Ignore
  };

  config = {
    environment.systemPackages = with pkgs; [ ];
  };
}
