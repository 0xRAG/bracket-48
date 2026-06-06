#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <team-id> <services-id-client-id> <key-id> <private-key-path>" >&2
  exit 1
fi

team_id="$1"
client_id="$2"
key_id="$3"
private_key_path="$4"
now="$(date +%s)"
expires_at="$((now + 15552000))"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

header="$(printf '{"alg":"ES256","kid":"%s"}' "$key_id" | base64url)"
payload="$(printf '{"iss":"%s","iat":%s,"exp":%s,"aud":"https://appleid.apple.com","sub":"%s"}' "$team_id" "$now" "$expires_at" "$client_id" | base64url)"
unsigned_token="${header}.${payload}"
signature="$(printf '%s' "$unsigned_token" | openssl dgst -sha256 -sign "$private_key_path" | base64url)"

printf '%s.%s\n' "$unsigned_token" "$signature"
