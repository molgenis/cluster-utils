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
    echo "       ${memyselfandi}               Lists members of my groups active on this server."
    echo "       ${memyselfandi} all           lists members of all groups active on this server."
    echo "       ${memyselfandi} some-group    lists members of group some-group."
    echo
}

#
##
### Main.
##
#

filesystem=''
format="%-25s %-75s\n"
total_width=101
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")

#
# Compile list of groups.
#
declare -a groups=("")
if [[ -z ${1:-} ]]; then
    #
    # Get all groups of the current user.
    #
    IFS=' ' read -a groups <<< "$(id -Gn | tr ' ' '\n' | sort | tr '\n' ' ')"
else
    if [ ${1} == 'all' ]; then
        #
        # List all groups with group folders on this server.
        #
        IFS=' ' read -a groups <<< "$(find '/groups/' -mindepth 1 -maxdepth 1 -type d | grep -o '[^/]*$' | sort | tr '\n' ' ')"
    else
        #
        # Check if specified group exists
        #
        if [ $(getent group ${1}) ]; then
            groups=("${1}")
        else
            _Usage
        fi
    fi
fi

#
# List members per group.
#
for group in ${groups[@]}; do \
    echo "${SEP_DOUBLE}"
    echo "Group ${group} contains members:"
    echo "${SEP_SINGLE}"
    IFS=' ' read -a group_members <<< "$(getent group ${group} | sed 's/.*://' | tr ',' '\n' | sort | tr '\n' ' ')"
    for group_member in ${group_members[@]:-}; do
        IFS=':' read -a member_info <<< "$(getent passwd ${group_member} | cut -d ':' -s -f 1,5)"
        if [[ ${#member_info[@]:0} -eq 2 ]]; then
            printf "${format}" "${member_info[@]}";
        fi
    done
done
echo "${SEP_DOUBLE}"