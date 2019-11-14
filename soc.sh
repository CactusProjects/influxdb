#!/bin/bash
#http://cactusprojects.com/rpi-status-log-to-influxdb/
# Gets SOC GPU Temperatures
gpu_temp_0=$(/opt/vc/bin/vcgencmd measure_temp | tr -cd '0-9.')

# Gets System Uptime
uptime=0
uptime=$(awk '{print $1}' /proc/uptime)

# Gets SOC CPU Temperatures
cpu_temp_0=$(cat /sys/class/thermal/thermal_zone0/temp)
cpu_temp_1=$(($cpu_temp_0/1000))
cpu_temp_2=$(($cpu_temp_0/100))
cpu_temp_3=$(($cpu_temp_2 % $cpu_temp_1))
cpu_temp_4=$cpu_temp_1"."$cpu_temp_3

# Converts the total CPU Usage into %
PREV_TOTAL=0
PREV_IDLE=0
Average=0

  for i in {1..6}
  do
  # Since the CPU fluctuates, it discards the first reading and averages the next 5.
  CPU=(`sed -n 's/^cpu\s//p' /proc/stat`) # Discards the cpu prefix
  IDLE=${CPU[3]} 			  # Just the idle CPU time.

  # Calculate the total CPU time.
  TOTAL=0
  for VALUE in "${CPU[@]}"; do
    let "TOTAL=$TOTAL+$VALUE"
  done

  # Calculate the CPU usage since we last checked.
  let "DIFF_IDLE=$IDLE-$PREV_IDLE"
  let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
  let "DIFF_USAGE=(1000*($DIFF_TOTAL-$DIFF_IDLE)/$DIFF_TOTAL+5)/10"

  # Remember the total and idle CPU times for the next check.
  PREV_TOTAL="$TOTAL"
  PREV_IDLE="$IDLE"

if [ $i -gt 1 ] # Ignores 1st reading as this is CPU average since boot
    then
	let Average="$DIFF_USAGE+$Average"
fi

  # Wait 1s before checking again.
  sleep 1
done

let Average="$Average/5"

#Minor to do:
#cat /proc/device-tree/model - Shows RPI Model, add this to the post to database

curl -i -XPOST 'http://your.influxDB.ip.address:8086/write?db=rpi_01' --data-binary 'system_status,system=RPI-01,system_model=Insert_Model_Name cpu_usage='$Average',cpu_temp='$cpu_temp_4',gpu_temp='$gpu_temp_0',uptime='$uptime'' 

# Debugging Terminal Output
#echo -en "\r\nCPU Average Since Boot: $DIFF_USAGE"
#echo -en "\r\nCPU Current 5s Average: $Average"
#echo -en "\r\nCPU Current Temp: $cpu_temp_0"
#echo -en "\r\nGPU Current Temp: $gpu_temp_0"
#echo -en "\r\nSystem Uptime (s): $uptime \r\n"

