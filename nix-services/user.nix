{ config, pkgs, ... }:
with pkgs.lib;
{
  options = {
    userNix.startScripts = mkOption {
      default = {};
      description = "Scripts (as text) to be run during build, executed alphabetically";
    };

    userNix.startScript = mkOption {};

  };

  config = {
    userNix.startScript = concatStrings (attrValues config.userNix.startScripts);
  };
}
