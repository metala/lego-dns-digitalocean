#!/bin/sh

[ -n "$_ALLOW_INCLUDES" ] || exit 1

DO_API_URL="https://api.digitalocean.com"

do_curl() {
	ensure_env_var DIGITALOCEAN_API_KEY

	curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $DIGITALOCEAN_API_KEY" "$@"
}

do_curl_jq() {
	RESPONSE="$(do_curl "$@")"
	echo "$RESPONSE" | jq || echo "> jq ERR; API response: $RESPONSE" >&2
}

do_json_put_endpoint() {
	echo '{}' | jq \
		--arg certificate_id "$1" \
		--arg custom_domain "$LEGO_DOMAIN" \
		'.certificate_id=$certificate_id | .custom_domain=$custom_domain' 
}

do_json_new_certificate() {
	NAME=$1
	ensure_var 'certificate name' "$NAME"

	echo '{}' | jq \
		--arg name "$NAME" \
		--rawfile key "$CERT_PATH_PREFIX.key" \
		--rawfile crt "$CERT_PATH_PREFIX.crt" \
		--rawfile chain "$CERT_PATH_PREFIX.issuer.crt" \
		'.type="custom"
		| .name=$name
		| .private_key=$key
		| .leaf_certificate=($crt | split("\n\n") | (.[0] + "\n"))
		| .certificate_chain=($chain | split("\n\n") | join("\n"))'
}

do_certificates_find_by_fingerprint() {
	do_curl -X GET "$DO_API_URL/v2/certificates" \
		| jq --arg fp "$1" '.certificates | .[] | select(.sha1_fingerprint==$fp)'
}

do_certificates_find() {
	FP=$(cert_file_sha1_fingerprint "$CERT_PATH_PREFIX.crt")
	do_certificates_find_by_fingerprint $FP
}

do_cmd_endpoints_ls() {
	do_curl_jq "$DO_API_URL/v2/cdn/endpoints" 
}

do_cmd_endpoints_get() {
	echo 'Retrieving endpoint details...' >&2
	ensure_env_var DIGITALOCEAN_ENDPOINT_ID

	do_curl_jq "$DO_API_URL/v2/cdn/endpoints/$DIGITALOCEAN_ENDPOINT_ID" | jq
}

do_cmd_endpoints_get_cert() {
	echo 'Retrieving endpoint certificate...' >&2
	ensure_env_var DIGITALOCEAN_ENDPOINT_ID

	RESPONSE="$(do_curl "$DO_API_URL/v2/cdn/endpoints/$DIGITALOCEAN_ENDPOINT_ID")"
	CERTIFICATE_ID="$(echo "$RESPONSE" | jq -r '.endpoint.certificate_id')"
	if [ "$CERTIFICATE_ID" == "null" ]; then
		echo "> ERR: The endpoint 'certificate_id' is not set." >&2
		echo "> API resposne:" >&2
		echo "$RESPONSE" | jq >&2
		exit 3
	fi

	do_curl "$DO_API_URL/v2/certificates/$CERTIFICATE_ID" | jq
}

do_cmd_endpoints_set_cert() {
	echo 'Setting endpoint certificate...' >&2
	ensure_env_var DIGITALOCEAN_ENDPOINT_ID

	echo "Updating endpoint '$DIGITALOCEAN_ENDPOINT_ID' with certificate '$CERTIFICATE_ID'..." 
	DATA="$(do_json_put_endpoint $1)"
	do_curl_jq -X PUT -d "$DATA" "$DO_API_URL/v2/cdn/endpoints/$DIGITALOCEAN_ENDPOINT_ID"
}

do_cmd_endpoints_refresh_cert() {
	echo 'Refreshing endpoint certificate...' >&2
	ensure_env_var DIGITALOCEAN_ENDPOINT_ID

	CERT=$(do_certificates_find)
	if [ -n "$CERT" ]; then
		CERTIFICATE_ID="$(echo "$CERT" | jq -r '.id')"
	else
		do_cmd_certificates_push
	fi

	if [ -z "$CERTIFICATE_ID" ]; then
		echo '> ERR: Missing certificate id.' >&2
		exit 1
	fi

	do_cmd_endpoints_set_cert "$CERTIFICATE_ID"
}

do_cmd_certificates_ls() {
	do_curl_jq -X GET "$DO_API_URL/v2/certificates"
}

do_cmd_certificates_rm() {
	do_curl_jq -X DELETE "$DO_API_URL/v2/certificates/$1"
}

do_cmd_certificates_push() {
	echo 'Pushing a certificate...' >&2

	ensure_env_var DIGITALOCEAN_ENDPOINT_ID
	CERT_PREFIX="${DIGITALOCEAN_CERTIFICATE_PREFIX:-lego-cert}"
	CERT_NAME="$CERT_PREFIX-t$(date +%Y%m%d%H%M%S)"

	DATA=$(do_json_new_certificate "$CERT_NAME")
	RESPONSE=$(do_curl -X POST -d "$DATA" "$DO_API_URL/v2/certificates")
	CERTIFICATE_ID=$(echo "$RESPONSE" | jq -r '.certificate.id')

	if [ "$CERTIFICATE_ID" == "null" ]; then
		echo "> ERR: Unable to create certificate." >&2
		echo "> API response:" >&2
		echo "$RESPONSE" | jq >&2
		exit 4
	fi
}
