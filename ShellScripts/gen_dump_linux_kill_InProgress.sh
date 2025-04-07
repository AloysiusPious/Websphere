#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-18
# Description:  to generate Keep and dump files using Linux KIll command
# Old Dump directories will be cleaned automatically
#################################################################################################
# Check if the script is being run as "wasadm"
if [ `whoami` != "wasadm" ]; then
  echo "Please run this script as \"wasadm\""
  exit 1
fi
# Check if the PID is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <PID>"
    exit 1
fi
# Variables
PID=$1  # Pass the WebSphere process ID as an argument
output_dir="/WASapp/dumps/$(date '+%Y%m%d_%H%M%S')_linux_kill"
PROFILE_HOME=$(ps -p "$PID" -o args= | grep -oP '[-]Djava\.security\.policy=\K[^ ]+/profiles/[^/]+')
mkdir -p "$output_dir"
# Generate Java Core (Thread Dump)
echo "Generating Java core (thread dump) for PID $PID..."
kill -3 "$PID"
sleep 5  # Wait for the thread dump to be written
# Generate Heap Dump
echo "Generating heap dump for PID $PID..."
heap_dump_file="$output_dir/heapdump_$(date '+%Y%m%d_%H%M%S').phd"
jmap -F -dump:format=b,file="$heap_dump_file" "$PID"
# Verify creation
if [[ -f "$heap_dump_file" ]]; then
    echo "Heap dump successfully created: $heap_dump_file"
else
    echo "Heap dump failed."
fi
# Move the Java core dump files to the output directory
mv ${PROFILE_HOME}/javacore* "$output_dir/"
echo "Java core and heap dump generation complete."
echo "Files are stored in $output_dir"
