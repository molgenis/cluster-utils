#!/bin/bash
#
# Script to report SLURM cluster usage per user.
# (Basically an sreport wrapper with custom formatting.)
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
# Prevents not being able to run this script, because quota were exceeded on one of our large TMP file systems.
#
export TMPDIR='/tmp/'

#
# Make sure dots are used as decimal separator.
#
LANG='en_US.UTF-8'
LC_NUMERIC="${LANG}"

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
 Lists usage of SLURM Trackable RESources (TRES) per user as percentage of the total cluster capacity.

 Usage:

   $(basename $0) OPTIONS

OPTIONS:

   -s   Start of period to create report for in  format YYYY-MM-DDThh:mm:ss.
   -e   End of period to create report for in  format YYYY-MM-DDThh:mm:ss.
   -p   Period to create report for. Specify period in format YYYY[-MM].

Details:
   
   Values are always reported with a dot as the decimal seperator (LC_NUMERIC="en_US.UTF-8").
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
  local ERROR_MESSAGE="Unspecified error."
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
$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: ERROR: ${errorMessage}
$(hostname) - ${SCRIPT_NAME}:${PROBLEMATIC_LINE}: FATAL: SLURM reporting FAILED with exit code = $exit_status.
"
  #
  # Reset trap and exit.
  #
  trap - EXIT
  exit $exit_status
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
# Formatting constants.
#
base_width=8
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='

#
##
### Main.
##
#

#
# Get commandline arguments.
#
START=0
END=0
PERIOD=0
while getopts "s:e:p:h" opt; do
  case $opt in
    h)
      showHelp
      ;;
    s)
      START=${OPTARG}
      ;;
    e)
      END=${OPTARG}
      ;;
    p)
      PERIOD=${OPTARG}
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
# TODO: Check if dependencies are available.
#
SCONTROL='scontrol'
SREPORT='sreport'

