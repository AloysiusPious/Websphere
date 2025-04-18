#!/bin/sh
#####################################################################################################
#
# This script is used to collect performance mustgather data for
# WebSphere or Liberty on Linux
#
# ./linperf.sh [PID(s)_of_the_problematic_JVM(s)_separated_by_spaces]
#
# Optional options
# -c CPU threshold or --cpu-threshold=<value>
# -j javacore interval
# -s script span
# -t top dash interval
# -v vmstat interval
# -q quiet end message
# -z allow stats
# --disable-kill disables issuing a kill -3 command.
# --output-dir=/path/to/linperf_RESULTS*.tar.gz
# --monitor-only monitors a triggering event only without data created.
# --cpu-threshold=<value> triggers a data collection when the specified CPU threshold is reached.
# --check-cpu-interval=<value> checks a process's CPU usage at interval in seconds. Default is 30.
# --disable-irix-mode caps CPU usage at 100% in this script.
#
# Example with some options against a Java PID:
# A javacore/thread dump every 5 seconds, running for 30 seconds:
# ./linperf.sh -j 5 -s 30 PID_of_the_problamtic_JVM
#
# Triggers a data collection when PID exceeds 70% CPU usage:
# ./linperf.sh PID_of_the_problamtic_JVM --cpu-threshold=70
#
# Example without PID for collecting stats, using -z flag:
# ./linperf.sh -z
#
#####################################################################################################
# WSADMIN SECTION START: If there are any code changes below,
# be sure to update the linperf_shell_script_content in the wsadmin perf script and test the changes.
#####################################################################################################
#
# Variables
#
#####################################################################################################
SCRIPT_SPAN=240         # How long the whole script should take . Default=240
JAVACORE_INTERVAL=30    # How often javacores should be taken including the final one. Default=30
TOP_INTERVAL=60         # How often top data should be taken. Default=60
TOP_DASH_H_INTERVAL=5   # How often top dash H data should be taken. Default=5
VMSTAT_INTERVAL=5       # How often vmstat data should be taken. Default=5
CHECK_CPU_INTERVAL=30   # How often the script should check a process's CPU usage. Default=30.
                        # It only works with -c <value> or --cpu-threshold=<value>.
MONITOR_ONLY=0          # Monitoring trigering events only with no data created.
                        # It only works with -c <value> or --cpu-threshold=<value>. Default=0
KEEP_QUIET=0            # To disable the end print message, change to 1. Default=0
ALLOW_STATS=0           # To collect OS data without provided PIDs, change to 1. Default=0
#####################################################################################################
# * All the 'INTERVAL' values should divide into the 'SCRIPT_SPAN' by a whole
#   integer to obtain expected results.
# * Setting any 'INTERVAL' too low (especially JAVACORE) can result in data
#   that may not be useful towards resolving the issue.  This becomes a problem
#   when the process of collecting data obscures the real issue.
###############################################################################
SCRIPT_VERSION=2024.09.17
START_DAY="$(date +%Y%m%d)"
START_TIME="$(date +%H%M%S)"

provided_pids=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j ) JAVACORE_INTERVAL="$2"; shift 2;;  
    -q ) KEEP_QUIET=1; shift 1;;
    -s ) SCRIPT_SPAN="$2"; shift 2;;
    -t ) TOP_INTERVAL="$2"; shift 2;;
    -v ) VMSTAT_INTERVAL="$2"; shift 2;;
    -z ) ALLOW_STATS=1; shift 1;;
    # Triggering event
    -c ) CPU_THRESHOLD="$2"; shift 2;;

    # Disable issuing a kill -3.
    --disable-kill ) disable_kill=1; shift 1;;
    # Disable writing to screen.out file. Only used by wsadmin script.
    --disable-screen-output ) DISABLE_SCREEN_OUTPUT=1; shift 1;;

    # Rename linperf_RESULTS. Used by a wsadmin script.
    --dir-name=* ) DIR_NAME="${1#*=}"; shift 1;;
    # Redirect linperf_RESULTS data to a specified directory.
    --output-dir=* ) OUTPUT_DIR="${1#*=}"; shift 1;;

    # Monitoring a triggering event only without data created.
    --monitor-only ) MONITOR_ONLY=1; shift 1;;

    # Triggering event.
    --cpu-threshold=* ) CPU_THRESHOLD="${1#*=}"; shift 1;;
    --check-cpu-interval=* ) CHECK_CPU_INTERVAL="${1#*=}"; shift 1;;

    # Disable irix mode to cap at 100% CPU in this script.
    --disable-irix-mode ) irix_mode=0; shift 1;;

    # Used by a wsadmin scirpt.
    --hide-stamp ) HIDE_STAMP=1; shift 1;;

    [0-9]* ) provided_pids="$provided_pids $1"; shift 1;;

    * ) echo "Unknown option: $1"; exit 1;;
  esac
