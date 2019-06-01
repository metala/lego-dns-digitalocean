#!/bin/sh

_ALLOW_INCLUDES=1
. ./common.sh
. ./digitalocean.sh

ensure_lego_vars() {
  ensure_env_var LEGO_DNS
  ensure_env_var LEGO_DOMAIN
  ensure_env_var LEGO_EMAIL
}

usage() {
  echo 'Commands:
  run (default)   Setup or renew, whichever is necessary
  setup           Run to setup account and domain
  renew           Renew the domain and endpoint certificate
  loop            Execute run every $LOOP_INTERVAL (default: 1h)
  NAMESPACE help  Show namespace help
  help            Show this help

Namespaces:
  endpoints       Endpoints namespace subcommands
  certificates    Certificates namespace subcommands
'
}

usage_endpoints() {
  echo 'Endpoints namespace subcommands:
  ls                List all endpoints
  get               Get selected endpoint details
  get-cert          Get endpoint certficate
  set-cert CERTID   Set endpoint certficate
  refresh-cert      Verify and update endpoint certficate
  help              Show this help
'
}

usage_certificates() {
  echo 'Certificates namespace subcommands:
  ls             List all certificates
  rm ID          Delete certificate with ID
  push           Push current certificate
  help           Show this help
'
}

cmd_endpoints() {
  SUBCMD="${1}"
  case "$SUBCMD" in
    ls) do_cmd_endpoints_ls ;;
    get) do_cmd_endpoints_get ;;
    get-cert) do_cmd_endpoints_get_cert ;;
    set-cert) do_cmd_endpoints_set_cert $2 ;;
    refresh-cert) do_cmd_endpoints_refresh_cert ;;
    help) usage_endpoints ;;
    *)
      echo "> Invalid subcommand: $@" >&2
      usage_endpoints >&2
      exit 1
  esac
}

cmd_certificates() {
  SUBCMD="${1}"
  case "$SUBCMD" in
    ls) do_cmd_certificates_ls ;;
    rm)  do_cmd_certificates_rm $2 ;;
    find) do_cmd_certificates_find ;;
    push) do_cmd_certificates_push ;;
    help) usage_certificates ;;
    *)
      echo "> Invalid subcommand: $@" >&2
      usage_certificates >&2
      exit 1
  esac
}

CERT_PATH_PREFIX="$PWD/.lego/certificates/$LEGO_DOMAIN"
LEGO_ARGS="-a --dns="$LEGO_DNS" --domains="$LEGO_DOMAIN" --email="$LEGO_EMAIL""

CMD="${1:-run}"
shift
if [ "$CMD" == "run" ]; then
  CMD="$(get_run_cmd)"
fi
case "$CMD" in
  # Namespaces
  endpoints)
    cmd_endpoints "$@"
    ;;
  certificates)
    cmd_certificates "$@"
    ;;

  # Commands
  setup)
    echo "> Executing 'run'..." >&2
    ensure_lego_vars
    ensure_env_var DIGITALOCEAN_ENDPOINT_ID

    lego $LEGO_ARGS run
    if [ "$?" -ne 0 ]; then
      echo "Failed to run lego DNS challenge on '$LEGO_DOMAIN'." >&2
      exit 1
    fi
    do_cmd_endpoints_refresh_cert
    ;;
  renew)
    echo "> Executing 'renew'..." >&2
    ensure_lego_vars
    ensure_env_var DIGITALOCEAN_ENDPOINT_ID

    lego $LEGO_ARGS renew --renew-hook "$0 renew-hook"
    if [ "$?" -ne 0 ]; then
      echo "Failed to renew '$LEGO_DOMAIN' using lego with DNS challenge." >&2
      exit 1
    fi
    ;;
  renew-hook)
    echo "> Executing 'renew-hook'..." >&2
    do_cmd_endpoints_refresh_cert
    ;;
  loop)
    LOOP_INTERVAL="${LOOP_INTERVAL:-1h}"
    echo "> Executing certificate update in a loop (interval: $LOOP_INTERVAL )" >&2
    while true; do
      echo "> Running '$0 run'..." >&2
      "$0" run
      
      NEXT_DATETIME="$(date -d "@$(next_date_timestamp "$LOOP_INTERVAL")")"
      echo "> Next run will be on '$NEXT_DATETIME' (in '$LOOP_INTERVAL')." >&2
      sleep "${LOOP_INTERVAL:-1h}"
    done
    ;;
  help)
    usage
    ;;
  *)
    echo "> Invalid command: $CMD $@" >&2
    usage >&2
    exit 1
esac

