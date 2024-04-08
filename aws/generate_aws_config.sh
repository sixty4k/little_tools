#!/usr/bin/env bash

# Put in your good stuff...
sso_region=
sso_account_id=
sso_role_name=

if [ -d ~/.aws ]; then
    mv ~/.aws/config ~/.aws/config.$(date +%Y%m%d).bak 2>/dev/null
else
    mkdir ~/.aws
fi

cat > ~/.aws/config<< _config_stanza_end
[default]
sso_start_url = https://vu.awsapps.com/start
sso_region = ${sso_region}
sso_account_id = ${sso_account_id}
sso_role_name = ${sso_role_name}
region = ${sso_region}
output = json
cli_pager=

[sso-session default]
sso_start_url = https://vu.awsapps.com/start
sso_region = ${sso_region}
sso_registration_scopes = sso:account:access

[profile orgroot]
sso_session = default
sso_account_id = ${sso_account_id}
sso_role_name = ${sso_role_name}
region = ${sso_region}

_config_stanza_end

aws sso login --profile orgroot
echo

cp ~/.aws/config aws_config

for account_and_name in $(aws organizations list-accounts --profile orgroot | jq -c '.Accounts[] | select(.Status=="ACTIVE") | [ .Name, .Id ]' | tr " " "_" | sort); do

    ## Account ID and Name

    account=$(jq -r '.[1]' <<< $account_and_name)
    name=$(jq -r '.[0]' <<< $account_and_name)

    ## Profile Name for ~/.aws/config
    profile_name=$(echo $name | sed -e's/-//g' -e's/_//g' | tr '[:upper:]' '[:lower:]')

    ## Region
    region=

    # to find the allowed regions, we're going to do some roundabout stupidity.
    OU_id=$(aws organizations list-parents --child-id ${account} --profile orgroot | jq -r .Parents[].Id)

    OU_policy=$(aws organizations list-policies-for-target --target-id ${OU_id} --filter SERVICE_CONTROL_POLICY --profile orgroot | jq -r '.Policies[] | select(.Name | contains("regions")) | .Id')

    if [[ -n ${OU_policy} ]]; then
        pol_regions=$(aws organizations describe-policy --policy-id ${OU_policy} --profile orgroot | jq -r '.Policy | .Content' | jq '.Statement[].Condition.StringNotEquals."aws:RequestedRegion" | map(select(. != "us-east-1")) ')

        region_count=$(jq '. | length' <<< ${pol_regions})

        if [[ ${region_count} -eq 1 ]]; then
            region=$(jq -r .[] <<< ${pol_regions})
            reg_source="OU Policy"

        elif [[ ${region_count} -gt 1 ]]; then
            region=$(echo ${pol_regions} | jq '.[0]')
            reg_source="OU Policy"

        else
            region=${sso_region}
            reg_source="using SSO Region"

        fi

    else
        region=${sso_region}
        reg_source="using SSO Region"

    fi

    ## Share our findings...
    echo "account: " $account
    echo "name: " $name
    echo "profile name: " $profile_name
    echo "SCP Policies: " $OU_policy
    echo "region: " $region
    echo "region source: " $reg_source

    ## Create a new ~/.aws/config file
cat >> aws_config<< _config_stanza_end
[profile ${profile_name}]
sso_session = default
sso_account_id = ${account}
sso_role_name = ${sso_role_name}
region = ${region}
output = json
cli_pager=

_config_stanza_end

done

if diff -q ~/.aws/config.$(date +%Y%m%d).bak aws_config 2>/dev/null ; then
    echo "Generated ~/.aws/config file and existing config match, no action"
    rm aws_config
    mv ~/.aws/config.$(date +%Y%m%d).bak ~/.aws/config

else
    echo "Generated ~/.aws/config differs from existing, replace? [y/n]"
    read yesno
    final_answer=$(echo $yesno | tr '[:upper:]' '[:lower:]')

    case ${final_answer::1} in
        "y" )
            mv aws_config ~/.aws/config
            ;;

        * )
            echo "generated file is here: $(pwd)/aws_config"
            [ -f  ~/.aws/config.$(date +%Y%m%d).bak ] && mv ~/.aws/config.$(date +%Y%m%d).bak ~/.aws/config
            ;;
    esac
fi
