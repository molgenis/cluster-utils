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
if [ ! -x "${SSH_LDAP_HELPER:-}" ]; then
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
	echo "       ${memyselfandi} will list by default all members of all groups you are a member of."
	echo "       ${memyselfandi} will sort group members on account name by default."
	echo
	echo 'Options:'
	echo '       -e          Sort group members by expiration date of their account as opposed to by account name.'
	echo '       -g all      Lists members of all groups including the ones you are not a member of.'
	echo '       -g GROUP    Lists members of the specified group GROUP.'
	echo '       -p          Plain text output: Disables coloring and other formatting using shell escape codes.'
	echo '                   Useful when redirecting the output to a log file.'
	echo
}

#
# Gets username, return enddate useraccount.
#
function _GetLoginExpirationTime() {
	local _user="${1}"
	local _user_cache_file="${ldap_cache_dir}/${_user}"
	local _loginExpirationTime="9999-99-99"
	local _regex='^loginexpirationtime=([0-9]{4})([0-9]{2})([0-9]{2}).+Z$'
	if [ -r "${_user_cache_file}" ]; then
		while IFS='' read -r _line || [[ -n "${_line}" ]]; do
			if [[ "${_line}" =~ ${_regex} ]]; then
				_loginExpirationTime="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
			fi
		done < "${_user_cache_file}"
	fi
	echo "${_loginExpirationTime}"
}

#
# Sorts user hashmap on date.
#
function _SortGroupMembersByDate() {
	declare -a _users=("${@}")
	declare -A _hashmap
	
	for _user in "${_users[@]}"; do
		_date=$(_GetLoginExpirationTime "${_user}")
		_hashmap["${_user}"]="${_date}"
	done
	#
	# Sort hashMap and store sorted users in $sorted_keys[@].
	#
	IFS=$'\n'; set -f
	group_members_sorted_by_exp_date=($(
		for _user in "${!_hashmap[@]}"; do
			printf '%s:%s\n' "${_user}" "${_hashmap[${_user}]}"
		done | sort -t ':' -k 2V | sed 's/:.*//'
	))
	unset IFS; set +f
}

function _PrintUserInfo() {
	local _user="${1}"
	local _format="${2}"
	local _loginExpirationTime="${3:-NA}"
	local _gecos
	IFS=':' read -a _user_info <<< "$(getent passwd ${_user} | cut -d ':' -s -f 1,5)"
	
	if [[ ${_loginExpirationTime} == '9999-99-99' || ${_loginExpirationTime} == 'NA' ]]; then
		_loginExpirationTime='Never'
	fi
	
	if [[ ${#_user_info[@]:0} -ge 1 ]]; then
		local _public_key="$(${SSH_LDAP_HELPER} -s ${_user})"
		if [[ -n "${_public_key}" ]]; then
			_gecos="${_user_info[1]:-NA}"
		else
			if [[ "${plain_text}" -eq 1 ]]; then
				_gecos="${_user_info[1]:-NA} (Inactive)"
			else
				_gecos="\e[2m${_user_info[1]:-NA} (Inactive)\e[22m"
			fi
		fi
	else
		if [[ ${_user} == 'MIA' || ${_user} == 'NA' ]]; then
			_user='MIA'
			if [[ "${plain_text}" -eq 1 ]]; then
				_gecos='Missing In Action.'
			else
				_gecos='\e[2mMissing In Action.\e[22m'
			fi
		else
			if [[ "${plain_text}" -eq 1 ]]; then
				_gecos='No details available (Not entitled to use this server/machine).'
			else
				_gecos='\e[2mNo details available (Not entitled to use this server/machine).\e[22m'
			fi
		fi
	fi
	printf "${_format}" "${_user}" "${_loginExpirationTime}" "${_gecos}";
}

#
##
### Main.
##
#

declare -a groups=()
declare -a group_members_sorted_by_exp_date=()
filesystem=''
total_width=110
base_header_length=25
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")
PADDING=$(head -c $((${total_width}-${base_header_length})) /dev/zero | tr '\0' ' ')
ldap_cache_dir="${HPC_ENV_PREFIX:-/apps}/.tmp/ldap_cache"

if [[ -d "${ldap_cache_dir}" ]]; then
	ldap_cache_timestamp="$(date --date="$(LC_DATE=C stat --printf='%y' "${ldap_cache_dir}" | cut -d ' ' -f1,2)" "+%Y-%m-%dT%H:%M:%S")"
fi

#
# Get commandline arguments.
#
sort_by='account'
plain_text=0
while getopts "g:ehp" opt; do
	case $opt in
		e)
			sort_by='login_expiration_date'
			;;
		h)
			_Usage
			exit
			;;
		p)
			plain_text=1
			;;
		g)
			group="${OPTARG}"
			;;
		\?)
			log4Bash "${LINENO}" "${FUNCNAME:-main}" '1' "Invalid option -${OPTARG}. Try $(basename $0) -h for help."
			;;
		:)
			log4Bash "${LINENO}" "${FUNCNAME:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename $0) -h for help."
			;;
		esac
