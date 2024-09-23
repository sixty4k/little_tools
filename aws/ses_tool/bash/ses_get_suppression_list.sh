#!/usr/local/bin/bash

aws-mfa &>/dev/null

aws_account=$1
aws_region=$2
date=$(date '+%Y-%m-%d')

## Are we enabled?

ses_test=$( assume-role ${aws_account} aws sesv2 get-account --region ${aws_region} 2>/dev/null | jq -r '.SendingEnabled' )

if [[ "${ses_test}" == "true" ]]; then

    mv ses_suppression_list-${aws_account}-${aws_region}-${date}.txt previous-ses_suppression_list-${aws_account}-${aws_region}-${date}.txt
    touch ses_suppression_list-${aws_account}-${aws_region}-${date}.txt

    function parse_output() {
      if [ ! -z "$cli_output" ]; then
        # The output parsing below also needs to be adapted as needed.
        echo $cli_output | jq -c '.SuppressedDestinationSummaries[] | [.LastUpdateTime, .Reason, .EmailAddress ]' >> ses_suppression_list-${aws_account}-${aws_region}-${date}.txt
        NEXT_TOKEN=$(echo $cli_output | jq -r ".NextToken")
      fi
    }



    unset NEXT_TOKEN

    aws_command="assume-role $aws_account aws sesv2 list-suppressed-destinations --region $aws_region"

    while [ "$NEXT_TOKEN" != "null" ]; do
      if [ "$NEXT_TOKEN" == "null" ] || [ -z "$NEXT_TOKEN" ] ; then
        echo "now running: $aws_command "
        sleep 3
        cli_output=$($aws_command 2>/dev/null)
        parse_output
      else
        echo "now paginating: $aws_command --starting-token $NEXT_TOKEN"
        sleep 3
        cli_output=$(assume-role $aws_account $aws_command --next-token $NEXT_TOKEN 2>/dev/null)
        parse_output
      fi
    done  #pagination loop

else

    echo "SES is not enabled or accessible for this account ( ${aws_account} ) and region ( ${aws_region} ) "
fi
