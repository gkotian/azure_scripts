#!/bin/bash

read -p "Enter the tenant ID: " TENANT_ID
read -p "Enter the client ID: " CLIENT_ID
read -p "Enter the client secret: " CLIENT_SECRET
echo

response=$(curl -s -X POST "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "scope=https://graph.microsoft.com/.default" \
  -d "grant_type=client_credentials")

if echo "$response" | grep -q "access_token"; then
  echo "Success: Credentials are valid."
else
  echo "Failed: $(echo "$response" | grep -o '"error_description":"[^"]*"')"
fi
