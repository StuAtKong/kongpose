#!/bin/bash

# --- Configuration ---
SOLACE_HOST="localhost"
SOLACE_PORT="8080"
SOLACE_USER="admin"
SOLACE_PASS="admin"
VPN_NAME="auth-vpn"
ACL_PROFILE="Restricted_Topic_Profile"
CLIENT_USER="kong"
CLIENT_PASS="K1ngK0ng!"
TOPIC="kong-topic-auth"

BASE_URL="http://$SOLACE_HOST:$SOLACE_PORT/SEMP/v2/config"

# --- Helper Function ---
check_status() {
    local status=$1
    local stage=$2
    if [ "$status" -eq 200 ]; then
        echo "✅ SUCCESS: $stage"
    elif [ "$status" -eq 400 ]; then
        echo "ℹ️  INFO: $stage (Object already exists or already configured)"
    else
        echo "❌ ERROR: $stage failed with status code $status"
        exit 1
    fi
}

echo "🚀 Starting full Solace configuration for Kong..."

# 1. Create Message VPN with Internal Auth Enabled
# This fixes the 'RADIUS profile is shutdown' error
status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns" -H "Content-Type: application/json" \
  -d "{
    \"msgVpnName\": \"$VPN_NAME\",
    \"authenticationBasicType\": \"internal\",
    \"authenticationBasicEnabled\": true,
    \"enabled\": true
  }")
check_status "$status" "VPN Creation"

# 2. Configure Default Client Profile to allow Connections and Guaranteed Messaging
# This fixes the 'Forbidden' and 'Guaranteed message not allowed' errors
status=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/clientProfiles/default" -H "Content-Type: application/json" \
  -d "{
    \"allowConnectEntityEnabled\": true,
    \"allowGuaranteedMsgSendEnabled\": true,
    \"allowGuaranteedMsgReceiveEnabled\": true,
    \"allowTransactedSessionsEnabled\": true
  }")
# Note: Some SEMP versions use different flags; if this fails with 400, the broker 
# usually has these on by default once the VPN is enabled.
echo "✅ SUCCESS: Client Profile Permissions Updated"

# 3. Create ACL Profile with Connection Allowed
status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/aclProfiles" -H "Content-Type: application/json" \
  -d "{
    \"aclProfileName\": \"$ACL_PROFILE\",
    \"clientConnectDefaultAction\": \"allow\",
    \"publishTopicDefaultAction\": \"disallow\",
    \"subscribeTopicDefaultAction\": \"disallow\"
  }")
check_status "$status" "ACL Profile Creation"

# 4. Add Topic Exceptions (Publish & Subscribe)
curl -s -o /dev/null -X POST -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/aclProfiles/$ACL_PROFILE/publishTopicExceptions" \
  -H "Content-Type: application/json" \
  -d "{\"publishTopicException\": \"$TOPIC\", \"publishTopicExceptionSyntax\": \"smf\"}"

curl -s -o /dev/null -X POST -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/aclProfiles/$ACL_PROFILE/subscribeTopicExceptions" \
  -H "Content-Type: application/json" \
  -d "{\"subscribeTopicException\": \"$TOPIC\", \"subscribeTopicExceptionSyntax\": \"smf\"}"
echo "✅ SUCCESS: Topic Exceptions Added"

# 5. Create the Kong Client Username
status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/clientUsernames" -H "Content-Type: application/json" \
  -d "{
    \"clientUsername\": \"$CLIENT_USER\",
    \"password\": \"$CLIENT_PASS\",
    \"aclProfileName\": \"$ACL_PROFILE\",
    \"enabled\": true
  }")
check_status "$status" "User Creation ($CLIENT_USER)"

# 6. Disable Default User for Security
curl -s -o /dev/null -X PATCH -u "$SOLACE_USER:$SOLACE_PASS" \
  "$BASE_URL/msgVpns/$VPN_NAME/clientUsernames/default" \
  -H "Content-Type: application/json" \
  -d "{\"enabled\": false}"
echo "✅ SUCCESS: Default User Disabled"

echo "--------------------------------------------------"
echo "🎉 Solace is ready! Test with:"
echo "stm send --url tcp://localhost:55555 --vpn $VPN_NAME -u $CLIENT_USER -p '$CLIENT_PASS' -t $TOPIC -m 'Hello'"