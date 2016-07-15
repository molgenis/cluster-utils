#!/bin/bash

#
##
### Environment and bash sanity.
##
#
set -u
set -e
umask 0027
memyselfandi=$(basename $0)
if [[ "${BASH_VERSINFO}" -lt 4 || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Sorry, you need at least bash 4.x to use ${memyselfandi}." >&2
  exit 1
fi

#
##
### Functions.
##
#

function _Usage() {
    echo
    echo 'Usage:'
    echo "       ${memyselfandi}              Lists account info for the current user."
    echo "       ${memyselfandi} some-user    Lists account info for the specified user."
    echo
}

#
##
### Main.
##
#
format="%-16s: %-s\n"
total_width=101
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")

#
# Get user.
#
declare user=''
if [[ -z ${1:-} ]]; then
    #
    # Get the current user.
    #
    user="$(id -nu | tr -d '\n')"
else
    #
    # Check if specified user exists
    #
    if [ ! -z "$(getent passwd ${1})" ]; then
        user="${1}"
    else
        _Usage
        echo "FATAL: user ${1} does not exist."
        exit 1
    fi
fi

#
# List details for user.
#
echo "${SEP_DOUBLE}"
echo "Basic account details for ${user}:"
echo "${SEP_SINGLE}"
#
# Get basic details from passwd.
#
IFS=':' read -a user_info <<< "$(getent passwd ${user} | cut -d ':' -s -f 1,3,5,6,7)"
if [[ ${#user_info[@]:0} -eq 5 ]]; then
    printf "${format}" 'User'  "${user_info[0]} (${user_info[1]})"
    printf "${format}" 'Home'  "${user_info[3]}"
    printf "${format}" 'Shell' "${user_info[4]}"
    printf "${format}" 'Mail'  "${user_info[2]}";
else
    echo "FATAL: cannot parse getent output."
fi
echo "${SEP_SINGLE}"
#
# Get primary group.
#
echo "Authorization for ${user}:"
echo "${SEP_SINGLE}"
primary_group="$(id -gn ${user})"
primary_group="${primary_group} ($(id -g ${user}))"
printf "${format}" 'Primary group'  "${primary_group}";
#
# Get secondary groups.
#
IFS=' ' read -a secondary_groups <<< "$(id -Gn  ${user} | tr ' ' '\n' | sort | tr '\n' ' ')"
    for secondary_group in ${secondary_groups[@]:-}; do
        secondary_group="${secondary_group} ($(getent group ${secondary_group} | cut -d ':' -s -f 3))"
        if [ "$secondary_group" == "${primary_group}" ]; then
            continue
        else
            printf "${format}" 'Secondary group'  "${secondary_group}"
        fi
    done
echo "${SEP_SINGLE}"
#
# Authentication.
#
echo "Public key(s) for ${user}:"
echo "${SEP_SINGLE}"
public_key="$(/usr/libexec/openssh/ssh-ldap-helper -s ${user})"
echo "${public_key}"
echo "${SEP_DOUBLE}"