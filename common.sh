#!/bin/sh

[ -n "$_ALLOW_INCLUDES" ] || exit 1

ensure_var() {
  if [ -z "$2" ]; then
    echo "> ERR: Missing $1 variable." >&2
    exit 2
  fi
}

ensure_env_var() {
  VAL=$(eval echo \"'$'$1\")
	ensure_var $1 $VAL
}

get_run_cmd() {
	if [ -f "$CERT_PATH_PREFIX.json" ]; then
		echo renew
	else
		echo setup
	fi
}

next_date_timestamp() {
	NUM=$(echo "$1" | grep -E '^[0-9]+' -o)
	SUFFIX=$(echo "$1" | grep -E '[smhd]$' -o)

	NOW=$(date +%s)
	case "$SUFFIX" in
		s) expr "$NOW" + "$NUM"  ;;
		m) expr "$NOW" + '(' "$NUM" '*' 60 ')' ;;
		h) expr "$NOW" + '(' "$NUM" '*' 3600 ')' ;;
		d) expr "$NOW" + '(' "$NUM" '*' 86400 ')' ;;
	esac
}

cert_file_sha1_fingerprint() {
	FILENAME="$1"

	openssl x509 -in "$FILENAME" -sha1 -noout -fingerprint \
		| grep -E '[0-9A-F]{2}(:[0-9A-F]{2}){19}' -o \
		| tr -d ':' \
		| tr '[:upper:]' '[:lower:]'
}

