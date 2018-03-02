#!/bin/bash

#
##
### Environment and bash sanity.
##
#
set -u
set -e
umask 0027
memyselfandi="$(basename $0)"
if [[ "${BASH_VERSINFO}" -lt 4 || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "Sorry, you need at least bash 4.x to use ${memyselfandi}." >&2
  exit 1
fi

SCRIPT_NAME="$(basename ${0})"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"

set +e
SACCT="$(which sacct 2>/dev/null)"
SQUEUE="$(which squeue 2>/dev/null)"
set -e
if [[ ! -x "${SACCT:-}" ]]; then
	echo "FATAL: Cannot find sacct Slurm command!"
	exit 1
fi
if [[ ! -x "${SQUEUE:-}" ]]; then
	echo "FATAL: Cannot find squeue Slurm command!"
	exit 1
fi

declare -A mem_unit_scaling_factors=(
	['B']='1'
	['K']='1024'
	['M']='1048576'
	['G']='1073741824'
)

#
##
### Functions.
##
#

function _usage() {
	echo
	echo 'Usage:'
	echo "       ${memyselfandi} will report job efficiency for both running and finished Slurm jobs."
	echo '       Job efficiency is determined as:'
	echo '          CPU efficiency (%) = average CPU core usage / requested cores'
	echo '          Mem efficiency (%) = peak memory usage / requested memory'
	echo '          Walltime efficiency (%) = run time / requested walltime'
	echo
	echo 'Options:'
	echo '       -j [JobID]       Compute job efficiency for the specified Slurm Job ID.'
	echo '                        You may specify multiple comma separated Job IDs.'
	echo '       -o [DIR]         Directory containing Slurm job *.out files from a UMCG cluster.'
	echo '                        The last 5 lines of these *.out files contain details on requested and consumed resources,'
	echo '                        which were produced by an sacct command in a custom Slurm job epilog script.'
	echo '       -l [FILE]        File containing list of Slurm Job IDs. Format must be one Job ID per line.'
	echo '                        Optionally the Job IDs may be prefixed with Job Names and a colon as separator like in a '
	echo '                        "molgenis.submitted.log" file. E.g.:'
	echo '                            JobName1:JobID1'
	echo '                            JobName2:JobID2'
	echo '                            JobNameN:JobIDN'
	echo '       -p "[PATTERN]"   Regex pattern to recognise and group similar type of jobs (optional).'
	echo '                        When specified the min, max and average will be computed for the job group/type.'
	echo '                        Note: PATTERN must contain exactly one pair of round brackets "()" to define the capture group,'
	echo '                        that will be used as the value for the job group/type, which must be part of the job name.'
	echo '                        E.g. for jobs from a Molgenis Compute pipeline with default job headers for Slurm,'
	echo '                        the pattern argument must be:'
	echo "                            -p '.*_(s[0-9]{2}_[^_]*)'"
	echo
}

#
# Custom signal trapping functions (one for each signal) required to format log lines depending on signal.
#
function trapSig() {
	local _trap_function="${1}"
	local _line="${2}"
	local _function="${3}"
	local _status="${4}"
	shift 4
	for _sig; do
		trap "${_trap_function} ${_sig} ${_line} ${_function} ${_status}" "${_sig}"
	done
}

function trapHandler() {
	local _signal="${1}"
	local _problematic_line="${2:-'?'}"
	local _problematic_function="${3:-'main'}"
	local _status="${4:-$?}"
	local _log_message="WARN: Trapped ${_signal} signal."
	local _log_timestamp=$(date "+%Y-%m-%dT%H:%M:%S") # Creates ISO 8601 compatible timestamp.
	local _log_line_prefix=$(printf "%-s %-s %-5s @ L%-s(%-s)>" "${SCRIPT_NAME}" "${_log_timestamp}" "${_problematic_line}" "${_problematic_function}")
	local _log_line="${_log_line_prefix} ${_log_message}"
	if [[ ${_status} -ne 0 ]]; then
		printf '%s\n' "${_log_line}" 1>&2
	else
		printf '%s\n' "${_log_line}"
	fi
	#
	# Reset trap and exit.
	#
	echo -e "\e[0m\n" # reset all terminal formatting attributes.
	trap - EXIT
	exit ${_status}
}

function _getJobEfficiency() {
	
	local      _job_group_pattern="${1}"
	shift
	declare -a _job_ids=("${@}")
	local      _job_id
	local      _job_name
	#
	# Variables suffixes:
	#   _r = requested
	#   _u = used
	#   _e = efficiency in %
	#
	local _sacct_format_r='JobId,JobName,Timelimit,AllocCPUs,ReqMem'
	local _sacct_format_u='JobId,Elapsed,AveCPU,MaxRSS'
	
	for _job_id in "${_job_ids[@]}"
	do
		#echo "DEBUG: Fetching job stats using sacct from Slurm DB for: ${_job_id}" >&2
		IFS='|' read -ra _job_info_r <<< $("${SACCT}" -o "${_sacct_format_r}" -p -j "${_job_id}"       | grep "${_job_id}|"      | tail -n 1)
		IFS='|' read -ra _job_info_u <<< $("${SACCT}" -o "${_sacct_format_u}" -p -j "${_job_id}.batch" | grep "${_job_id}.batch" | tail -n 1)
		
		if [[ ${#_job_info_r[@]:0} -ge 1 && ${#_job_info_u[@]:0} -ge 1 ]]
		then
			#echo "DEBUG:     ${_job_info_requested[@]} ${_job_info_used[@]}"
			if [[ -z "${_job_info_r[1]:-}" ]]
			then
				_job_name="${_job_id}"
			else
				_job_name="${_job_info_r[1]}"
				if [[ "${_job_group_pattern}" != 'none' ]]
				then
					if [[ "${_job_name}" =~ ${_job_group_pattern} ]]
					then
						#echo "DEBUG: Job name for job ${_job_id} '${_job_name}' matched specified job group pattern ${_job_group_pattern}." >&2
						local _job_type="${BASH_REMATCH[1]}"
					else
						echo "FATAL: Job name for job ${_job_id} '${_job_name}' does not match specified job group pattern ${_job_group_pattern}." >&2
						exit 1
					fi
				fi
				if [[ "${#_job_name}" -gt 60 ]]
				then
					_job_name="${_job_name:0:57}..."
				fi
			fi
			#
			# Compute efficiency
			#
			local _walltime_r="${_job_info_r[2]}"
			local _walltime_u="${_job_info_u[1]}"
			local _walltime_e=''
			local _cpu_r="${_job_info_r[3]}"
			local _cpu_u="${_job_info_u[2]}"
			local _cpu_e=''
			local _mem_r="${_job_info_r[4]}"
			local _mem_u="${_job_info_u[3]}"
			local _mem_e=''
			local _walltime_seconds_r=$(_time2Seconds "${_walltime_r}")
			local _walltime_seconds_u=$(_time2Seconds "${_walltime_u}")
			local _cpu_seconds_u=$(_time2Seconds "${_cpu_u}")
			local _mem_in_bytes_r=$(_mem2Bytes "${_mem_r}")
			local _mem_in_bytes_u=$(_mem2Bytes "${_mem_u}")
			if [[ "${_walltime_seconds_r}" -gt 0 ]]
			then
				_walltime_e=$(printf "%.2f" "$(echo "scale=5; ((${_walltime_seconds_u} / ${_walltime_seconds_r}) * 100)" | bc)")
				if [[ "${_walltime_seconds_u}" -gt 0 ]]
				then
					_cpu_e=$(printf "%.2f" "$(echo "scale=5; ((${_cpu_seconds_u} / ${_walltime_seconds_u}) * 100)" | bc)")
				else
					_cpu_e='0.00'
				fi
			else
				_walltime_e='0.00'
			fi
			if [[ "${_mem_in_bytes_r}" -gt 0 ]]
			then
				_mem_e=$(printf "%.2f" "$(echo "scale=5; ((${_mem_in_bytes_u} / ${_mem_in_bytes_r}) * 100)" | bc)")
			else
				_mem_e='0.00'
			fi
			#
			# Add color/formatting.
			#
			local _formatted_walltime_e="$(_formatEfficiency "${_walltime_e}" '75' '90')"
			local _formatted_cpu_e="$(_formatEfficiency "${_cpu_e}" '90' '100')"
			local _formatted_mem_e="$(_formatEfficiency "${_mem_e}" '75' '90')"
		else
			_job_name="ERROR: Failed to parse sacct output for job ${_job_id}"
			local _walltime_r='?'
			local _cpu_r='?'
			local _mem_r='?'
			local _formatted_walltime_e='?'
			local _formatted_cpu_e='?'
			local _formatted_mem_e='?'
		fi
		
		printf "${body_format_jobs}" "${_job_name}" "${_walltime_r}" "${_formatted_walltime_e}" "${_cpu_r}" "${_formatted_cpu_e}" "${_mem_r}" "${_formatted_mem_e}"
		
		#
		# Create/update job_efficiency_summarized_by_job_type
		#
		# String values are 'fake' arrays of colon separated values:
		#    "number_of_jobs:min_walltime_e:average_walltime_e:max_walltime_e:min_cpu_e:average_cpu_e:max_cpu_e:min_mem_e:average_mem_e:max_mem_e"
		# Note: min, max and average values are rounded to integers, so all values in the fake array are ints for easy comparison in bash.
		#
		if [[ -n "${_job_type:-}" && "${_formatted_walltime_e}" != '?' ]]
		then
			local _rounded_walltime_e="$(printf '%.0f' ${_walltime_e})"
			local _rounded_cpu_e="$(printf '%.0f' ${_cpu_e})"
			local _rounded_mem_e="$(printf '%.0f' ${_mem_e})"
			if [[ -z "${job_efficiency_summarized_by_job_type[${_job_type}]+isset}" ]]
			then
				#
				# Add new job type.
				#
				job_efficiency_summarized_by_job_type["${_job_type}"]="1:${_rounded_walltime_e}:${_rounded_walltime_e}:${_rounded_walltime_e}:${_rounded_cpu_e}:${_rounded_cpu_e}:${_rounded_cpu_e}:${_rounded_mem_e}:${_rounded_mem_e}:${_rounded_mem_e}"
			else
				#
				# Recompute number of jobs, min efficiency, max efficiency & average efficiency
				# and update info for this job type.
				#
				IFS=':' read -a _job_type_stats <<< "${job_efficiency_summarized_by_job_type["${_job_type}"]}"
				local _number_of_jobs="${_job_type_stats[0]}"
				local _min_walltime_e="${_job_type_stats[1]}"
				local _avg_walltime_e="${_job_type_stats[2]}"
				local _max_walltime_e="${_job_type_stats[3]}"
				local _min_cpu_e="${_job_type_stats[4]}"
				local _avg_cpu_e="${_job_type_stats[5]}"
				local _max_cpu_e="${_job_type_stats[6]}"
				local _min_mem_e="${_job_type_stats[7]}"
				local _avg_mem_e="${_job_type_stats[8]}"
				local _max_mem_e="${_job_type_stats[9]}"
				
				if [[ "${_rounded_walltime_e}" -lt "${_min_walltime_e}" ]]
				then
					_min_walltime_e="${_rounded_walltime_e}"
				elif [[ "${_rounded_walltime_e}" -gt "${_max_walltime_e}" ]]
				then
					_max_walltime_e="${_rounded_walltime_e}"
				fi
				_avg_walltime_e="$(_updateAverage "${_avg_walltime_e}" "${_walltime_e}" "${_number_of_jobs}")"
				if [[ "${_rounded_cpu_e}" -lt "${_min_cpu_e}" ]]
				then
					_min_cpu_e="${_rounded_cpu_e}"
				elif [[ "${_rounded_cpu_e}" -gt "${_max_cpu_e}" ]]
				then
					_max_cpu_e="${_rounded_cpu_e}"
				fi
				_avg_cpu_e="$(_updateAverage "${_avg_cpu_e}" "${_cpu_e}" "${_number_of_jobs}")"
				if [[ "${_rounded_mem_e}" -lt "${_min_mem_e}" ]]
				then
					_min_mem_e="${_rounded_mem_e}"
				elif [[ "${_rounded_mem_e}" -gt "${_max_mem_e}" ]]
				then
					_max_mem_e="${_rounded_mem_e}"
				fi
				_avg_mem_e="$(_updateAverage "${_avg_mem_e}" "${_mem_e}" "${_number_of_jobs}")"
				_number_of_jobs="$((${_number_of_jobs} + 1))"
				job_efficiency_summarized_by_job_type["${_job_type}"]="${_number_of_jobs}:${_min_walltime_e}:${_avg_walltime_e}:${_max_walltime_e}:${_min_cpu_e}:${_avg_cpu_e}:${_max_cpu_e}:${_min_mem_e}:${_avg_mem_e}:${_max_mem_e}"
			fi
			#echo "DEBUG: job_efficiency_summarized_by_job_type for ${_job_type}: ${job_efficiency_summarized_by_job_type[${_job_type}]}" >&2
		fi
	done
}

function _time2Seconds() {
	local _slurm_time="${1}"
	local _regex_incl_days='^([0-9]*)-([0-9]{2}):([0-9]{2}):([0-9]{2})$'
	local _regex_excl_days='^([0-9]{2}):([0-9]{2}):([0-9]{2})$'
	
	if [[ "${_slurm_time}" =~ ${_regex_incl_days} ]]
	then
		local    _days="${BASH_REMATCH[1]}"
		local   _hours="${BASH_REMATCH[2]}"
		local _minutes="${BASH_REMATCH[3]}"
		local _seconds="${BASH_REMATCH[4]}"
	elif [[ "${_slurm_time}" =~ ${_regex_excl_days} ]]
	then
		local    _days='0'
		local   _hours="${BASH_REMATCH[1]}"
		local _minutes="${BASH_REMATCH[2]}"
		local _seconds="${BASH_REMATCH[3]}"
	else
		echo "FATAL: time as reported by Slurm command sacct in unsupported format; Got: ${_slurm_time:-}." >&2
		exit 1
	fi
	
	local _time_in_seconds="$((${_days}*24*60*60 + ${_hours#0}*60*60 + ${_minutes#0}*60 + ${_seconds#0}))"
	echo -n "${_time_in_seconds}"
}

function _mem2Bytes() {
	local _slurm_mem="${1}"
	local _regex='^([0-9][0-9.]*)([BKMGT])[cn]?$'
	
	if [[ "${_slurm_mem}" =~ ${_regex} ]]
	then
		local    _mem="${BASH_REMATCH[1]}"
		local   _unit="${BASH_REMATCH[2]}"
	else
		echo "FATAL: memory as reported by Slurm command sacct in unsupported format; Got: ${_slurm_mem:-}." >&2
		exit 1
	fi
	local _mem_in_bytes=$(printf "%.0f" "$(echo "scale=5; (${_mem}*${mem_unit_scaling_factors[${_unit}]})" | bc)")
	echo -n "${_mem_in_bytes}"
}

function _updateAverage() {
	local _average_old="${1}"
	local _new_value="$(printf '%.0f' "${2}")"
	local _number_of_values_old="${3}"
	local _average_new="${_average_old}" # default in case we cannot compute a new average.
	
	_average_new="$(( ((${_average_old}*${_number_of_values_old}) + ${_new_value}) / (${_number_of_values_old} + 1) ))"
	echo -n "$(printf '%.0f' ${_average_new})"
}

function _formatEfficiency() {
	local _unformattedEfficiency="${1}"
	local _lower_threshold="${2}"
	local _upper_threshold="${3}"
	local _unformattedEfficiencyAsInt="$(printf '%.0f' ${_unformattedEfficiency})"
	local _padding="$(head -c $((7 - ${#_unformattedEfficiency})) /dev/zero | tr '\0' ' ')"
	local _formattedEfficiency="${_unformattedEfficiency}" # default.
	#
	# Colors:
	#
	# \e[91m = bright red
	# \e[92m = bright green
	# \e[93m = bright yellow
	# \e[97m = white
	#
	if [[ "${_unformattedEfficiencyAsInt}" -gt "${_upper_threshold}" ]]
	then
		# (Too) high: need a small buffer for variation in job reqs and impact of load from other jobs.
		_formattedEfficiency="${_padding:-}\e[91m${_unformattedEfficiency}\e[97m"
	elif [[ "${_unformattedEfficiencyAsInt}" -lt "${_lower_threshold}" ]]
	then
		# (Too) low: resources are waisted.
		_formattedEfficiency="${_padding:-}\e[93m${_unformattedEfficiency}\e[97m"
	else
		# Just right.
		_formattedEfficiency="${_padding:-}\e[92m${_unformattedEfficiency}\e[97m"
	fi
	echo -n "${_formattedEfficiency}"
}

#
##
### Main.
##
#

#
# Trap all exit signals: HUP(1), INT(2), QUIT(3), TERM(15), ERR.
#
trapSig 'trapHandler' '${LINENO}' '${FUNCNAME:-main}' '$?' HUP INT QUIT TERM EXIT ERR

total_width=127
header1_format="%-60s | %-20s | %-20s | %-18s\n"
header2_format="%-60s | %11s  %7s |   %9s  %7s | %9b  %7b\n"
header3_format="%-60s |    %3s    %3s    %3s |    %3s    %3s    %3s | %3s    %3s    %3s\n"
body_format_jobs="%-60s | %11b  %7b |   %9b  %7b | %9b  %7b\n"
body_format_job_types="%-60s |    %3b <= %3b <= %3b |    %3b <= %3b <= %3b | %3b <= %3b <= %3b\n"
SEP_SINGLE_CHAR='-'
SEP_DOUBLE_CHAR='='
SEP_SINGLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_SINGLE_CHAR}")
SEP_DOUBLE=$(head -c ${total_width} /dev/zero | tr '\0' "${SEP_DOUBLE_CHAR}")

#
# Get commandline arguments.

while getopts "j:o:l:p:h" opt
do
	case "${opt}" in
		h)
			_usage
			trap - EXIT
			exit 0
			;;
		j)
			job_ids_string="${OPTARG}"
			;;
		o)
			job_out_dir="${OPTARG}"
			;;
		l)
			job_list_file="${OPTARG}"
			;;
		p)
			#echo 'FATAL: not yet implemented.'
			#exit 1
			job_group_pattern="${OPTARG}"
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
# Configure terminal colors.
#
echo -e "\e[40m"  # black background.
echo -e "\e[97m"  # white text/foreground.

