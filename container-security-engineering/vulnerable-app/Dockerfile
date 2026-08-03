FROM ubuntu:18.04

RUN apt-get update \
    && apt-get install -y curl openssl \
    && echo "DEMO_API_TOKEN=hardcoded-demo-secret-123456789" > /opt/demo-secret.txt

CMD ["sleep", "infinity"]