done
#############################################
# If PIDs are not provided, the script exits.
#############################################
if [ -z "$provided_pids" ] && [ $ALLOW_STATS -eq 0 ]; then
  echo "Unable to find required PID argument. Please rerun the script as follows:"
  echo "./linperf.sh [PID(s)_of_the_problematic_JVM(s)_separated_by_spaces]"
  exit 1
fi

######################
# Verify option inputs
######################
if [ $MONITOR_ONLY -eq 1 ]; then
  if [ -z "${CPU_THRESHOLD}" ]; then
    echo "To run with --monitor-only, include --cpu-threshold=<value>. Exiting script."
    exit 1
  fi
fi

if [ -n "$irix_mode" ] && [ -n "$CPU_THRESHOLD" ]; then
  if [ $irix_mode -eq 0 ] && [ $CPU_THRESHOLD -gt 100 ]; then
    echo "With --disable-irix-mode, --cpu-threshold=<value> cannot exceed 100. Exiting script"
    exit 1
  fi
fi

################################################
# Verify running PIDs
# Remove duplicate PID and non-exist PID.
# The script exits if running PIDs do not exist.
################################################
pids=""
if [ -n "$provided_pids" ]; then
  for pid in `echo $provided_pids | xargs -n1 | sort -u | xargs`
  do
    if test -d /proc/"$pid"/; then
      pids="$pid $pids"
    else
      echo "PID $pid does not exist. Exiting script."
      exit 1
    fi
  done
fi

####################################################
# Exit the script if running as a non-root user and
# the user does not match all PID owners
####################################################
current_id="$(id -u)"
current_group="$(id -g)"
if [ "${current_id}" -ne "0" ] && [ "${current_group}" -ne "0" ]; then
  for pid in $pids; do
  if [ "${current_id}" -ne "$(stat -c "%u" /proc/${pid})" ] && [ "${current_group}" -ne "$(stat -c "%g" /proc/${pid})" ]; then
    echo "PID ${pid} is owned by user '$(stat -c "%U" /proc/${pid})' and group '$(stat -c "%G" /proc/${pid})' but you are $(id). Either switch users or run as root/sudo."
    exit 1
  fi
  done
fi

###################
# Assign OUTPUT_DIR
###################
if [ -n "$OUTPUT_DIR" ] && [ -n "$DIR_NAME" ]; then
  OUTPUT_DIR="$OUTPUT_DIR/$DIR_NAME"
elif [ -n "$OUTPUT_DIR" ] && [ -z "$DIR_NAME" ]; then
  DIR_NAME="linperf_RESULTS.$START_DAY.$START_TIME"
  OUTPUT_DIR="$OUTPUT_DIR/$DIR_NAME"
elif [ -z "$OUTPUT_DIR" ] && [ -n "$DIR_NAME" ]; then
  OUTPUT_DIR="$DIR_NAME"
else
  DIR_NAME="linperf_RESULTS.$START_DAY.$START_TIME"
  OUTPUT_DIR="$DIR_NAME"
fi
case "$OUTPUT_DIR" in
  *" "* ) echo "\"$OUTPUT_DIR\" contains a space. Exiting script."
  exit 1
esac

#####################################
# Create a temporary output directory
#####################################
if [ $MONITOR_ONLY -ne 1 ]; then
  mkdir -p $OUTPUT_DIR
  if [ $? -ne 0 ]; then
    echo "Failed to create $OUTPUT_DIR."
    exit 1
  fi
  # Go into the created output directory and
  # get the full path to let the user know the current directory.
  cd $OUTPUT_DIR
  if [ $? -ne 0 ]; then
    echo "Failed to go into $OUTPUT_DIR."
    exit 1
  fi
  readonly OUTPUT_DIR="$(pwd)"
fi

