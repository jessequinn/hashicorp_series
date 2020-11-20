#! /bin/bash

echo "Enabling Vault on server\n"

systemctl enable vault-server.service
systemctl start vault-server.service

export VAULT_ADDR=http://127.0.0.1:8200

echo "Enabled Vault complete\n"
exit 0