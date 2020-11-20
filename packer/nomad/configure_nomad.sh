#! /bin/bash

echo "Configuring Nomad\n"

if [ $1 == "server" ]; then
  systemctl enable nomad-server.service
  systemctl start nomad-server.service
else
  systemctl enable nomad-client.service
  systemctl start nomad-client.service
fi

echo "Configuration of Nomad complete\n"
exit 0