#################################
# Write a message to screen.out
# Empty $1 does not write out
#################################
log()
{
  # $1 - message
  if [ -z "${DISABLE_SCREEN_OUTPUT}" ] && [ -n "$1" ] && [ $MONITOR_ONLY -ne 1 ] && [ -z "${HIDE_STAMP}" ]; then
    echo $(date '+%Y-%m-%d %H:%M:%S')  "\t$1" | tee -a screen.out
  elif [ -n "${HIDE_STAMP}" ] && [ -n "$1" ]; then
    echo "$1"
  elif [ -n "$1" ]; then
    echo $(date '+%Y-%m-%d %H:%M:%S')  "\t$1"
  fi
}
#################################################################
# Remove PID either calling from cpu_trigger() or cpu_threshold()
# and update $pids.
#################################################################
no_longer_running_pids=""
remove_pid()
{
  pid_to_remove=$1
  pids=$2
  # Remove PID from PIDs, replaces multiple spaces with single, remove trailing space
  new_pids=$(echo "$pids" | sed "s/\b$pid_to_remove\b//g" | sed 's/  / /g' | sed 's/ *$//')
  echo "$new_pids"
}

#############################
# Calculate CPU usage for PID
#############################
# Get the total CPU time (user time + system time) for given PID.
get_total_time_for_pid(){
  stat_line=$(cat /proc/$1/stat)
  utime=$(echo $stat_line | awk '{print $14}')
  stime=$(echo $stat_line | awk '{print $15}')
  echo $((utime + stime))
}

get_initial_cpu_times(){
  for pid in $pids; do
    get_total_time_for_pid $pid
  done
}

###########################################
# Loop until CPU usage threshold is reached
###########################################
cpu_trigger()
{
  if [ -n "${CPU_THRESHOLD}" ] && [ -n "${pids}" ]; then
    # Assign irix_mode if it is null and toprc file exists.
    # Otherwise, set irix_mode to 1 if no toprc file exists.
    if [ -z "$irix_mode" ] && [ -f "$HOME/.config/procps/toprc" ]; then
      irix_mode=$(grep -oP 'Mode_irixps=\K[0-9]' "$HOME/.config/procps/toprc")
    elif [ -z "$irix_mode" ] && [ -f "$HOME/.toprc" ]; then
      irix_mode=$(grep -oP 'Mode_irixps=\K[0-9]' "$HOME/.toprc")
    elif [ -z "$irix_mode" ]; then
      irix_mode=1
    fi

    num_of_cpus=$(nproc)
    log "CHECK_CPU_INTERVAL = $CHECK_CPU_INTERVAL"
    log "Irix mode = $irix_mode"
    log "Number of CPUs: $num_of_cpus"
    log "Monitoring PIDs: $pids"
    log "Waiting for a process to exceed $CPU_THRESHOLD% CPU usage."

    num_of_cpus=$(nproc)
    while :
    do
      # An array of total times spent by provided PIDs at the first point in time.
      initial_times=$(get_initial_cpu_times)

      sleep $CHECK_CPU_INTERVAL
      i=1
      for pid in $pids; do

        if [ -e /proc/$pid ]; then
          # Get the value of the initial time spent by the process from the array.
          cpu_time_before=$(echo "$initial_times" | sed -n "${i}p")
          # The second point: The process has been up.
          cpu_time_after=$(get_total_time_for_pid $pid)

          # Calculate the difference in total time between two points (time_after - time_before)
          # Calculate CPU usage percentage over the CHECK_CPU_INTERVAL(sleep_time)
          # If irix mode is off, divide the CPU usage by number of CPUs.
          pid_cpu_usage=$(awk -v time_before=$cpu_time_before -v time_after=$cpu_time_after -v sleep_time=$CHECK_CPU_INTERVAL 'BEGIN {printf "%0.f", ((time_after - time_before ) / (sleep_time  )) }')

          if [ "$irix_mode" -eq 0 ]; then
            pid_cpu_usage=$((pid_cpu_usage/num_of_cpus))
          fi
          log "$pid's $pid_cpu_usage%"

          if [ $pid_cpu_usage -ge $CPU_THRESHOLD ]; then
            log "PID $pid exceeded the CPU usage threshold, currently at $pid_cpu_usage%."
            break 2
          fi
        else
          log "PID $pid is no longer running."
          no_longer_running_pids="$no_longer_running_pids $pid"
        fi
        i=$((i + 1))
      done

      for pid in $no_longer_running_pids; do
        pids=$(remove_pid $pid "$pids")
      done

      if [ -z "$pids" ]; then
        log "No more running PIDs provided. Exiting script."
        exit 1
      elif [ -n "$no_longer_running_pids" ]; then
        log "Monitoring remaining PIDs: $pids"
        # Clear no_longer_running_pids to ensure it can be used later when $pid is no longer when issuing a kill -3 $pid.
        no_longer_running_pids=""
      fi
    done
  fi
  if [ $MONITOR_ONLY -eq 1 ]; then
    exit 0
  fi
}

