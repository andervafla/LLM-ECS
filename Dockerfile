FROM grafana/agent:latest

COPY agent-config.yaml /etc/agent/agent-config.yaml

CMD ["--config.file=/etc/agent/agent-config.yaml"]
