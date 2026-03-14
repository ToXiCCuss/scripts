#!/bin/bash

ADMIN_USER=${1:-admin}

if [ -z "$2" ]; then
  ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c 30)
else
  ADMIN_PASS=$2
fi

echo "Initial Setup of MongoDB Admin User"
echo "------------------------------------------"
echo "Username: $ADMIN_USER"
echo "Password: $ADMIN_PASS"
echo "------------------------------------------"

mongosh admin --quiet <<EOF
db.createUser({
  user: "$ADMIN_USER",
  pwd: "$ADMIN_PASS",
  roles: [
    { role: "root", db: "admin" }
  ]
})
EOF

if [ $? -eq 0 ]; then
  echo "------------------------------------------"
  echo "Admin user successfully created."
  echo ""

  CONFIG_FILE="/etc/mongodb-admin.cred"
  echo "[INFO] Creating credential file: $CONFIG_FILE"
  
  if sudo bash -c "cat <<EOF > $CONFIG_FILE
ADMIN_USER=\"$ADMIN_USER\"
ADMIN_PASS=\"$ADMIN_PASS\"
EOF" 2>/dev/null; then
    sudo chmod 600 "$CONFIG_FILE"
    echo "[INFO] Credential file created and secured (chmod 600)."
  else
    echo "[WARN] Could not create $CONFIG_FILE. Please create it manually with the following content:"
    echo "ADMIN_USER=\"$ADMIN_USER\""
    echo "ADMIN_PASS=\"$ADMIN_PASS\""
  fi

  echo ""
  echo "Next Steps:"
  echo "1. Enable authentication in /etc/mongod.conf:"
  echo "   security:"
  echo "     authorization: enabled"
  echo ""
  echo "2. Restart MongoDB:"
  echo "   sudo systemctl restart mongod"
  echo "------------------------------------------"
else
  echo "------------------------------------------"
  echo "Error creating admin user."
  echo "Please check if MongoDB is running and if authentication is already enabled."
  exit 1
fi