#
# Check & parse args.
#
if [[ -z "${job_ids_string:-}" && -z "${job_out_dir:-}" && -z "${job_list_file:-}" ]]
then
	_usage
	echo 'FATAL: must specify at least either one Job ID with -j or a directory with Job *.out files with -o.'
	exit 1
else
	if [[ -n "${job_ids_string:-}" ]]
	then
		IFS=',' read -a job_ids <<< "$(echo "${job_ids_string}" \
				| tr ',' '\n' \
				| sort -n \
				| tr '\n' ',' \
				| sed 's/,$//')"
	elif [[ -n "${job_out_dir:-}" ]]
	then
		if [[ -d "${job_out_dir}" && -r "${job_out_dir}" && -x "${job_out_dir}" ]]
		then
			IFS=',' read -a job_ids <<< "$(tail -n 5 "${job_out_dir}"/*.out \
				| grep -o 'Resources consumed by job [0-9]*'\
				| sed 's/Resources consumed by job //' \
				| sort -n | tr '\n' ','| sed 's/,$//')"
		else
			echo "FATAL: directory ${job_out_dir} does not exist or is not accessible. Check path and permissions".
			exit 1
		fi
		if [[ "${#job_ids[@]:-0}" -lt '1' ]]
		then
			echo "FATAL: did not find any Job IDs in the footers of the ${job_out_dir}/*.out files."
			exit 1
		fi
	elif [[ -n "${job_list_file:-}" ]]
	then
	if [[ -f "${job_list_file}" && -r "${job_list_file}" ]]
		then
		IFS=',' read -a job_ids <<< "$(cat "${job_list_file}" \
				| grep -o '[0-9][0-9]*$'\
				| sort -n | tr '\n' ','| sed 's/,$//')"
		else
			echo "FATAL: file ${job_list_file} does not exist or is not accessible. Check path and permissions".
			exit 1
		fi
		if [[ "${#job_ids[@]:-0}" -lt '1' ]]
		then
			echo "FATAL: did not find any Job IDs in file ${job_list_file}."
			exit 1
		fi
	fi