##################################################################################
# If MONITOR_ONLY is true, no output data will be created after this if statement.
##################################################################################
if [ $MONITOR_ONLY -eq 1 ]; then
  log "linperf version:  $SCRIPT_VERSION."
  cpu_trigger
  # Future plan:
  # FileDescriptorTrigger?
  # SwapTrigger?
  exit 0
fi

#############################################
# Let user know path to a temporary directory
# and the inputs and beings are displayed.
#############################################
log "Temporary directory $OUTPUT_DIR created."
log "linperf version: $SCRIPT_VERSION."
for pid in $pids
do
  log "Provided PID: $pid"
done
log "SCRIPT_SPAN = $SCRIPT_SPAN"
if [ -z $disable_kill ]; then
  log "JAVACORE_INTERVAL = $JAVACORE_INTERVAL"
else
  log "Disable kill -3: true"
fi
log "TOP_INTERVAL = $TOP_INTERVAL"
log "TOP_DASH_H_INTERVAL = $TOP_DASH_H_INTERVAL"
log "VMSTAT_INTERVAL = $VMSTAT_INTERVAL"

# Call cpu_trigger(), which check the CPU_THRESHOLD before executing.
cpu_trigger

# Collect the user currently executing the script.
date > whoami.out
whoami >> whoami.out 2>&1
log "Collection of user authority data complete."

######################
# Start collection of:
#  * netstat x2
#  * ps -elf
#  * top
#  * top dash H
#  * vmstat
######################
# Collect the first netstat: date at the top, data, and then a blank line.
date >> netstat.out
netstat -pan >> netstat.out 2>&1
echo >> netstat.out
log "First netstat snapshot complete."

# Collect the ps -elf: date at the top, data, and then a blank line.
date >> ps.out
ps -elf >> ps.out 2>&1
ps aux >> ps.aux.out 2>&1
echo >> ps.out
log "Collected a ps -elf snapshot."

# Start the collection of top data.
# It runs in the background so that other tasks can be completed while this runs.
date >> top.out
echo >> top.out
top -bc -d $TOP_INTERVAL -n `expr $SCRIPT_SPAN / $TOP_INTERVAL + 1` >> top.out 2>&1 &
# Assign TOP's PID to top_pids. It will be used for terminating TOP processes
# when the script is unexpectedly finished early (e.g. pids are no longer running).
top_pids=$!
log "Collection of top data started."

# Start the collection of top dash H data.
# It runs in the background so that other tasks can be completed while this runs.
for pid in $pids
do
  log "Collected against PID $pid." >> topdashH.$pid.out
  echo >> topdashH.$pid.out
  top -bH -d $TOP_DASH_H_INTERVAL -n `expr $SCRIPT_SPAN / $TOP_DASH_H_INTERVAL + 1` -p $pid >> topdashH.$pid.out 2>&1 &
  top_pids="$top_pids $!"
  log "Collection of top dash H data started for PID $pid."
done

# Start the collection of vmstat data.
# It runs in the background so that other tasks can be completed while this runs.
date >> vmstat.out
vmstat $VMSTAT_INTERVAL `expr $SCRIPT_SPAN / $VMSTAT_INTERVAL + 1` >> vmstat.out 2>&1 &
log "Collection of vmstat data started."

#############################################################################
# Start collection of javacores and ps -eLf.
# Loop the appropriate number of times, pausing for the given amount of time,
# and iterate through each supplied PID.
# A kill -3 command will not be executed if disable_kill is true.
#############################################################################
n=1
m=`expr $SCRIPT_SPAN / $JAVACORE_INTERVAL`

if [ -n "$pids" ] && [ -z "$disable_kill" ]; then
  log "Issuing a kill -3 command for the provided PID(s) to create a javacore or a thread dump."
