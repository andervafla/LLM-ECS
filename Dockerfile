FROM prom/cloudwatch-exporter:latest

COPY cloudwatch_exporter_config.yml /config/cloudwatch_exporter_config.yml