done

#
# Configure formatting.
#
body_format="%-25b %-17b %-70b\n"
if [[ "${plain_text}" -eq 1 ]]; then
	group_header_format="%-${total_width}b\n"
	role_header_format="%-${total_width}b\n"
else
	group_header_format="\e[7m%-${total_width}b\e[27m\n"
	role_header_format="\e[1m%-${total_width}b\e[22m\n"
fi

#
# Compile list of groups.
#
if [[ -z ${group:-} ]]; then
	#
	# Get all groups of the current user.
	#
	IFS=' ' read -a groups <<< "$(id -Gn | tr ' ' '\n' | sort | tr '\n' ' ')"
else
	if [[ ${group} == 'all' ]]; then
		#
		# List all groups with group folders on this server.
		#
		IFS=' ' read -a groups <<< "$(find '/groups/' -mindepth 1 -maxdepth 1 -type d | grep -o '[^/]*$' | sort | tr '\n' ' ')"
	else
		#
		# Check if specified group exists.
		#
		if [[ $(getent group "${group}") ]]; then
			groups=("${group}")
		else
			_Usage
			echo "ERROR: specified group ${group} does not exist."
			exit 1
		fi
	fi
fi

#
# List owners, datamanagers and members per group.
#
this_user="$(whoami)"
regex='([^=]+)=([^=]+)'
for group in ${groups[@]}; do \
	if [[ "${group}" == ${this_user} ]]; then
		#
		# Skip private group.
		#
		continue
	fi
	echo "${SEP_DOUBLE}"
	group_header="Colleagues in the ${group} group:${PADDING:${#group}}"
	printf "${group_header_format}" "${group_header}"
	echo "${SEP_DOUBLE}"
	#
	# Fetch owner(s) and datamanager(s) from cached group meta-data.
	#
	cache_file="${ldap_cache_dir}/${group}"
	declare -a owners=('MIA')
	declare -a dms=('MIA')
	if [[ -r "${cache_file}" ]]; then
		while IFS=$'\n' read -r metadata_line; do
			#echo "DEBUG: parsing meta-data line ${metadata_line}."
			if [[ "${metadata_line}" =~ ${regex} ]]; then
				key="${BASH_REMATCH[1]}"
				val="${BASH_REMATCH[2]}"
				#echo "DEBUG: key = ${key} | val = ${val}."
				if [[ "${key}" == 'owner' ]]; then
					owners=($(printf '%s' "${val}" | tr ',' ' '))
					#echo "DEBUG: owners = ${owners[@]}."
				elif [[ "${key}" == 'datamanager' ]]; then
					dms=($(printf '%s' "${val}" | tr ',' ' '))
					#echo "DEBUG: dms = ${dms[@]}."
				else
					echo "WARN: Cannot parse meta-data line ${metadata_line}."
				fi
			fi
		done < "${cache_file}"
		printf "${role_header_format}" "${group} owner(s):"
		echo "${SEP_SINGLE}"
		for owner in "${owners[@]:-}"; do
			#echo "DEBUG: processing owner = ${owner}."
			_PrintUserInfo "${owner}" "${body_format}"
		done
		echo "${SEP_DOUBLE}"
		printf "${role_header_format}" "${group} datamanager(s):"
		echo "${SEP_SINGLE}"
		for dm in "${dms[@]:-}"; do
			_PrintUserInfo "${dm}" "${body_format}"
		done
		echo "${SEP_DOUBLE}"
	fi
	printf "${role_header_format}" "${group} member(s):"
	echo "${SEP_SINGLE}"
	IFS=' ' read -a group_members <<< "$(getent group ${group} | sed 's/.*://' | tr ',' '\n' | sort | tr '\n' ' ')"
	if [[ "${sort_by}" == 'login_expiration_date' ]]; then
		_SortGroupMembersByDate "${group_members[@]:-}"
		group_members=("${group_members_sorted_by_exp_date[@]:-}")
	fi
	for group_member in "${group_members[@]:-}"; do
		experationDate=$(_GetLoginExpirationTime "${group_member}")
		_PrintUserInfo "${group_member}" "${body_format}" "${experationDate}"
	done
done
echo "${SEP_DOUBLE}"
echo 'NOTE: Group memberships were fetched live from LDAP. All other data was fetched from the LDAP cache:'
echo "      ${ldap_cache_dir} last updated on ${ldap_cache_timestamp:-unknown}"
echo "${SEP_DOUBLE}"
