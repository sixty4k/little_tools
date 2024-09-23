#!/usr/local/bin/bash

aws-mfa &>/dev/null

aws_account=$3
aws_region=$4

remove_email() {
  if assume-role $aws_account aws sesv2 delete-suppressed-destination --email-address ${1} --region $aws_region; then
    echo "Removed email ${1} from $aws_account $aws_region SES Supression List"
  else
    echo "Unable to remove ${i}"
  fi
}

ses_test=$( assume-role ${aws_account} aws sesv2 get-account --region ${aws_region} 2>/dev/null | jq -r '.SendingEnabled' )

if [[ "${ses_test}" == "true" ]]; then



  if [[ "${1}" == "-d" ]]; then
    # remove all users in that domain
    domain=$2

    for email in $(grep ${domain} ses_suppression_list-*.txt | jq -r '.[2]'); do
      remove_email ${email}
    done

  elif [[ "${1}" == "-e" ]]; then
    # remove specifc user from suppression list
    remove_email ${2}
  fi


else

    echo "SES is not enabled or accessible for this account ( ${aws_account} ) and region ( ${aws_region} ) "
fi
