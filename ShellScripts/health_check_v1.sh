#!/bin/bash
# Get hostname and IP address
CLUSTER_MEMBER="App Vertical-1"
# Get current date and time
report_time=$(date +"%Y-%m-%d %H:%M:%S")
# Define HTML report file
report_file="health_check_report_$(date +"%Y-%m-%d_%H_%M_%S").html"

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
# Get top 3 processes by memory usage
top_mem_procs=$(ps aux --sort=-%mem | awk 'NR<=4{print $4"% CPU - "$3"% MEM - "$11}')
# Get top 3 processes by CPU usage
top_cpu_procs=$(ps aux --sort=-%cpu | awk 'NR<=4{print $3"% CPU - "$4"% MEM - "$11}')
# Get file system utilization with mount points
file_systems=$(df -h | grep '^/dev/' | awk '{print $1 " (" $6 "): " $5}')
# Generate compact HTML report
cat << EOF > $report_file
<!DOCTYPE html>
<html>
<head>
    <title>Linux Health Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; color: #333; background-color: #ffffff; margin: 0; padding: 0; }
        .container { padding: 10px; }
        h1 { color: #4CAF50; text-align: center; font-size: 22px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 10px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; font-size: 14px; }
        th { background-color: #4CAF50; color: white; }
        td { background-color: #f9f9f9; }
        pre { font-size: 12px; background-color: #f5f5f5; padding: 10px; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${CLUSTER_MEMBER}<br> Health Check Report</h1>
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
    </div>
</body>
</html>
EOF
# Notify user of report location
echo "HTML report generated: $report_file"
