# SES Tool

This tool allows for interacting with the SES suppression list, to review addresses that have been blocked, unblock specific addresses, or clear the whole list.

This tool is a slightly easier way to do the tasks, rather than directly using the `awscli` directly or via bash scripts.

## Prereqs

* You'll need python (3.11 is what I'm using)
  `brew install python@3.11`
* `virtualenv` or `venv`
* (optional) aws config with profiles defined
  * add your profile on line 34, defining what regions to look in


If your AWS config uses materially different naming conventions, just pass those in as the `ACCOUNT` but be sure to set `REGION` as well.

## Setup

```
python3.11 -m venv .
. bin/activate
pip install -r requirements.txt
```

## Functions

Basic usage:

```
usage: ses_tool.py [-h] [-r REGION] [-a ACCOUNT] [-e EMAIL [EMAIL ...] | -d
                   DOMAIN] [-j | -c]
                   ACTION

Smart AWS SES tool

positional arguments:
  ACTION                Action to take

options:
  -h, --help            show this help message and exit
  -r REGION, --region REGION
                        Set the region
  -a ACCOUNT, --account ACCOUNT
                        Set the AWS Account
  -e EMAIL [EMAIL ...], --email EMAIL [EMAIL ...]
                        Email address(es) for CHECK or DEL actions
  -d DOMAIN, --domain DOMAIN
                        Email domain for CHECK or DEL actions
  -j, --json            Output in JSON format, the default
  -c, --csv             Output in csv format

actions:
  GET     Get the full suppression list
  CHECK   Check if an email is suppressed
  DEL     Delete an email from the suppression list
  ```

### Accounts

the `-a` `--account` expects a _profile_ name from your `~/.aws/config`, if you have not added your profiles to the script, you'll need to pass in both account profile name, _and_ SES regions.

### Email or Domain

For `CHECK` or `DEL` functions, you need to provide an email address(es) in the form of `name@domain.tdl`, or a domain, in the form of `domain.tld`


### GET

This gets the full suppression list from the active SES regions for an aws account.

### CHECK/DEL

These take an email address (or multiple addresses) and checks for, or deletes from, the suppression list.

## But Mike, don't you love BASH!?

See the `/bash` subfolder for the first draft and how crufty it was already getting

