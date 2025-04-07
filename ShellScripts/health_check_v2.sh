#!/bin/bash
# Get hostname and IP address

HOSTNAME=`hostname`
# Get current date and time
report_time=$(date +"%Y-%m-%d %H:%M:%S")
# Define HTML report file
report_file="${HOSTNAME}_health_check_report_$(date +"%Y-%m-%d_%H_%M_%S").html"
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
# Get system memory info
total_mem=$(free -g | awk '/^Mem:/{print $2}')
used_mem=$(free -g | awk '/^Mem:/{print $3}')
free_mem=$(free -g | awk '/^Mem:/{print $4}')
mem_util_percent=$(free -m | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}') # Convert to integer
# Highlight memory utilization in red if over 90%
if [ "$mem_util_percent" -gt 90 ]; then
    mem_util="<span style=\"color:red\">${mem_util_percent}%</span>"
else
    mem_util="${mem_util_percent}%"
fi
# Get CPU usage info
total_cpu=$(nproc)
cpu_util_percent=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.0f", 100 - $1}') # Convert to integer
# Highlight CPU utilization in red if over 90%
if [ "$cpu_util_percent" -gt 90 ]; then
    cpu_util="<span style=\"color:red\">${cpu_util_percent}%</span>"
else
    cpu_util="${cpu_util_percent}%"
fi
# Get top 3 processes by memory usage
top_mem_procs=$(ps aux --sort=-%mem | awk 'NR<=4{print $4"% CPU - "$3"% MEM - "$11}')
# Get top 3 processes by CPU usage
top_cpu_procs=$(ps aux --sort=-%cpu | awk 'NR<=4{print $3"% CPU - "$4"% MEM - "$11}')
# Get file system utilization with mount points and highlight usage over 90%
file_systems=$(df -h | grep '^/dev/' | awk '{usage=$5+0; if (usage >= 90) print "<span style=\"color:red\">" $1 " (" $6 "): " $5 "</span>"; else print $1 " (" $6 "): " $5}')
# Define an array of Java processes to monitor
declare -a java_processes=(
    "Websphere | grep java | grep server1 | grep -v grep | grep -v grep | grep -v grep"
    "TRS | grep TRS | grep java | grep -v server1 | grep -v grep | grep -v grep"
    "DBC | grep DBC | grep java | grep -v server1 | grep -v grep | grep -v grep"
    "RDBM | grep RDBM | grep java | grep -v server1 | grep -v grep | grep -v grep"
)
# Check Java process status
process_info=""
for process in "${java_processes[@]}"; do
    process_name=$(echo "$process" | awk -F'|' '{print $1}') # Extract process name before first pipe
    process_check=$(eval "ps -ef | ${process#*|}")
    if [[ -n "$process_check" ]]; then
        pid=$(echo "$process_check" | awk '{print $2}')
        start_time=$(ps -p "$pid" -o lstart=)
        total_time=$(ps -p "$pid" -o etime=)
        process_info+="<pre><span style=\"color:green\"><strong>${process_name} ==> Running:</strong></span> PID: $pid, Start Time: <b>$start_time</b>, Total Running Time: <b>$total_time</b></pre>"
    else
        process_info+="<pre><span style=\"color:red\"><strong>${process_name} ==> Not running</strong></span></pre>"
    fi
done
# Generate compact HTML report
cat << EOF > $report_file
<!DOCTYPE html>
<html>
<head>
    <title>Linux Health Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; color: #333; background-color: #FFFFFF; margin: 0; padding: 0; }
        .container { padding: 10px; }
        h1 { color: #4CAF50; text-align: center; font-size: 22px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; font-size: 14px; }
        th { background-color: #4CAF50; color: white; }
        td { background-color: #F9F9F9; }
        pre { font-size: 12px; background-color: #F5F5F5; padding: 10px; border-radius: 4px; }
        span { color: red; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${HOSTNAME}<br> Health Check Report</h1>
        <table>
            <tr>
                <th>Report Generated</th>
                <td>${report_time}</td>
            </tr>
            <tr>
                <th>Hostname</th>
                <td>${hostname}</td>
            </tr>
            <tr>
                <th>IP Address</th>
                <td>${ip_address}</td>
            </tr>
            <tr>
                <th>Total Memory</th>
                <td>${total_mem}GB</td>
            </tr>
            <tr>
                <th>Memory Utilization</th>
                <td>${mem_util}</td>
            </tr>
            <tr>
                <th>Total CPU Cores</th>
                <td>${total_cpu}</td>
            </tr>
            <tr>
                <th>CPU Utilization</th>
                <td>${cpu_util}</td>
            </tr>
        </table>
        <h2 style="font-size: 18px; color: #4CAF50;">Top 3 Processes by Memory Usage:</h2>
        <pre>$top_mem_procs</pre>
        <h2 style="font-size: 18px; color: #4CAF50;">Top 3 Processes by CPU Usage:</h2>
        <pre>$top_cpu_procs</pre>
        <h2 style="font-size: 18px; color: #4CAF50;">File System Utilization:</h2>
        <pre>$file_systems</pre>
        <h2 style="font-size: 18px; color: #4CAF50;">Java Processes Status:</h2>
        $process_info
    </div>
</body>
</html>
EOF
# Notify user of report location
echo "HTML report generated: $report_file"
