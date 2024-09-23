#!/usr/bin/env python

import csv
import sys
import boto3
import argparse
import textwrap
import simplejson
from datetime import date, datetime
from pprint import pprint


parser = argparse.ArgumentParser(description='Smart AWS SES tool',
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=textwrap.dedent('''\
                                    actions:
                                      GET   \tGet the full suppression list
                                      CHECK \tCheck if an email is suppressed
                                      DEL   \tDelete an email from the suppression list
                                      ''')
                                 )
parser.add_argument('-r', '--region', help="Set the region")
parser.add_argument('-a', '--account', help="Set the AWS Account", default='prod')
parser.add_argument('ACTION', help="Action to take")
group = parser.add_mutually_exclusive_group()
group.add_argument('-e', '--email', nargs='+', help="Email address(es) for CHECK or DEL actions")
group.add_argument('-d', '--domain', help="Email domain for CHECK or DEL actions")
group2 = parser.add_mutually_exclusive_group()
group2.add_argument('-j', '--json', action='store_true', help="Output in JSON format, the default", dest='json_or_csv', default=True)
group2.add_argument('-c', '--csv', action='store_false', help="Output in csv format", dest='json_or_csv')

args = parser.parse_args()

regions = {
    'default': ['us-east-1', 'us-east-2'],
}

def check_regions():
    if args.region:
        return [args.region]
    else:
        return regions.get(args.account, ['eu-west-1', 'eu-west-2'])

def json_serial(obj):
    """JSON serializer for objects not serializable by default json code"""

    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError ("Type %s not serializable" % type(obj))

def ses_check():
    # If this doesn't return true, we should just barf out.
    try:
        response = client.get_account()
        return response["SendingEnabled"]

    except client.exceptions.ClientError as e:
        print("Access error: %s" % e)
        return False

    except:
        return False

def get_suppression_list():
    ## Get Suppression List
    ## Response Form
    # {
    #     'SuppressedDestinationSummaries': [
    #         {
    #             'EmailAddress': 'string',
    #             'Reason': 'BOUNCE'|'COMPLAINT',
    #             'LastUpdateTime': datetime(2015, 1, 1)
    #         },
    #     ],
    #     'NextToken': 'string'
    # }
    ses_supress = client.list_suppressed_destinations()
    ses_supress_list = (ses_supress['SuppressedDestinationSummaries'])

    while "NextToken" in ses_supress:
        ses_supress = client.list_suppressed_destinations(NextToken=ses_supress["NextToken"])
        ses_supress_list.extend(ses_supress['SuppressedDestinationSummaries'])

    return ses_supress_list

def is_suppressed(email):
    # response form
    # {
    #     'SuppressedDestination': {
    #         'EmailAddress': 'string',
    #         'Reason': 'BOUNCE'|'COMPLAINT',
    #         'LastUpdateTime': datetime(2015, 1, 1),
    #         'Attributes': {
    #             'MessageId': 'string',
    #             'FeedbackId': 'string'
    #         }
    #     }
    # }
    # Check if an email has been supressed
    try:
        response = client.get_suppressed_destination(EmailAddress=email)

    except client.exceptions.NotFoundException:
        return False

    except:
        print("Unable to check " + email)

        response["SuppressedDestination"]["Reason"]

    else:
        return True

def remove_suppressed(email):
    # Response form:
    # { }
    try:
        response = client.delete_suppressed_destination(EmailAddress=email)
    except:
        print("Something went wrong, deleting: " + email)
    else:
        return True


for region in check_regions():
    session = boto3.Session(profile_name=args.account)
    client = session.client('sesv2', region_name=region)
    if ses_check():
        match args.ACTION.lower():
            case "get":
                filename = "%s-%s-suppression-list" % (args.account, region)
                if args.json_or_csv:
                    with open(filename + '.json', 'w') as output:
                        output.write(simplejson.dumps(get_suppression_list(), default=json_serial, indent=2 ))
                elif not args.json_or_csv:
                    with open(filename + '.csv', 'w') as output:
                        supress_dict=get_suppression_list()
                        csvout = csv.DictWriter(output, dialect='excel',fieldnames=supress_dict[0].keys())
                        csvout.writeheader()
                        csvout.writerows(supress_dict)

            case "check":
                if args.email:
                    for emailaddy in args.email:
                        if is_suppressed(emailaddy):
                            print(emailaddy + " is on the suppression list for " + args.account + " in " + region)
                        else:
                            print(emailaddy + " is *NOT* on the suppression list for " + args.account + " in " + region)

                elif args.domain:
                    suslist = get_suppression_list()

                    if args.json_or_csv:
                        for entry in suslist:
                            if args.domain in entry['EmailAddress']:
                                print(simplejson.dumps(entry, default=json_serial ))

                    else:
                        output = sys.stdout
                        csvout = csv.DictWriter(output, dialect='excel',fieldnames=suslist[0].keys())
                        csvout.writeheader()
                        for entry in suslist:
                            if args.domain in entry['EmailAddress']:
                                csvout.writerow(entry)


                else:
                    print("Must include an email or domain to check for!")

            case "del":
                if args.email:
                    for emailaddy in args.email:
                        if is_suppressed(emailaddy):
                            remove_suppressed(emailaddy)
                            print(emailaddy + " removed from suppression list for " + args.account + " in " + region)
                        else:
                            print(emailaddy + " was *NOT* on the suppression list for " + args.account + " in " + region)

                elif args.domain:
                    suslist = get_suppression_list()
                    for email in [ entry['EmailAddress'] for entry in suslist]:
                        if args.domain in email:
                            remove_suppressed(email)
                            print(email + " removed from suppression list for " + args.account + " in " + region)

                else:
                    print("Must include an email or domain to delete!")


    else:
        print("SES isn't available _to you_ in region: " + region)
        exit()
