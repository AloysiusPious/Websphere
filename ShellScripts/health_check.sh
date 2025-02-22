#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-22
# Description: This script to generate Health of Linux System and generate html report
#################################################################################################
#!/bin/bash
# Get current date and time
report_time=$(date +"%Y-%m-%d %H:%M:%S")
# Define HTML report file
report_file="health_check_report_$(date +"%Y-%m-%d_%H_%M_%S").html"
# Get hostname and IP address
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
# Get system memory info
total_mem=$(free -g | awk '/^Mem:/{print $2}')
used_mem=$(free -g | awk '/^Mem:/{print $3}')
free_mem=$(free -g | awk '/^Mem:/{print $4}')
mem_util=$(free -m | awk '/^Mem:/{print $3 "MB of " $2 "MB"}')
# Get CPU usage info
total_cpu=$(nproc)
cpu_util=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
# Get top 5 processes by memory usage
top_mem_procs=$(ps aux --sort=-%mem | awk 'NR<=6{print $4"% CPU - "$3"% MEM - "$11}')
# Get top 5 processes by CPU usage
top_cpu_procs=$(ps aux --sort=-%cpu | awk 'NR<=6{print $3"% CPU - "$4"% MEM - "$11}')
# Get file system utilization with mount points
file_systems=$(df -h | grep '^/dev/' | awk '{print $1 " (" $6 "): " $5}')
# Print results to screen
echo "Report Generated: $report_time"
echo "Hostname: $hostname"
echo "IP Address: $ip_address"
echo "Memory Utilization: $mem_util"
echo "CPU Utilization: $cpu_util"
echo "Total Memory: ${total_mem}GB"
echo "Top 3 Processes by Memory Usage:"
echo "$top_mem_procs"
echo "Top 3 Processes by CPU Usage:"
echo "$top_cpu_procs"
echo "File System Utilization:"
echo "$file_systems"
# Generate colorful HTML report
cat << EOF > $report_file
<!DOCTYPE html>
<html>
<head>
    <title>Linux Health Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f0f8ff; color: #333; }
        h1 { color: #4CAF50; text-align: center; }
        p { font-size: 16px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 2px solid #ddd; }
        th { background-color: #4CAF50; color: white; }
        td { background-color: #f9f9f9; }
        pre { background: #282c34; color: #61dafb; padding: 10px; border-radius: 5px; white-space: pre-wrap; word-wrap: break-word; }
        h2 { color: #4CAF50; }
    </style>
</head>
<body>
    <h1>Linux Health Check Report</h1>
    <table>
        <tr>
            <th>Report Generated</th>
            <th>Hostname</th>
            <th>IP Address</th>
            <th>Total Memory</th>
            <th>Memory Utilization</th>
            <th>Total CPU Cores</th>
            <th>CPU Utilization</th>
        </tr>
        <tr>
            <td>${report_time}</td>
            <td>${hostname}</td>
            <td>${ip_address}</td>
            <td>${total_mem}GB</td>
            <td>${mem_util}</td>
            <td>${total_cpu}</td>
            <td>${cpu_util}</td>
        </tr>
    </table>
    <h2>Top 5 Processes by Memory Usage:</h2>
    <pre>$top_mem_procs</pre>
    <h2>Top 5 Processes by CPU Usage:</h2>
    <pre>$top_cpu_procs</pre>
    <h2>File System Utilization:</h2>
    <pre>$file_systems</pre>
</body>
</html>
EOF
# Notify user of report location
echo "HTML report generated: $report_file"