FROM grafana/agent:latest

COPY agent-config.yaml /etc/agent/agent-config.yaml

ENTRYPOINT ["/bin/agent"]
CMD ["--config.file=/etc/agent/agent-config.yaml", "--mode=flow"]
