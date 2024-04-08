#!/usr/bin/env bash

action=li

if ! aws sts get-caller-identity --profile default 2>/dev/null; then
    aws sso login --profile default
fi

if [ "$#" -eq 1 ]; then
    if [[ "$1" == "logout" ]]; then
        action=lo
    else
        profile_list="$@"
    fi
fi

[[ -z "$profile_list" ]] && profile_list=$(aws configure list-profiles | grep -v default)

for profile in ${profile_list}; do
    echo ${profile}

    if [[ $action == "lo" ]]; then
        aws sso logout --profile ${profile} &>/dev/null
    else
        if aws sts get-caller-identity --profile ${profile} 2>/dev/null; then
            echo
        else
            aws sso login --profile ${profile} &>/dev/null
            sleep 2
            aws sts get-caller-identity --profile ${profile}
            echo
        fi
    fi
done