fi
if [[ -n "${job_group_pattern:-}" ]]
then
	brackets_open="${job_group_pattern//[^(]}"
	brackets_close="${job_group_pattern//[^)]}"
	if [[ ${#brackets_open} -ne 1 || ${#brackets_close} -ne 1 ]]
	then
		echo "FATAL: job group pattern must contain exactly one capture group between round brackets '()', but you specified ${job_group_pattern}."
		exit 1
	fi
fi

#
# Print header.
#
echo "${SEP_DOUBLE}"
printf "${header1_format}" 'JobName' 'Time' 'Cores (used=average)' 'Memory (used=peak)'
printf "${header2_format}" ' ' 'Requested' 'Used(%)' 'Requested' 'Used(%)' 'Requested' 'Used(%)'
echo "${SEP_SINGLE}"

#
# Get and print Slurm job efficiency.
#
declare -A job_efficiency_summarized_by_job_type
_getJobEfficiency "${job_group_pattern:-none}" "${job_ids[@]}"

#
# Print job efficiency summarized by job type (optional).
#
if [[ -n "${job_group_pattern:-}" ]]
then
	echo "${SEP_DOUBLE}"
	printf "${header1_format}" 'JobType [NumberOfJobs]' 'Time Used(%)' 'Cores Used(%)' 'Memory Used(%)'
	printf "${header3_format}" ' ' 'Min' 'Avg' 'Max' 'Min' 'Avg' 'Max' 'Min' 'Avg' 'Max'
	echo "${SEP_SINGLE}"
	for job_type in "${!job_efficiency_summarized_by_job_type[@]}"
	do
		IFS=':' read -a job_type_stats <<< "${job_efficiency_summarized_by_job_type["${job_type}"]}"
		printf "${body_format_job_types}" "${job_type} [${job_type_stats[0]}]" \
			"${job_type_stats[1]}" "${job_type_stats[2]}" "${job_type_stats[3]}" \
			"${job_type_stats[4]}" "${job_type_stats[5]}" "${job_type_stats[6]}" \
			"${job_type_stats[7]}" "${job_type_stats[8]}" "${job_type_stats[9]}"
	done | sort -k1V
fi

#
# Print footer.
#
echo "${SEP_DOUBLE}"

#
# Exit cleanly on success.
#
echo -e "\e[0m\n" # reset all terminal formatting attributes.
trap - EXIT
exit 0
