#!/bin/bash

set -e

SHOW_MESSAGE=false

if [[ $# -eq 0 ]]; then
    SHOW_MESSAGE=false
fi

while [[ "$1" != "" ]]; do
    case $1 in
    -m | --show-message)
        SHOW_MESSAGE=true
        ;;

    *)
        usage
        exit 1
        ;;
    esac

    shift
done

if [[ $SHOW_MESSAGE == true ]]; then
    echo -e "\033[0;36mLoading azd .env file from current environment...\033[0m"
fi

# while IFS='=' read -r key value; do
#     value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
#     export "$key=$value"
# done <<EOF
# $(azd env get-values)
# EOF

while IFS= read -r line; do
    if [[ $line =~ ^([^=]+)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]//\"}"
        export "$key"="$value"
    fi
done < <(azd env get-values)
