#!/usr/bin/env bash

set -Eeuo pipefail

msg() {
  echo -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat << _EOF_
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-d]  <domain_name>

Script description here.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-d, --domain    Set domain name
_EOF_
  exit
}

parse_params() {
  # default values of variables set from params
    DOMAIN=''

    while [[ $# -gt 0 ]]; do
    key="${1-}"
    value="${2-}"
    case "$key" in
        -h|--help)
            usage
        ;;
        -v|--verbose)
            set -x
        ;;
        -d|--domain)
            DOMAIN="$value"
            if ! [[ "$DOMAIN" =~ ^.*\.[a-z]+$ ]]; then
                die "Wrong format of domain name"
            fi 
        ;;
        -?*)
            die "Unknown option: $key"
        ;;
        *) break ;;
    esac
    shift
    done

    args=("$@")

    # check required params and arguments
    [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

    return 0
}

parse_params "$@"

which whois &> /dev/null || die "whois utility is not installed"

expiration_date=$(whois "$DOMAIN" | grep -E 'paid|Expir|expir' | grep -o -E '[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{4}.[0-9]{2}.[0-9]{2}|[0-9]{2}/[0-9]{2}/[0-9]{4}' | tr . / | awk 'NR == 1' || true)

if [[ -n "$expiration_date" ]]; then
    expiration_seconds=$(date -d "$expiration_date" '+%s')
    today_seconds=$(date '+%s')
    seconds_left=$((expiration_seconds - today_seconds))
    days_left=$(( seconds_left / 86400 ))
else
    die "There is no info about domain: $DOMAIN"
fi

msg "$days_left"