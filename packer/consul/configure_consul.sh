#! /bin/bash

echo "Configuring Consul\n"

mkdir /tmp/consul

if [ $1 == "server" ]; then
  systemctl enable consul-server.service
  systemctl start consul-server.service
else
  systemctl enable consul-client.service
  systemctl start consul-client.service
    sleep 30
  consul join $2
fi

echo "Configuration of Consul complete\n"
exit 0
