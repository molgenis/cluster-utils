#!/bin/bash

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
# Make sure dots are used as decimal separator.
#
export LC_ALL='en_US.UTF-8'

#
##
### Main.
##
#

filesystem=''
formatsfff="%-50s  %6.1f  %6.1f  %6.1f\n"
formatssss="%-50s  %6s  %6s  %6s\n"
total_width=74
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")

#
# Check if user specified a file system.
#
if [[ -z ${1:-} ]]; then
  echo
  echo 'FATAL: no file system specified.'
  echo
  echo "Usage: $0 [filesystem as listed in /proc/mounts]"
  echo
  exit
else
  filesystem=$1
fi

#
# Check if file system is known in /proc/mounts.
#
proc_mounts_entry=$(fgrep "${filesystem}" /proc/mounts | awk '{print $2}')
if [[ ${proc_mounts_entry:-} != ${filesystem} ]]; then
  echo
  echo "FATAL: file system ${filesystem} not present in /proc/mounts. Check for trailing slashes."
  echo
  exit
fi

echo "${SEP_DOUBLE}"
printf "${formatssss}" 'Path' 'Used' 'Quota' 'Limit'
echo "${SEP_SINGLE}"
/root/hpc-environment-quota.bash -nap | \
    grep ${filesystem} | \
    awk -v filesystem="${filesystem}" -v format="${formatsfff}" \
        'BEGIN {OFS="\t"} {total_used+=$4; total_quota+=$6; total_limit+=$8} {printf format,$2,$4,$6,$8} END {printf format, filesystem" TOTAL for all groups", total_used, total_quota, total_limit}'

#
# Filesystem            Size  Used Avail Use% Mounted on 
# 172.23.34.211@tcp0:172.23.34.212@tcp0:/umcgst07
#                       324T  293T   16T  96% /mnt/umcgst07
#
echo "${SEP_SINGLE}"
printf "${formatssss}" 'Complete FS' 'Used' 'Use%' 'Size'
echo "${SEP_SINGLE}"
read -r -a diskfree <<< $(df -B 1T ${filesystem} | tail -1)
printf "${formatsfff}" "${diskfree[4]}" "${diskfree[1]}" "$(echo ${diskfree[3]} | sed -e 's/%//')" "${diskfree[0]}"
echo "${SEP_DOUBLE}"