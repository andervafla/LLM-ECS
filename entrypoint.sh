#!/bin/sh

ollama serve &

sleep 10

ollama pull llama3.2:1b

tail -f /dev/null
