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
    echo '${memyselfandi} - SLURM Job Load.'
    echo '        Retrieves the load produced by running jobs and computes job efficiency '
    echo '        by comparing requested resources to actually used resources.'
    echo '        Job stats are retrieved using clustershell (clush) to access nodes '
    echo '        and ps + top to get average + current job stats, respectively.'
    echo 'Usage:'
    echo "       ${memyselfandi} -h              Prints this help message."
    echo "       ${memyselfandi} -u some-user    Lists efficiency for all jobs of the specified user."
    echo "       ${memyselfandi} -j jobID        List efficiency for the specified job."
    echo "       ${memyselfandi} -j jobID-jobID  Lists efficiency for all jobs in the specified range of jobIDs."
    echo "       ${memyselfandi} -j jobID,jobID  Lists efficiency for all jobs in the specified comma seprated list of jobIDs."
    echo "       ${memyselfandi} -j ALL          Lists efficiency for all running jobs."
    echo
}

  #echo "========================================"
  #echo "  Environment Variables:                "
  #echo "    STUBL_SJEFF_PCPU=(ps|top)           "
  #echo "      ps - use %cpu from ps command.    "
  #echo "           This is the average cpu use  "
  #echo "           over the life of the job.    "
  #echo " "
  #echo "     top - use %cpu from top command.   "
  #echo "           This is a 1 second snapshot  "
  #echo "           of cpu usage and reflects    "
  #echo "           current job behavior.        "
  #echo "========================================"

#
##
### Main.
##
#

#
# Get commandline arguments.
#
USER=''
JOBS=''

while getopts "u:j:h" opt; do
  case $opt in
    h)
      _Usage
      exit 0
      ;;
    u)
      USER=${OPTARG}
      ;;
    j)
      JOBS=${OPTARG}
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
# Compile list of jobs.
#
declare -a JOB_IDS=()
if [ ! -z "${USER:-}" ]; then
    #
    # Get list of all jobs for this user.
    #
    JOB_IDS=$(squeue -h --state='R' -o %A -u ${USER} | grep -v CLUSTER)
elif [ "${JOBS:-}" == 'ALL' ]; then
    #
    # Get list of all jobs.
    #
    JOB_IDS=$(squeue -h --state='R' -o %A | grep -v CLUSTER)
elif [[ "${JOBS:-}" =~ ',' ]]; then
    JOB_IDS=$(echo "${JOBS}" | tr ',' ' ')
elif [[ "${JOBS:-}" =~ '^([0-9]*)-([0-9]*)$' ]]; then
    JOB_IDS={${BASH_REMATCH[1]}..${BASH_REMATCH[2]}}
elif [[ "${JOBS:-}" =~ '^([0-9]*)$' ]]; then
    JOB_IDS=(${JOBS})
else
    _Usage
    exit 1
fi

#
# Display header.
#
format='%s  %s  %s  %s\n'
printf "${format}" 'JobID' 'User' 'Efficiency' '%CPU Req.'

for JOB_ID in ${JOB_IDS[@]}; do
    #
    # Default format: "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %R"
    # Specify explicit format without number to make field as long as necessary to capture complete data.
    #
    job_info=$(squeue -h --job=${JOB_ID} --state='R'  --format='%i %P %j %u %t %M %D %R %C'  2>/dev/null | grep -v CLUSTER)
    
    #
    # Check if we found the job.
    #
    if [ "${job_info}" == '' ]; then
        if [ "${JOBS:-}" != 'ALL' ]; then
            echo "FATAL: Invalid job ID (${JOB_ID})"
        else
            continue
        fi
    fi
    
    #
    # Parse job details from squeue.
    #
    user=`echo ${job_info} | awk '{ print $4 }'`
    node_list=`echo ${job_info} | awk '{ print $8 }'`
    cores=`echo ${job_info} | awk '{ print $9 }'`
    node_list=`nodeset -e ${node_list} | tr ' ' ','`
    echo "DEBUG: user ${user} | node_list ${node_list} | cores ${cores}"
    
    #
    # Get load for each requested core.
    #
    cpu_load_snapshot=`clush -w ${node_list} -N "ps -u ${user} -o pcpu= " 2>/dev/null | awk '{ sum+=$1} END {print sum}'`
    cpu_load_average=`clush -w ${node_list} -N "top -b -u${user} -n1 | fgrep ${user}" 2>/dev/null | awk '{ sum+=$9} END {print sum}'`
    echo "DEBUG: cpu_load_snapshot = ${cpu_load_snapshot}"
    echo "DEBUG: cpu_load_average = ${cpu_load_average}"
    if [ "${cpu_load_snapshot}" == '' ]; then
      cpu_load_snapshot=0
    fi
    if [ "${cpu_load_average}" == '' ]; then
      cpu_load_average=0
    fi
    
    #
    # Compute job efficiency.
    #
    efficiency_snapshot=`echo ${cpu_load_snapshot} ${cores} | awk '{ printf("%0.2lf\n", $1/$2); }'`
    efficiency_average=`echo ${cpu_load_average} ${cores} | awk '{ printf("%0.2lf\n", $1/$2); }'`
    
    #
    # compute overall number of cores used.
    #
    effcpu=$(echo ${efficiency_snapshot} ${cores} | awk '{ printf("%0.2lf\n", $1 * $2 / 100); }')
    
    #
    # Display job stats.
    #
    if [ $(echo "${efficiency_average} < 80" | bc -l) == 0 ]; then
        #
        # Job load inefficiently low.
        #
        echo "${JOB_ID} ${user} ${efficiency_average} $effcpu ${cores}" | awk '{ printf("%c[0;31m%-8s  %-8s   = %-6s%%  (%s of %s)\n%c[0m", 27, $1, $2, $3, $4, $5, 27); }'
    else
        #echo "${JOB_ID} ${user} ${efficiency_average} $effcpu ${cores}" | awk '{ printf("%-8s  %-8s   = %-6s%%  (%s of %s)\n", $1, $2, $3, $4, $5); }'
        printf "%-8s  %-8s   = %-6s%%  (%s of %s)\n" ${JOB_ID} ${user} ${efficiency_average} $effcpu ${cores}
    fi
done

