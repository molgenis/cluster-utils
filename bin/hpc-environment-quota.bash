#!/bin/bash
#
# Script to report quota for user and his groups on several dirs from shared/network storage.
#

#
##
### Environment and bash sanity.
##
#
if [[ "${BASH_VERSINFO}" -lt 4 || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Sorry, you need at least bash 4.x to use ${0}." >&2
  exit 1
fi
set -u
set -e
umask 0027

#
# Set ${TMPDIR} to /tmp, which is usually on localhost.
# Prevents not being able to check quota, because quota were exceeded on one of our large TMP file systems.
#
export TMPDIR='/tmp/'

#
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR
#
trap 'reportError $LINENO' HUP INT QUIT TERM EXIT ERR

#
##
### Functions.
##
#
function showHelp() {
  #
  # Display commandline help on STDOUT.
  #
  cat <<EOH
===============================================================================================================
 Lists quota status for the current user and its groups (default).

 Usage:

   $(basename $0) OPTIONS

OPTIONS:

   -a   List quota for all groups instead of only for the groups the user executing this script is a member of 
        (root user only).

Details:

   The report will show 11 columns:
   
    1 Quota type = one of:
       (U) = user quota
       (P) = (private) group quota: group with only one user and mostly used for home dirs.
       (G) = (regular) group quota: group with multiple users.
       (F) = file set quota: in our setup different tech to manage quota for a group with multiple users.
    2 Path/Filesystem = (part of) a storage system controlled by the quota settings listed.
    3 used   = total amount of disk space your data consumes.
    4 quota  = soft limit for space.
    5 limit  = hard limit for space.
    6 grace  = days left before the timer for space quota expires.
    7 used   = total number of files and folders your data consists of.
    8 quota  = the soft limit for the number of files and folder.
    9 limit  = the hard limit for the number of files and folders.
   10 grace  = days left before the timer for the number of files and folders quota expires.
   11 status = whether you exceed your quota or not.
   
   Grace is the time you can temporarily exceed the quota (soft limit) up to max the hard limit.
   When there is no grace time left the soft limit will temporarily become a hard limit 
   until the amount of used resources drops below the quota, which will reset the timer.
   Grace is 'none'
    * when the quota (soft) limit has not been exceeded or
    * when the quota (soft) limit has been exceeded and there is no grace time left or
    * when the hard limit has been exceeded.
   Grace is reported as remaining time when the quota (soft) limit has been exceeded, 
   but the hard limit has not been reached yet and the grace timer has not yet expired.
===============================================================================================================

EOH
  #
  # Reset trap and exit.
  #
  trap - EXIT
  exit 0
}

function reportError() {
  local SCRIPT_NAME=$(basename $0)
  local PROBLEMATIC_LINE=$1
  local exit_status=${2:-$?}
  local ERROR_MESSAGE="Unknown error."
  local errorMessage=${3:-"${ERROR_MESSAGE}"}
  #
  # Notify syslog.
  #
  #logger ${LOG2STDERR} "$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: FATAL: quota reporting FAILED!"
  #logger ${LOG2STDERR} "$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: Exit code = $exit_status"
  #logger ${LOG2STDERR} "$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: Error message = ${errorMessage}"
  #
  # Notify on STDOUT.
  #
  echo "
$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: FATAL: quota reporting FAILED!
$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: Exit code = $exit_status
$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: Error message = ${errorMessage}
"
  #
  # Reset trap and exit.
  #
  trap - EXIT
  exit $exit_status
}

#
# GPFS has dedicated quota tools with output that deviates from the normal quota reporting.
# This function parses the mmlsquota (GPFS) output with some site specific hacks 
# and formats the result using printf with a format as specified by the ${format} variable.
#
function getFileSetQuotaForGPFS() {
  #
  # GPFS example file set quota.
  #
  #                          Block Limits                                    |     File Limits
  # Filesystem type             GB      quota      limit   in_doubt    grace |    files   quota    limit in_doubt    grace  Remarks
  # scratch    FILESET       36517      51200      51200          1     none |  1048947       0        0      301     none target02.local
  #
  local _group="$1"
  local _fs_name="${_group}" # fileset_name used for mmlsquota commandline tool
  local _QUOTA='/usr/lpp/mmfs/bin/mmlsquota'
  local _BSIZE='1'
  local _BUNIT='T'
  local _size_used=2
  local _size_quota=3
  local _size_limit=4
  local _size_in_doubt=5
  local _size_grace=6
  local _files_used=8
  local _files_quota=9
  local _files_limit=10
  local _files_in_doubt=11
  local _files_grace=12
  local _LFS=''
  local _fs_path='' # fileset_path used for reporting to users.
  for _FILESYS in $(awk '$3 == "gpfs" {print $1}' /proc/mounts | sort)
  do
    _FILESYS=${_FILESYS/\/dev\//}
    if [ ${_FILESYS} == 'gpfs2' ]; then
      _LFS='tmp02'
    else 
      reportError ${LINENO} $? 'Unknown GPFS detected. Request admin to update quota reporting!'
      #
      # Handle exceptions in paths, file set names, etc.
      #
    fi
    if [ ${_group} == ${DEPLOY_ADMIN_GROUP} ]; then
      _fs_path="/.envsync/${_LFS}"
    else
      _fs_path="/groups/${_group}/${_LFS}"
    fi
    local _fileset_quota="$(${_QUOTA} -j ${_fs_name} ${_FILESYS} --block-size ${_BSIZE}${_BUNIT} 2> /dev/null)"  || reportError ${LINENO} $?
    IFS=' ' read -a _body_values   <<< $(echo "${_fileset_quota}" | tail -n 1)                                   || reportError ${LINENO} $?
    if [[ ! -z ${_body_values[0]:-} && ${#_body_values[@]:-} -eq 14 ]]; then
      declare -a _quota_values=("${_fs_path}" 
                 "${_body_values[${_size_used}]}${_BUNIT}" "${_body_values[${_size_quota}]}${_BUNIT}" "${_body_values[${_size_limit}]}${_BUNIT}" "${_body_values[${_size_grace}]}" 
                 "${_body_values[${_files_used}]}" "${_body_values[${_files_quota}]}" "${_body_values[${_files_limit}]}" "${_body_values[${_files_grace}]}")
      printQuota 'F' "${_quota_values[@]}"
    fi
  done
}

#
# LustreFS has dedicated quota tools with output that deviates from the normal quota reporting.
# This function parses the lfs quota output with some site specific hacks 
# and formats the result using printf with a format as specified by the ${format} variable.
#
function getGroupQuotaForLustreFS() {
  #
  # lfs quota examples.
  #
  # $~> lfs quota -h -g umcg-gaf /groups/umcg-gaf/tmp04
  # Disk quotas for group umcg-gaf (gid 55100132):
  #      Filesystem    used   quota   limit   grace   files   quota   limit   grace
  # /groups/umcg-gaf/tmp04
  #                  23.09T*    15T     20T       -  334110       0       0       -
  #
  # $~> lfs quota -h -g umcg-pneerincx /home
  # Disk quotas for group umcg-pneerincx (gid 50100292):
  #      Filesystem    used   quota   limit   grace   files   quota   limit   grace
  #           /home  356.4M      1G      2G       -    7159       0       0       -
  #
  local _group="$1"
  local _size_used=1
  local _size_quota=2
  local _size_limit=3
  local _size_grace=4
  local _files_used=5
  local _files_quota=6
  local _files_limit=7
  local _files_grace=8
  #
  # Loop over Logical File Systems (LFS-ses).
  #
  for _LFS in $(awk '$3 == "lustre" {print $2}' /proc/mounts | sort)
  do
    local _quota_type='G' # default.
    #
    # Handle exceptions in paths, group names, etc.
    #
    if [ "${_group}" == ${DEPLOY_ADMIN_GROUP} ]; then
      #
      # Deploy Admins (depad) group only uses specific LFS-ses.
      #
      if [[ ${_LFS} != '/apps'* ]] && [[ ${_LFS} != '/.envsync'* ]] ; then
        continue
      fi
    elif [ "${_group}" == "${MY_USER}" ]; then
      #
      # User's private group only uses /home LFS.
      #
      if [ "${_LFS}" != '/home'* ]; then
        continue
      fi
      _quota_type='P'
    else
      #
      # User's regular group only uses /groups/... LFS.
      #
      if [[ "${_LFS}" != '/groups/'${_group}'/'* ]]; then
        continue
      fi
    fi
    local _lfs_quota="$(lfs quota -q -h -g ${_group} ${_LFS} 2> /dev/null | tr -d '\n')"  || reportError ${LINENO} $?
    IFS=' ' read -a _body_values   <<< $(echo "${_lfs_quota}" | tail -n 1)                || reportError ${LINENO} $?
    if [[ ! -z ${_body_values[0]:-} && ${#_body_values[@]:-} -eq 9 ]]; then
      declare -a _quota_values=("${_LFS}" 
                 "${_body_values[${_size_used}]}"  "${_body_values[${_size_quota}]}"  "${_body_values[${_size_limit}]}"  "${_body_values[${_size_grace}]}" 
                 "${_body_values[${_files_used}]}" "${_body_values[${_files_quota}]}" "${_body_values[${_files_limit}]}" "${_body_values[${_files_grace}]}")
      printQuota "${_quota_type}" "${_quota_values[@]}"
    fi
  done
}


#
# This function parses a single line of plain vanilla Linux quota tools output
# and formats the result using printf with a format as specified by the ${format} variable.
#
function parseAndFormatRegularQuota() {
  local _quota_type="$1"
  local _quota_report_line="$2"
  #
  # Parse string into array.
  #
  IFS=' ' read -a _quota_values <<< $(echo "${_quota_report_line}") || reportError ${LINENO} $?
  #
  # Check for missing and wrong grace values.
  #
  local _regex='[0-9]{5}days'
  if [[ "${_quota_values[1]}" =~ '*' ]]; then # Check for size (bytes) quota
    #
    # Fix grace reporting bug when grace has expired.
    # (Bug will result in ridiculous high grace value starting at 49697days and counting down.)
    #
    if [[ "${_quota_values[4]}" =~ ${_regex} ]]; then
      _quota_values[4]='0days'
    fi
  else
    #
    # The quota (soft) limit was not exceeded and a grace value is missing / not reported.
    # Insert 'none' to prevent shifting values.
    #
    _quota_values=("${_quota_values[@]:0:4}" 'none' "${_quota_values[@]:4}")
  fi
  if [[ "${_quota_values[5]}" =~ '*' ]]; then # Check for files (inodes) quota
    #
    # Fix grace reporting bug when grace has expired.
    # (Bug will result in ridiculous high grace value starting at 49697days and counting down.)
    #
    
    if [[ "${_quota_values[8]}" =~ ${_regex} ]]; then
      _quota_values[8]='0days'
    fi
  else
    #
    # The quota (soft) limit was not exceeded and a grace value is missing / not reported.
    # Insert 'none' to prevent shifting values.
    #
    _quota_values=("${_quota_values[@]}" 'none')
  fi
  printQuota "${_quota_type}" "${_quota_values[@]}"
}

#
# Polish quota values for pretty printing and print.
#
function printQuota() {
  local _status='Ok' # default.
  local _quota_type="${1}"
  shift
  declare -a local _quota_values=("${@}")
  #echo "DEBUG _quota_values: ${_quota_values[@]}"
  #
  # Check and append status.
  #
  #   Set status to Ok and switch to quota EXCEEDED when: 
  #    * either the consumed resource values are suffixed with and asterisk (*)
  #    * or the consumed resource values exceed the quota (soft limit) values.
  #    * or the timer was triggered and the grace value is not 'none'.
  #
  local _regex='\*$'
  for offset in {1,5}; do
    #echo "DEBUG _quota_values ${offset}: ${_quota_values[${offset}]}"
    if [[ "${_quota_values[${offset}]}" =~ ${_regex} ]]; then
      _status='\e[5mEXCEEDED!\e[25m'
    fi
    #if [[ ${_quota_values[${offset}]} -gt ${_quota_values[${offset}+1]} ]]; then
    #  _status='\e[5mEXCEEDED!\e[25m'
    #fi
  done
  for offset in {4,8}; do
    if [[ "${_quota_values[${offset}]}" == '-' ]]; then
      _quota_values[${offset}]='none'
    fi
    _quota_values[${offset}]=${_quota_values[${offset}]/day/ day}
    if [[ "${_quota_values[${offset}]}" != 'none' ]]; then
      _status='\e[5mEXCEEDED!\e[25m'
    fi
  done
  #
  # Reformat quota values and units.
  #
  _regex='^([0-9.][0-9.]*)([kMGTP]?)'
  for offset in {1,2,3,5,6,7}; do
    if [[ "${_quota_values[${offset}]}" =~ ${_regex} ]]; then
      local _int="${BASH_REMATCH[1]}"
      local _unit="${BASH_REMATCH[2]}"
      if [[ -z "${_unit:-}" && "${_int}" -gt 5 ]]; then
        _int=$((${_int}/1000))
        _unit='k'
      fi
      printf -v _formatted_number "%'.1f" "${_int}"
      if [[ -z "${_unit:-}" ]]; then
        _quota_values[${offset}]="${_formatted_number}  "
      else
        _quota_values[${offset}]="${_formatted_number} ${_unit}"
      fi
    fi
  done
  printf "${format}" "${_quota_type}" "${_quota_values[@]}" "${_status}"
}


#
##
### Variables.
##
#

#
# Check were we are running this script.
#
#SERVER_NAME="$(hostname)"
MY_DIR=$( cd -P "$( dirname "$0" )" && pwd )
#
# Get the name of the user executing this script.
#
MY_USER="$(id -un)"
#
# Special group used to rsync copies of deployed software 
# and reference data sets to various HP filesystems.
#
DEPLOY_ADMIN_GROUP='umcg-depad'
#
# Get list of groups the user executing this script is a member of.
#  * Remove a (private) group with the same name as MY_USER from the list if present.
#  * Sort the remaining groups in alphabetical order and
#  * If MY_USER is a member of the DEPLOY_ADMIN_GROUP move that one to the top of the list.
#
IFS=' ' read -a MY_GROUPS <<< "$(id -Gn | \
                                 sed "s/${MY_USER} //" | \
                                 tr ' ' '\n' | sort | tr '\n' ' ' | \
                                 sed "s/\(.*\) ${DEPLOY_ADMIN_GROUP}\(.*\)/${DEPLOY_ADMIN_GROUP} \1\2/")"
#
# Choose customised quota binary and associated first column length.
#
OPTIONS="--show-mntpoint --hide-device"
QUOTA="${MY_DIR}/quota-30-left"
first_column_length=30
#
# Formatting constants.
#
SEP_SINGLE='----------------------------------------------------------------------------------------------------------------------------------------------------------'
SEP_DOUBLE='=========================================================================================================================================================='
format="(%1s) %-${first_column_length}s | %10s  %10s  %10s  %15s | %10s  %10s  %10s  %15s | %9b\n"
format_hh="    %-${first_column_length}s | %51s | %51s |\n"

# Longer output version:
#QUOTA="${MY_DIR}/quota-50-left"
#SEP_SINGLE="${SEP_SINGLE}------------------"
#SEP_DOUBLE="${SEP_DOUBLE}=================="
#first_column_length=50

#
##
### Main.
##
#

#
# Get commandline arguments.
#
ALL_GROUPS=0
while getopts ":ha" opt; do
  case $opt in
    h)
      showHelp
      ;;
    a)
      ALL_GROUPS=1
      ;;
    \?)
      reportError ${LINENO} '1' "Invalid option -${OPTARG}. Try \"$(basename $0) -h\" for help."
      ;;
    :)
      reportError ${LINENO} '1' "Option -${OPTARG} requires an argument. Try \"$(basename $0) -h\" for help."
      ;;
  esac
done

#
# Make sure there are no extra arguments we did not expect nor need.
#
shift $(($OPTIND - 1))
if [ ! -z ${1:-} ]; then
  reportError ${LINENO} '1' "Invalid argument \"$1\". Try \"$(basename $0) -h\" for help."
fi

#
# Create list of groups for which to report quota status.
#
declare -a QUOTA_GROUPS=("${MY_GROUPS[@]:-}")
if [ ${ALL_GROUPS} -eq 1 ]; then
  IFS=' ' read -a group_folders_on_this_server <<< "$(ls -1 /groups/ | sort | tr '\n' ' ')"
  IFS=' ' read -a QUOTA_GROUPS <<< $(printf '%s\n' ${MY_GROUPS[@]} ${group_folders_on_this_server[@]} | sort -u | tr '\n' ' ')
fi

#
# Display header.
#
quota_report_header_header=$(printf "${format_hh}" '' 'Total size of files and folders' 'Total number of files and folders')
quota_report_header=$(printf "${format}" 'T' 'Path/Filesystem' 'used' 'quota' 'limit' 'grace' 'used' 'quota' 'limit' 'grace' 'Status')
echo "${SEP_DOUBLE}"
echo "${quota_report_header_header}"
echo "${quota_report_header}"

#
# Display relevant regular user quota.
# 
# Only used
#  * for some systems 
#  * mostly for local file systems 
#  * under control of the "standard" Linux quota tools.
#
set +e
trap - ERR
user_quota="$(${QUOTA} -sQwA -u ${OPTIONS} 2> /dev/null)"
trap 'reportError $LINENO' ERR
set -e
quota_user_report=$(echo "${user_quota}" | tail -n+3 | sort -u)
if [[ ! -z ${quota_user_report:-} ]]; then
  echo "${SEP_SINGLE}"
  IFS_BAK="${IFS}"
  IFS=$'\n'
  for quota_report_line in ${quota_user_report}; do
    parseAndFormatRegularQuota 'U' "${quota_report_line}"
  done
  IFS="${IFS_BAK}"
fi
trap 'reportError $LINENO' ERR
set -e

#
# Display relevant goofy "user" quota.
# 
# Only used
#  * for home dirs from shared Lustre systems 
#  * for a user's "private group" with a group name that is the same as the user name.
#  * under control of the Lustre quota tool: lfs quota ....
#
quota_private_group_report=$(getGroupQuotaForLustreFS "${MY_USER}")
if [[ ! -z ${quota_private_group_report:-} ]]; then
  echo "${SEP_SINGLE}"
  echo "${quota_private_group_report}"
fi

#
# Display relevant group quota.
# 
# Only used
#  * for group dirs from shared GPFS or Lustre systems 
#  * under control of either the Lustre quota tool (lfs quota) or GPFS quota tool (mmlsquota).
#
for THIS_GROUP in "${QUOTA_GROUPS[@]}"
do
  quota_group_report=$(getGroupQuotaForLustreFS "${THIS_GROUP}")
  quota_fileset_report=$(getFileSetQuotaForGPFS "${THIS_GROUP}")
  if [[ ! -z ${quota_group_report:-} || ! -z ${quota_fileset_report} ]]; then
    echo "${SEP_SINGLE}"
  fi
  if [[ ! -z ${quota_group_report:-} ]]; then
    echo "${quota_group_report}"
  fi
  if [[ ! -z ${quota_fileset_report:-} ]]; then
    echo "${quota_fileset_report}"
  fi
done
echo "${SEP_DOUBLE}"

#
# Reset trap and exit.
#
trap - EXIT
exit 0