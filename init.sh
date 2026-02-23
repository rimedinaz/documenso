#!/bin/bash
set -e

# Create .env from .env.example if it doesn't exist
if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
else
  echo ".env already exists. Skipping creation."
fi

# Function to generate a random 32-character hex string
generate_key() {
  openssl rand -hex 32
}

# Function to generate a random 64-character hex string (for NEXTAUTH_SECRET)
generate_secret() {
  openssl rand -base64 32
}

# Check and set NEXTAUTH_SECRET
if grep -q "NEXTAUTH_SECRET=$" .env || grep -q "NEXTAUTH_SECRET= " .env; then
  SECRET=$(generate_secret)
  sed -i "s|NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=\"$SECRET\"|" .env
  echo "Generated NEXTAUTH_SECRET."
fi

# Check and set NEXT_PRIVATE_ENCRYPTION_KEY
if grep -q "NEXT_PRIVATE_ENCRYPTION_KEY=$" .env || grep -q "NEXT_PRIVATE_ENCRYPTION_KEY= " .env; then
  KEY=$(generate_key)
  sed -i "s|NEXT_PRIVATE_ENCRYPTION_KEY=.*|NEXT_PRIVATE_ENCRYPTION_KEY=\"$KEY\"|" .env
  echo "Generated NEXT_PRIVATE_ENCRYPTION_KEY."
fi

# Check and set NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY
if grep -q "NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=$" .env || grep -q "NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY= " .env; then
  KEY=$(generate_key)
  sed -i "s|NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=.*|NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=\"$KEY\"|" .env
  echo "Generated NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY."
fi

# Create certs directory
mkdir -p certs

# Generate self-signed certificate if it doesn't exist
if [ ! -f certs/cert.p12 ]; then
  echo "Generating self-signed certificate..."
  openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes -subj "/CN=localhost"
  openssl pkcs12 -export -out certs/cert.p12 -inkey certs/key.pem -in certs/cert.pem -passout pass:password
  rm certs/key.pem certs/cert.pem
  echo "Certificate generated at certs/cert.p12."
else
  echo "Certificate already exists at certs/cert.p12. Skipping generation."
fi

# Set permissions
chmod 600 certs/cert.p12

echo "Initialization complete. You can now run 'docker-compose up -d'."
