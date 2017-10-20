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

set +e
SSH_LDAP_HELPER="$(which ssh-ldap-helper 2>/dev/null)"
set -e
SSH_LDAP_HELPER="${SSH_LDAP_HELPER:-/usr/libexec/openssh/ssh-ldap-helper}"
if [ ! -x ${SSH_LDAP_HELPER:-} ]; then
    echo "WARN: Cannot find ssh-ldap-helper, which is required to determine if users are (in)active."
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
    echo "       ${memyselfandi} all           Lists members of all groups active on this server."
    echo "       ${memyselfandi} some-group    Lists members of group some-group."
    echo
}

function _PrintUserInfo() {
    local _user="${1}"
    local _format="${2}"
    #echo "DEBUG: _user   = ${_user}."
    #echo "DEBUG: _format = ${_format}."
    IFS=':' read -a _user_info <<< "$(getent passwd ${_user} | cut -d ':' -s -f 1,5)"
    if [[ ${#_user_info[@]:0} -eq 2 ]]; then
        local _public_key="$(${SSH_LDAP_HELPER} -s ${_user})"
        if [[ -n "${_public_key}" ]]; then
            printf "${_format}" "${_user_info[@]}";
        else
            printf "${_format}" "${_user_info[0]}" "\e[2m${_user_info[1]} (Inactive)\e[22m";
        fi
    else
        if [ ${_user} == 'MIA' ]; then
            printf "${_format}" "${_user}" '\e[2mMissing In Action.\e[22m';
        else
            printf "${_format}" "${_user}" '\e[2mNo details available (Not entitled to use this server/machine).\e[22m';
        fi
    fi
}


#
##
### Main.
##
#

filesystem=''
total_width=101
base_header_length=25
body_format="%-25b %-76b\n"
header_format="%-${total_width}b\n"
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")
PADDING=$(head -c $((${total_width}-${base_header_length})) /dev/zero | tr '\0' ' ')
groups_metadata_cache_dir="${HPC_ENV_PREFIX}/.tmp/groups_metadata_cache"
if [ -d ${groups_metadata_cache_dir} ]; then
    groups_metadata_cache_timestamp="$(date --date="$(LC_DATE=C stat --printf='%y' "${groups_metadata_cache_dir}" | cut -d ' ' -f1,2)" "+%Y-%m-%dT%H:%M:%S")"
fi

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
# List owners, datamanagers and members per group.
#
regex='([^=]+)=([^=]+)'
for group in ${groups[@]}; do \
    echo "${SEP_DOUBLE}"
    group_header="\e[7mColleagues in the ${group} group:${PADDING:${#group}}\e[27m"
    printf "${header_format}" "${group_header}"
    echo "${SEP_DOUBLE}"
    #
    # Fetch owner(s) and datamanager(s) from cached group meta-data.
    #
    cache_file="${groups_metadata_cache_dir}/${group}"
    declare -a owners=('MIA')
    declare -a dms=('MIA')
    if [ -r ${cache_file} ]; then
        while IFS=$'\n' read -r metadata_line; do
            #echo "DEBUG: parsing meta-data line ${metadata_line}."
            if [[ "${metadata_line}" =~ ${regex} ]]; then
                key="${BASH_REMATCH[1]}"
                val="${BASH_REMATCH[2]}"
                #echo "DEBUG: key = ${key} | val = ${val}."
                if [ "${key}" == 'owner' ]; then
                    owners=($(printf '%s' "${val}" | tr ',' ' '))
                    #echo "DEBUG: owners = ${owners[@]}."
                elif [ "${key}" == 'datamanager' ]; then
                    dms=($(printf '%s' "${val}" | tr ',' ' '))
                    #echo "DEBUG: dms = ${dms[@]}."
                else
                    echo "WARN: Cannot parse meta-data line ${metadata_line}."
                fi
            fi
        done < "${cache_file}"
        printf "${header_format}" "\e[1m${group} owner(s):\e[22m"
        echo "${SEP_SINGLE}"
        for owner in ${owners[@]:-}; do
            #echo "DEBUG: processing owner = ${owner}."
            _PrintUserInfo "${owner}" "${body_format}"
        done
        echo "${SEP_DOUBLE}"
        printf "${header_format}" "\e[1m${group} datamanager(s):\e[22m"
        echo "${SEP_SINGLE}"
        for dm in ${dms[@]:-}; do
            _PrintUserInfo "${dm}" "${body_format}"
        done
        echo "${SEP_DOUBLE}"
    fi
    printf "${header_format}" "\e[1m${group} member(s):\e[22m"
    echo "${SEP_SINGLE}"
    IFS=' ' read -a group_members <<< "$(getent group ${group} | sed 's/.*://' | tr ',' '\n' | sort | tr '\n' ' ')"
    for group_member in ${group_members[@]:-}; do
        _PrintUserInfo "${group_member}" "${body_format}"
    done
done
echo "${SEP_DOUBLE}"
echo 'NOTE: Group memberships were fetched live from LDAP. All other data was fetched from the LDAP cache:'
echo "      ${groups_metadata_cache_dir} last updated on ${groups_metadata_cache_timestamp:-unknown}"
echo "${SEP_DOUBLE}"