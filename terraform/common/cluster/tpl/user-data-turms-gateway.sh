#!/bin/bash

apt-get update

# Set up Docker repository
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install Docker Engine
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl start docker
systemctl enable docker

# Set environment
cat >/etc/security/limits.conf <<EOF
*         hard    nofile      1000000
*         soft    nofile      1000000
root      hard    nofile      1000000
root      soft    nofile      1000000
EOF

# Run turms-gateway
HOST=$(hostname -i)
docker pull ghcr.io/turms-im/turms-gateway:latest
docker run -d --name turms-gateway --ulimit nofile=1000000 \
  --memory-swappiness=0 \
  -p 7510:7510 -p 9510:9510 -p 10510:10510 -p 11510:11510 -p 12510:12510 \
  --health-cmd="curl -I --silent $${HOST}:9510/actuator/health || exit 1" \
  --health-interval=5s \
  --health-timeout=5s \
  --health-retries=3 \
  --health-start-period=60s \
  -e TURMS_GATEWAY_JVM_OPTS="
  -Dspring.profiles.active=${PROFILE}
  -Dturms.cluster.connection.server.port-auto-increment=false
  -Dturms.cluster.discovery.address.advertise-strategy=advertise_address
  -Dturms.cluster.discovery.address.advertise-host=$${HOST}
  -Dturms.cluster.shared-config.mongo.uri=${CONFIG_MONGODB_URI}
  -Dturms.service.mongo.user.uri=${USER_MONGODB_URI}
  -Dturms.service.redis.session.uri-list[0]=${SESSION_REDIS_URI}
  -Dturms.service.redis.location.uri-list[0]=${LOCATION_REDIS_URI}
  ${CUSTOM_JVM_OPTS}" \
  ghcr.io/turms-im/turms-gateway