fi
while [ $n -le $m ]
do
  # Collect a ps snapshot: date at the top, data, and then a blank line.
  date >> ps.threads.out
  ps -eLf >> ps.threads.out 2>&1
  echo >> ps.threads.out
  log "Collected a ps -eLf snapshot."

  # Collect a javacore against the provided PID (passed in by the user).
  # Javacores are output to the working directory of the JVM; in most cases this is the <profile_root>.
  if [ -z "$disable_kill" ]; then
  for pid in $pids
  do
    kill_output=$(kill -3 $pid 2>&1)
    if [ $? -ne 0 ]; then
      log "PID $pid no longer exists."
      pids=$(remove_pid $pid "$pids")
      no_longer_running_pids="$no_longer_running_pids $pid"
      if [ -z "$pids" ]; then
        log "No more running PIDs provided, finishing the script."
        # Kill -3 $PID is no longer needed due to above.
        # Support team guides for locating javacores/thread dumps if they were produced before PIDs no longer exist.
        disable_kill=1
        break 3
      fi
    else
      log "Issued a kill -3 for PID $pid."
    fi
  done
  fi

  # Pause for JAVACORE_INTERVAL seconds.
  log "Continuing to collect data for $JAVACORE_INTERVAL seconds..."
  sleep $JAVACORE_INTERVAL

  # Increment counter
  n=`expr $n + 1`
done

# Collect a final javacore and ps -eLf snapshot.
date >> ps.threads.out
ps -eLf >> ps.threads.out 2>&1
echo >> ps.threads.out
log "Collected the final ps -eLf snapshot."

# Produce the final javacore.
if [ -z "$disable_kill" ]; then
  for pid in $pids
  do
    kill -3 $pid #>> screen.out 2>&1
    log "Produced the final javacore for PID $pid."
  done
fi

# Collect a final netstat.
date >> netstat.out
netstat -pan >> netstat.out 2>&1
log "Final netstat snapshot complete."

#########################
# Other data collection #
#########################
dmesg > dmesg.out 2>&1
df -hk > df-hk.out 2>&1

log "Collected other data."

# Terminate TOP processes created by this script.
trap 'kill $top_pids 2>/dev/null' EXIT
###############
# WSADMIN END #
###############

#########################
# Compress & Cleanup    #
#########################
# Brief pause to make sure all data is collected.
log "Preparing for packaging and cleanup..."
sleep 5

# Tar javacores
tarred_javacores_string=""
pids_not_found_javacores="$no_longer_running_pids"
TarJavacores()
{
  #scriptdir=$(pwd)
  # $1 - directory
  # $2 - javacore filenames
  # $3 - PID
  (cd ''"$1"'' && tar -cf ''"$OUTPUT_DIR/javacore.$3.tar"'' $2)
  temp_javacores_string="$tarred_javacores_string javacore.$3.tar "
  tarred_javacores_string=$temp_javacores_string
}
if [ -z "$disable_kill" ]; then
  for pid in $pids
  do
  # Check javacores in the default JVM directory.
  # Check -Xdump:directory.
  # Check environment entry IBM_JAVACOREDIR.
  # If any of above is true, gather javacores.
  # If javacores are not found, append PID to pids_not_found_javacores.
  JAVACORES="$(cd /proc/$pid/cwd/ && ls javacore* 2>/dev/null | awk -v pid="${pid}" -v startday="${START_DAY}" -v starttime="${START_TIME}" '/javacore\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.txt/ { str=$0; gsub(/.*\//, "", str); split(str, pieces, /\./); if ( pieces[4] == pid && pieces[2] >= startday && pieces[3] >= starttime ) { printf("%s ", $0); } } END { printf("\n"); }' )"
  if [ -n "${JAVACORES}" ]; then
    TarJavacores "/proc/$pid/cwd/" ''"$JAVACORES"'' $pid
  elif $(ps -fp $pid | grep -q -e "-Xdump:directory"); then
    XDUMPDIR="$(ps -fp $pid | sed '1d' | sed 's/.*\Xdump:directory=//g' | sed 's/\ -.*//g')"
    JAVACORES="$(cd ''"$XDUMPDIR"'' && ls javacore* 2>/dev/null | awk -v pid="${pid}" -v startday="${START_DAY}" -v starttime="${START_TIME}" '/javacore\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.txt/ { str=$0; gsub(/.*\//, "", str); split(str, pieces, /\./); if ( pieces[4] == pid && pieces[2] >= startday && pieces[3] >= starttime ) { printf("%s ", $0); } } END { printf("\n"); }' )"
    TarJavacores ''"$XDUMPDIR"'' ''"$JAVACORES"'' $pid
  elif $(ps ewww $pid | grep -q -e "IBM_JAVACOREDIR="); then
    IBM_JAVACOREDIR=$(ps ewww $pid | awk 'NR == 2 { for (i = 1; i < NF; i++) { if ($i ~ /.+=/) { state = 0; } if (state >= 1) { printf(" "); } if (state >= 1) { printf("%s", $i); state = 2; } if (state == 0 && $i ~ /^IBM_JAVACOREDIR=/) { state = 1; x = $i; gsub(/^IBM_JAVACOREDIR=/, "", x); printf("%s", x); } } printf("\n"); }')
    JAVACORES="$(cd ''"$IBM_JAVACOREDIR"'' && ls javacore* 2>/dev/null | awk -v pid="${pid}" -v startday="${START_DAY}" -v starttime="${START_TIME}" '/javacore\.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.txt/ { str=$0; gsub(/.*\//, "", str); split(str, pieces, /\./); if ( pieces[4] == pid && pieces[2] >= startday && pieces[3] >= starttime ) { printf("%s ", $0); } } END { printf("\n"); }' )"
    TarJavacores ''"$IBM_JAVACOREDIR"'' ''"$JAVACORES"'' $pid
  else
    log "Cannot locate javacores for PID $pid."
    temp_pids_string="$pids_not_found_javacores $pid"
    pids_not_found_javacores="$temp_pids_string "
  fi
  done
