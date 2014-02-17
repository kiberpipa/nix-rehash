{ config, pkgs, ... }:
{
  config = {
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql92;
    services.postgresql.dataDir = "/tmp/postgres";
    services.elasticsearch.enable = true;
    services.elasticsearch.dataDir = "/tmp/elasticsearch";
  };
}
