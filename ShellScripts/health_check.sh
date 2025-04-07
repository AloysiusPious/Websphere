#!/bin/bash
SCRIPT_HOME="/WASapp/scripts/sys_operations"
HOSTNAME=$(hostname)
report_time=$(date +"%Y-%m-%d %H:%M:%S")
TOP_PROCESS=8
REPORT_DIR="${SCRIPT_HOME}/reports"
ARCHIVE_DIR="${REPORT_DIR}/archive"
mkdir -p ${REPORT_DIR}
mkdir -p ${ARCHIVE_DIR}
mv ${REPORT_DIR}/*.html ${ARCHIVE_DIR}
report_file="${REPORT_DIR}/${HOSTNAME}_health_check_report_$(date +"%Y-%m-%d_%H_%M_%S").html"
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
total_mem=$(free -g | awk '/^Mem:/{print $2}')
used_mem=$(free -g | awk '/^Mem:/{print $3}')
free_mem=$(free -g | awk '/^Mem:/{print $4}')
mem_util_percent=$(free -m | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}')
mem_util="<span style=\"color:red\">${mem_util_percent}%</span>"
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
#top_mem_procs=$(ps aux --sort=-%mem | awk -v limit=$TOP_PROCESS 'NR<=limit{print $4"% MEM - "$3"% CPU - "$11}')
#top_cpu_procs=$(ps aux --sort=-%cpu | awk -v limit=$TOP_PROCESS 'NR<=limit{print $3"% CPU - "$4"% MEM - "$11}')
top_mem_procs=$(ps aux --sort=-%mem | awk -v limit=$TOP_PROCESS 'NR<=limit {
    mem=$4+0; cpu=$3+0;
    if (mem > 80) printf "<span style=\"color:red\">%.2f%% MEM - %.2f%% CPU - %s</span>\n", mem, cpu, $11;
    else printf "%.2f%% MEM - %.2f%% CPU - %s\n", mem, cpu, $11
}')
top_cpu_procs=$(ps aux --sort=-%cpu | awk -v limit=$TOP_PROCESS 'NR<=limit {
    mem=$4+0; cpu=$3+0;
    if (cpu > 80) printf "<span style=\"color:red\">%.2f%% CPU - %.2f%% MEM - %s</span>\n", cpu, mem, $11;
    else printf "%.2f%% CPU - %.2f%% MEM - %s\n", cpu, mem, $11
}')
file_systems=$(df -h | grep '^/dev/' | awk '{usage=$5+0; if (usage >= 90) print "<span style=\"color:red\">" $1 " (" $6 "): " $5 "</span>"; else print $1 " (" $6 "): " $5}')
declare -a java_processes_app1=(
    "Websphere | grep java | grep server1 | grep -v grep"
    "TRS | grep TRS | grep java | grep -v server1 | grep -v grep"
    "DBC | grep DBC | grep java | grep -v server1 | grep -v grep"
    "RDBM | grep RDBM | grep java | grep -v server1 | grep -v grep"
	"Athena | grep DFNALGO | grep java | grep -v server1 | grep -v grep"
)
process_info="<table><tr><th>S.No</th><th>Process Name</th><th>Status</th><th>PID</th><th>Start Date</th><th>Start Time</th><th>Uptime</th></tr>"
serial=1
for process in "${java_processes_app1[@]}"; do
    process_name=$(echo "$process" | awk -F'|' '{print $1}')
    process_check=$(eval "ps -ef | ${process#*|}")
    if [[ -n "$process_check" ]]; then
        pid=$(echo "$process_check" | awk '{print $2}')
        start_time=$(ps -p "$pid" -o lstart=)
        total_time=$(ps -p "$pid" -o etime=)
        process_info+="<tr><td>${serial}</td><td>${process_name}</td><td><span style=\"color:green\">Running</span></td><td>${pid}</td><td>${start_time:0:10}${start_time:19}</td><td>${start_time:10:9}</td><td>${total_time}</td></tr>"
    else
        process_info+="<tr><td>${serial}</td><td>${process_name}</td><td><span style=\"color:red\">Not running</span></td><td>N/A</td><td>N/A</td><td>N/A</td><td>N/A</td></tr>"
    fi
    ((serial++))
done
process_info+="</table>"
# Define MQ and Database hosts and ports
#declare -a mq_hosts=("mq_host1" "mq_host2")
declare -a mq_hosts_1=("167.111.4.232")
declare -a mq_hosts_2=("167.111.4.88")
###########
declare -a mq_ports_1=(11001 11002 11003 11004 11007)
declare -a mq_ports_2=(11001 11002 11003 11004)
#############
declare -a db_hosts=("10.100.203.35" "10.100.203.36" "10.100.203.37" "10.100.203.38" "10.100.203.39" "mubasherdb-scan")
declare -a db_ports=(5070)
# Generate Telnet Connection Status for MQ and Database Hosts
mq_info="<table><tr><th>S.No</th><th>MQ Host IP</th><th>Connection Status</th></tr>"
serial=1
for mq_host in "${mq_hosts_1[@]}"; do
    for port in "${mq_ports_1[@]}"; do
        if nc -z -w5 "$mq_host" "$port" &>/dev/null; then
            status="<span style=\"color:green\">Success</span>"
        else
            status="<span style=\"color:red\">Failed</span>"
        fi
        mq_info+="<tr><td>${serial}</td><td>${mq_host}:${port}</td><td>${status}</td></tr>"
        ((serial++))
    done
done
for mq_host in "${mq_hosts_2[@]}"; do
    for port in "${mq_ports_2[@]}"; do
        if nc -z -w5 "$mq_host" "$port" &>/dev/null; then
            status="<span style=\"color:green\">Success</span>"
        else
            status="<span style=\"color:red\">Failed</span>"
        fi
        mq_info+="<tr><td>${serial}</td><td>${mq_host}:${port}</td><td>${status}</td></tr>"
        ((serial++))
    done
done
mq_info+="</table>"
db_info="<table><tr><th>S.No</th><th>Database Host IP</th><th>Connection Status</th></tr>"
serial=1
for db_host in "${db_hosts[@]}"; do
    for port in "${db_ports[@]}"; do
        if nc -z -w5 "$db_host" "$port" &>/dev/null; then
            status="<span style=\"color:green\">Success</span>"
        else
            status="<span style=\"color:red\">Failed</span>"
        fi
        db_info+="<tr><td>${serial}</td><td>${db_host}:${port}</td><td>${status}</td></tr>"
        ((serial++))
    done
done
db_info+="</table>"
cat << EOF > $report_file
<!DOCTYPE html>
<html>
<head>
    <title>Linux Health Check Report</title>
    <style>
        body { font-family: Arial, sans-serif; color: #333; background-color: #FFFFFF; margin: 0; padding: 0; }
        .container { padding: 20px; }
        h1 { color: #4CAF50; text-align: center; font-size: 22px; }
		 h2 { color: #4CAF50; text-align: left; font-size: 18px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 0px; }
        th, td { padding: 5px; text-align: left; border-bottom: 0px solid #ddd; font-size: 14px; }
        th { background-color: #2980B9; color: white; }
        td { background-color: #F9F9F9; }
        pre { font-size: 12px; background-color: #F5F5F5; padding: 0px; border-radius: 4px; }
        .header-table th, .header-table td { font-size: 14px; }
		    footer { text-align: center; padding: 3px 0; border-top: 1px solid #ccc; font-size: 12px; color: #1F618D;}
    </style>
</head>
<body>
    <div class="container">
        <h1>${HOSTNAME}</h1>
        <table class="header-table">
            <tr>
                <th>Report Generated</th><th>Hostname</th><th>IP Address</th><th>Total Memory</th><th>Memory Utilization</th><th>Total CPU Cores</th><th>CPU Utilization</th>
            </tr>
            <tr>
                <td>${report_time}</td><td>${hostname}</td><td>${ip_address}</td><td>${total_mem}GB</td><td>${mem_util}</td><td>${total_cpu}</td><td>${cpu_util}</td>
            </tr>
        </table>
        <table>
            <tr><th>Top $(expr $TOP_PROCESS - 1) Processes by Memory Usage</th><th>Top $(expr $TOP_PROCESS - 1) Processes by CPU Usage</th><th>File System Utilization</th></tr>
            <tr><td><pre>${top_mem_procs}</pre></td><td><pre>${top_cpu_procs}</pre></td><td><pre>${file_systems}</pre></td></tr>
        </table>

        <h2 style="color: #2E86C1;">Java Processes Status</h2>
        $process_info
        <h2 style="color: #2E86C1;">MQ Connection Status</h2>
        $mq_info
        <h2 style="color: #2E86C1;">Database Connection Status</h2>
        $db_info
    </div>
</body>
</html>
EOF
scp $report_file wasadm@x.x.x.x:/jboss/jbcs-httpd24-2.4/httpd/www/html/health/app-vertical-1/$(date +"%H_%M_%Y-%m-%d").html
ssh wasadm@x.x.x.x 'chmod 755 /jboss/jbcs-httpd24-2.4/httpd/www/html/health/app-vertical-1/$(date +"%H_%M_%Y-%m-%d").html'
find "$ARCHIVE_DIR" -name "*health_check_report*" -type f -mtime +7 -exec rm -f "{}" \;
echo "HTML report generated: $report_file"
