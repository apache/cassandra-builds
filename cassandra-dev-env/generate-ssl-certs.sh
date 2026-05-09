#!/bin/bash

# SSL Certificate Generation Script for Cassandra Sidecar mTLS
# Generates CA, server, and client certificates for mTLS authentication

set -e

CERT_DIR="./ssl-certs"
VALIDITY_DAYS=365
KEY_SIZE=2048

# Certificate passwords (configurable via environment)
CA_PASSWORD=${CA_PASSWORD:-"cassandra"}
SERVER_PASSWORD=${SERVER_PASSWORD:-"cassandra"}
CLIENT_PASSWORD=${CLIENT_PASSWORD:-"cassandra"}
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:-"cassandra"}

echo "🔐 Generating SSL certificates for Cassandra Sidecar mTLS..."
echo "   Certificate Directory: $CERT_DIR"
echo "   Validity: $VALIDITY_DAYS days"
echo "   Key Size: $KEY_SIZE bits"

# Create certificate directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Clean up existing certificates
rm -f *.pem *.p12 *.jks *.key *.crt

echo "🔐 Step 1: Generating Certificate Authority (CA)..."

# Generate CA private key
openssl genrsa -out ca-key.pem $KEY_SIZE

# Generate CA certificate
openssl req -new -x509 -key ca-key.pem -out ca-cert.pem -days $VALIDITY_DAYS -subj "/CN=Cassandra Sidecar CA/OU=Development/O=Apache Cassandra/C=US"

echo "✅ CA certificate generated"

echo "🔐 Step 2: Generating Server Certificate..."

# Generate server private key
openssl genrsa -out server-key.pem $KEY_SIZE

# Generate server certificate signing request with SAN
cat > server.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost
OU = Development
O = Apache Cassandra
C = US

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = cassandra-1
DNS.3 = cassandra-2  
DNS.4 = cassandra-3
DNS.5 = cassandra-4
DNS.6 = cassandra-5
DNS.7 = cassandra-node-1
DNS.8 = cassandra-node-2
DNS.9 = cassandra-node-3
DNS.10 = cassandra-node-4
DNS.11 = cassandra-node-5
DNS.12 = cassandra-1.cassandra-net
DNS.13 = cassandra-2.cassandra-net
DNS.14 = cassandra-3.cassandra-net
DNS.15 = cassandra-4.cassandra-net
DNS.16 = cassandra-5.cassandra-net
DNS.17 = cassandra-node-1.cassandra-net
DNS.18 = cassandra-node-2.cassandra-net
DNS.19 = cassandra-node-3.cassandra-net
DNS.20 = cassandra-node-4.cassandra-net
DNS.21 = cassandra-node-5.cassandra-net
IP.1 = 127.0.0.1
IP.2 = ::1
IP.3 = 172.18.0.2
IP.4 = 172.18.0.3
IP.5 = 172.18.0.4
IP.6 = 172.18.0.5
IP.7 = 172.18.0.6
EOF

# Generate server CSR
openssl req -new -key server-key.pem -out server.csr -config server.conf

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days $VALIDITY_DAYS -extensions v3_req -extfile server.conf

echo "✅ Server certificate generated"

echo "🔐 Step 3: Generating Client Certificate..."

# Generate client private key
openssl genrsa -out client-key.pem $KEY_SIZE

# Create client certificate configuration with Client Authentication extension
cat > client.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = Cassandra Sidecar Client
OU = Development
O = Apache Cassandra
C = US

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = critical, clientAuth
basicConstraints = critical, CA:FALSE
subjectAltName = URI:spiffe://cassandra/sidecar/admin
EOF

# Generate client certificate signing request with extensions
openssl req -new -key client-key.pem -out client.csr -config client.conf

# Sign client certificate with CA including Client Authentication extension - using exact working command
openssl x509 -req -in client.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days $VALIDITY_DAYS -extensions v3_req -extfile client.conf -sha256

echo "✅ Client certificate generated"

echo "🔐 Step 4: Creating PKCS12 Keystores and Truststore..."

# Create server keystore (PKCS12)
openssl pkcs12 -export -in server-cert.pem -inkey server-key.pem -out server-keystore.p12 -name "cassandra-server" -password pass:$SERVER_PASSWORD

# Create client keystore with CA certificate included (PKCS12) 
openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem -certfile ca-cert.pem -out client-keystore.p12 -name "cassandra-client" -password pass:$CLIENT_PASSWORD

# Create truststore with CA certificate (PKCS12) - using keytool for better Java compatibility
if command -v keytool &> /dev/null; then
    keytool -import -trustcacerts -alias cassandra-ca -file ca-cert.pem -keystore truststore.p12 -storetype PKCS12 -storepass $TRUSTSTORE_PASSWORD -noprompt
else
    # Fallback to OpenSSL if keytool is not available
    openssl pkcs12 -export -nokeys -in ca-cert.pem -out truststore.p12 -name "cassandra-ca" -password pass:$TRUSTSTORE_PASSWORD
fi

echo "✅ PKCS12 keystores created"

echo "🔐 Step 5: Creating JKS Keystores (for Cassandra compatibility)..."

# Convert PKCS12 to JKS for Cassandra (if keytool is available)
if command -v keytool &> /dev/null; then
    # Create server JKS keystore
    keytool -importkeystore -srckeystore server-keystore.p12 -srcstoretype PKCS12 -srcstorepass $SERVER_PASSWORD \
            -destkeystore server-keystore.jks -deststoretype JKS -deststorepass $SERVER_PASSWORD -noprompt

    # Create truststore JKS 
    keytool -importkeystore -srckeystore truststore.p12 -srcstoretype PKCS12 -srcstorepass $TRUSTSTORE_PASSWORD \
            -destkeystore truststore.jks -deststoretype JKS -deststorepass $TRUSTSTORE_PASSWORD -noprompt

    echo "✅ JKS keystores created"
else
    echo "⚠️  keytool not available, JKS keystores not created (PKCS12 will work for Sidecar)"
fi

echo "🔐 Step 6: Setting permissions..."

# Set appropriate permissions
chmod 600 *.pem *.p12 *.jks 2>/dev/null || true
chown -R cassandra:cassandra "$CERT_DIR" 2>/dev/null || true

echo "🔐 Step 7: Verification..."

# Display certificate information
echo ""
echo "📋 Certificate Summary:"
echo "   CA Certificate: ca-cert.pem"
echo "   Server Certificate: server-cert.pem" 
echo "   Client Certificate: client-cert.pem"
echo "   Server Keystore: server-keystore.p12 (password: $SERVER_PASSWORD)"
echo "   Client Keystore: client-keystore.p12 (password: $CLIENT_PASSWORD)" 
echo "   Truststore: truststore.p12 (password: $TRUSTSTORE_PASSWORD)"

# Verify server certificate
echo ""
echo "🔍 Server Certificate Details:"
openssl x509 -in server-cert.pem -text -noout | grep -E "(Subject:|DNS:|IP Address:|Extended Key Usage)" || true

# Verify client certificate 
echo ""
echo "🔍 Client Certificate Details:"
openssl x509 -in client-cert.pem -text -noout | grep -A 10 "Version:\|Extended Key Usage\|Key Usage" || echo "   Client certificate verification - checking manually:"
openssl x509 -in client-cert.pem -noout -ext extendedKeyUsage 2>/dev/null || echo "   No extended key usage found"

# Clean up temporary files
rm -f *.csr *.conf *.srl

echo ""
echo "✅ SSL certificate generation complete!"
echo "   Certificates are ready for Cassandra Sidecar mTLS configuration"
echo ""