fi

# Tar/GZip the output files together and then remove the output files.
log "Compressing the following files into $DIR_NAME.tar.gz."
files_string="netstat.out vmstat.out ps.aux.out ps.out ps.threads.out top.out screen.out dmesg.out whoami.out df-hk.out $tarred_javacores_string"
for pid in $pids
do
  temp_string="topdashH.$pid.out"
  files_string="$files_string $temp_string"
done
for pid in $no_longer_running_pids
do
  temp_string="topdashH.$pid.out"
  files_string="$files_string $temp_string"
done
log "$(echo $files_string | sed 's/  / /g' | sed 's/ *$//')"

tar -cf ../$DIR_NAME.tar $files_string
if [ $? -ne 0 ]; then
  echo $(date '+%Y-%m-%d %H:%M:%S') "\tDue to above tar issue, the mentioned files in $DIR_NAME are not removed."
  dir_end_message="$OUTPUT_DIR"
else
  gzip ../$DIR_NAME.tar
  rm $files_string
fi

# Check if the current directory is empty before removing it.
# Otherwise, print out message and the output dir will not be removed.
if [ -n "$(ls -A)" ]; then
  echo $(date '+%Y-%m-%d %H:%M:%S') "\tFailed to remove the temporary $DIR_NAME directory."
else
  cd ..
  rm -r $DIR_NAME
  echo $(date '+%Y-%m-%d %H:%M:%S') "\tTemporary directory $DIR_NAME removed."
  dir_end_message="$OUTPUT_DIR.tar.gz"
fi

echo $(date '+%Y-%m-%d %H:%M:%S') "\tCleanup complete."
echo $(date '+%Y-%m-%d %H:%M:%S') "\tlinperf script complete."

if [ $KEEP_QUIET -eq 0 ]; then
  echo
  echo "$(tput setaf 0)$(tput setab 3)\t\t\t\t\t\t\t\t\t\t$(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  To share with IBM support, upload all the following files:"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * $dir_end_message"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * /var/log/messages (Linux OS files)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  For WebSphere Application Server:"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * Logs (systemout.log, native_stderr.log, etc)"

  if [ "${pids_not_found_javacores}" != "" ]; then
    echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * javacores from PID(s) $pids_not_found_javacores"
  fi

  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * server.xml for the server(s) that you are providing data for"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  For Liberty:"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * Logs (messages.log, console.log, etc)"

  if [ "${pids_not_found_javacores}" != "" ]; then
    echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * javacores from PID(s) $pids_not_found_javacores (if running on an IBM JDK)"
  fi

  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)  * server.env, server.xml, and jvm.options"
  echo "$(tput setaf 0)$(tput setab 3)  $(tput sgr 0)"
  echo "$(tput setaf 0)$(tput setab 3)\t\t\t\t\t\t\t\t\t\t$(tput sgr 0)"
fi