#
# Determine reporting period.
#
# Example: start=2016-10-01T00:00:00 end=2016-11-01T00:00:00
#
regex_YYYY='^([0-9]{4})$'
regex_YYYY_MM='^([0-9]{4})(-([0-9]{2}))$'
if [[ "${START}" == '0' && "${END}" == '0' ]]; then
  if [[ ${PERIOD} =~ ${regex_YYYY} ]]; then
    if [ ${BASH_REMATCH[1]} -ge 2000 ]; then
      YEAR=${BASH_REMATCH[1]}
      START="${YEAR}-01-01T00:00:00"
      END="$((YEAR+1))-01-01T00:00:00"
    else
      reportError ${LINENO} '1' "Reporting period missing or specified in wrong format: found period=${PERIOD}. Try \"$(basename $0) -h\" for help."
    fi
  elif [[ ${PERIOD} =~ ${regex_YYYY_MM} ]]; then
    if [[ 10#${BASH_REMATCH[1]} -ge 2000 && 10#${BASH_REMATCH[3]} -ge 01 && 10#${BASH_REMATCH[3]} -le 12 ]]; then
      YEAR="${BASH_REMATCH[1]}"
      MONTH="${BASH_REMATCH[3]}"
      if [[ 10#${MONTH} -ne 12 ]]; then
        START="${YEAR}-${MONTH}-01T00:00:00"
        end_month=$((${MONTH#0} + 1))
        end_month=$(printf "%02d" "${end_month}")
        END="${YEAR}-${end_month}-01T00:00:00"
      else
        START="${YEAR}-${MONTH}-01T00:00:00"
        END="$((YEAR+1))-01-01T00:00:00"
      fi
    else
      reportError ${LINENO} '1' "Reporting period missing or specified in wrong format: found period=${PERIOD}. Try \"$(basename $0) -h\" for help."
    fi
  elif [[ ${PERIOD} == '0' ]]; then
    showHelp
  else
    reportError ${LINENO} '1' "Reporting period missing or specified in wrong format: found period=${PERIOD}. Try \"$(basename $0) -h\" for help."
  fi
fi
regex='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$'
if [[ ! ${START} =~ ${regex} || ! ${END} =~ ${regex} ]]; then
  reportError ${LINENO} '1' "Reporting period missing or specified in wrong format: found start=${START} and end=${END}. Try \"$(basename $0) -h\" for help."
fi

#
# Get currently available resources from scontrol.
# Note: The older the reporting period the larger the chance that 
#       currently available resources != resources available in reporting period.
#
declare -a scontrol_partitions=($(${SCONTROL} -a -o show partition | tr ' ' '|' | tr "\n" ' ')) || reportError ${LINENO} $? "Failed to get available resources from scontrol."
declare    scontrol_cluster="$(${SCONTROL} -a show config | grep ClusterName | grep -o '[^= ]*$')"

#
# Get resource usage data from sreport.
#
declare -a sreport_cpu=($(${SREPORT} cluster UserUtilizationByAccount -P -n -T CPU -t Percent format=Cluster,Account,Login,Used start=${START} end=${END} | tr "\n" ' ')) \
                    || reportError ${LINENO} $? "Failed to get UserUtilizationByAccount sreport for TRES CPU."
declare -a sreport_mem=($(${SREPORT} cluster UserUtilizationByAccount -P -n -T MEM -t Percent format=Cluster,Account,Login,Used start=${START} end=${END} | tr "\n" ' ')) \
                    || reportError ${LINENO} $? "Failed to get UserUtilizationByAccount sreport for TRES MEM."

#
# Compute length of field values to adjust layout
# and sanity check for consistency in ordering of sreport output lines.
#
longest_cluster_length=7
longest_account_length=7
longest_login_length=5
longest_cpu_usage_length=8
longest_mem_usage_length=8
for offset in "${!sreport_cpu[@]}"; do
  #
  # Split sreport pipe separated values into individual fields and store them in a new array.
  # Format = Cluster|Account|Login|Used|
  #
  declare -a sreport_cpu_line=($(echo "${sreport_cpu[${offset}]}" | tr '|' ' ')) || reportError ${LINENO} $? "Failed to parse UserUtilizationByAccount sreport for TRES CPU."
  declare -a sreport_mem_line=($(echo "${sreport_mem[${offset}]}" | tr '|' ' ')) || reportError ${LINENO} $? "Failed to parse UserUtilizationByAccount sreport for TRES MEM."
  #
  # Sanity check: order of both sreports should be the same.
  #
  if [[ "${sreport_cpu_line[0]}" != "${sreport_mem_line[0]}" || \
        "${sreport_cpu_line[1]}" != "${sreport_mem_line[1]}" || \
        "${sreport_cpu_line[2]}" != "${sreport_mem_line[2]}" ]]; then
    reportError ${LINENO} '1' "Mismatch in line order of sreport CPU vs. sreport MEM reports: ${sreport_cpu_line[0]} vs. ${sreport_mem_line[0]}."
  fi
  if [[ ${#sreport_cpu_line[0]} -gt ${longest_cluster_length} ]]; then
    longest_cluster_length=${#sreport_cpu_line[0]}
  fi
  if [[ ${#sreport_cpu_line[1]} -gt ${longest_account_length} ]]; then
    longest_account_length=${#sreport_cpu_line[1]}
  fi
  if [[ ${#sreport_cpu_line[2]} -gt ${longest_login_length} ]]; then
    longest_login_length=${#sreport_cpu_line[2]}
  fi
  if [[ ${#sreport_cpu_line[3]} -gt ${longest_cpu_usage_length} ]]; then
    longest_cpu_usage_length=${#sreport_cpu_line[3]}
  fi
  if [[ ${#sreport_mem_line[3]} -gt ${longest_mem_usage_length} ]]; then
    longest_mem_usage_length=${#sreport_mem_line[3]}
  fi
done

total_width=$((${base_width}+${longest_cluster_length}+${longest_account_length}+${longest_login_length}+${longest_cpu_usage_length}+${longest_mem_usage_length}))
if [[ ${total_width} -lt 70 ]]; then
  total_width=70
fi
format_usage="%-${longest_cluster_length}s  %${longest_account_length}s  %${longest_login_length}s  %${longest_cpu_usage_length}s  %${longest_mem_usage_length}s\n"
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")

format_metadata_period="Cluster usage report from %-19s to %-19s.\n"
format_metadata_partitions="   %-14s  %12s  %12s\n"

#
# Display metadata and headers.
#
echo "${SEP_DOUBLE}"
printf "${format_metadata_period}" "${START}" "${END}"
echo "${SEP_SINGLE}"

#
# Display available resources.
#
printf "%s\n" "Available resources for ${scontrol_cluster} cluster:"
printf "${format_metadata_partitions}" 'Partition' 'CPUs (cores)' 'Memory (GB)'
echo "${SEP_SINGLE}"
declare total_cluster_cpu=0
declare total_cluster_mem=0
for offset in "${!scontrol_partitions[@]}"; do
  #
  # Split scontrol pipe separated key=value pairs into individual fields and store them in a new hash.
  #
  declare -A scontrol_partition_line
  while read key value; do
    scontrol_partition_line["${key}"]="${value}"
  done < <(echo "${scontrol_partitions[${offset}]}" | tr '|' "\n" | tr '=' ' ')
  total_partition_cpu=$((${scontrol_partition_line['TotalNodes']} * ${scontrol_partition_line['MaxCPUsPerNode']}))
  total_partition_mem=$((${scontrol_partition_line['TotalNodes']} * ${scontrol_partition_line['MaxMemPerNode']}))
  total_partition_mem=$((${total_partition_mem} / 1024))
  printf "${format_metadata_partitions}" "${scontrol_partition_line['PartitionName']}" "${total_partition_cpu}" "${total_partition_mem}"
  total_cluster_cpu=$((${total_cluster_cpu} + ${total_partition_cpu}))
  total_cluster_mem=$((${total_cluster_mem} + ${total_partition_mem}))
done
printf "${format_metadata_partitions}" 'TOTAL' "${total_cluster_cpu}" "${total_cluster_mem}"
echo "${SEP_SINGLE}"

#
# Display consumed resources.
#
printf "${format_usage}" 'Cluster' 'Account' 'Login' 'CPU used' 'MEM used'
echo "${SEP_SINGLE}"
declare total_cpu_usage=0
declare total_mem_usage=0
for offset in ${!sreport_cpu[@]}; do
  #
  # Split sreport pipe separated values into individual fields and store them in a new hash.
  # Format = Cluster|Account|Login|Used|
  #
  IFS='|' read -r -a sreport_cpu_line <<< "$(echo "${sreport_cpu[${offset}]}")"
  IFS='|' read -r -a sreport_mem_line <<< "$(echo "${sreport_mem[${offset}]}")"
  printf "${format_usage}" "${sreport_cpu_line[0]}" "${sreport_cpu_line[1]}" "${sreport_cpu_line[2]}" "${sreport_cpu_line[3]}" "${sreport_mem_line[3]}"
  total_cpu_usage=$(echo "scale=2; ${total_cpu_usage} + ${sreport_cpu_line[3]%\%}" | bc)
  total_mem_usage=$(echo "scale=2; ${total_mem_usage} + ${sreport_mem_line[3]%\%}" | bc)
done
printf "${format_usage}" 'TOTAL' 'ANY' 'ALL' "${total_cpu_usage}%" "${total_mem_usage}%"
echo "${SEP_DOUBLE}"

#
# Reset trap and exit.
#
trap - EXIT
exit 0