#!/bin/bash
HOST=$(hostname)
export iopFilename="${HOST}_ioptest.txt"
export iopCputempfile="${HOST}_cputemp_during_ioptest.txt"
export iopDrivetempfile="${HOST}_drivetemp_during_ioptest.txt"
export throughPutFilename="${HOST}_throughputtest.txt"
export throughPutCputempfile="${HOST}_cputemp_during_throughputtest.txt"
export throughPutDrivetempfile="${HOST}_drivetemp_during_throughputtest.txt"
function nasburnin::multipledrives(){
        joined_string=""
        for item in "${devicearray[@]}"; do
                if [ -n "$joined_string" ]; then
                        joined_string="${joined_string}:${item}"
                else
                        joined_string="$item"
                fi
        done

        sudo sed -i '/^filename=/c\filename="'"$joined_string"'"'   ioptest.fio
        sudo sed -i '/^filename=/c\filename="'"$joined_string"'"'   throughputtest.fio
}

function nasburnin::singledrive(){
        sudo sed -i '/^filename=/c\filename="'"$device"'"'   ioptest.fio
        sudo sed -i '/^filename=/c\filename="'"$device"'"'   throughputtest.fio
}


# https://forum.qnap.com/viewtopic.php?t=175559

function nasburnin::show_help(){
    echo "Usage: $0 [options]"
    echo "Options:" 
    echo "  --iop"
    echo "  --throughput"
    echo "  --singledrive"
    echo "  --multiple"
    echo "  --qnap"
    echo "  --qnapiop"
    echo "  --qnapthroughput"
}

function nasburnin::qnap(){
    echo $(cat /etc/smb.conf | grep -i path)
    qnapfile="${HOST}_qnaptest.txt"
    qcli_storage -T force=1 >> $qnapfile
    devicearray=($(qcli_storage | awk 'NR > 1 {print $3}' | tr '(X)' ' '))
    sudo sed -i '/^filename=/c\filename=test_device'   ioptest.fio
    sudo sed -i '/^filename=/c\filename=test_device'   throughputtest.fio

    nasburnin::qnapioptest
    sleep 120
    nasburnin::qnapthroughputtest
}

function nasburnin::qnapioptest(){
    fio  ioptest.fio >> $iopFilename &
    cmd_pid=$!
    $cputemp=$(get_cpu_temp)
    $drivetemp=$(get_hd_temp 2)
    while true; do
        echo $cputemp
        date >> $iopCputempfile
        get_cpu_temp >> $iopCputempfile
        echo $drivetemp
        date >> $iopDrivetempfile
        get_hd_temp 2 >> $iopDrivetempfile
        if [[ $cputemp == *"90"* || $drivetemp == *"55"* ]]; then
            sudo kill $cmd_pid
            echo "Test stopped because CPU or Drive temperature too high"
            echo "Temperature of CPU or Drive too high auto killed" >> $iopFilename
            break
        fi
        if ps -o pid | grep -w $cmd_pid > /dev/null; then
            echo "still running"
        else
            echo "Test completed Successfully" >> $iopFilename
            break
        fi
        sleep 5
    done 
}

function nasburnin::qnapthroughputtest(){
    fio  throughputtest.fio >> $throughPutFilename &
    cmd_pid=$!
    $cputemp=$(get_cpu_temp)
    $drivetemp=$(get_hd_temp 2)
    while true; do
        echo $cputemp
        date >> $throughPutCputempfile
        get_cpu_temp >> $throughPutCputempfile
        echo $drivetemp
        date >> $throughPutDrivetempfile
        get_hd_temp 2 >> $throughPutDrivetempfile
        if [[ $cputemp == *"90"* || $drivetemp == *"55"* ]]; then
            sudo kill $cmd_pid
            echo "Test stopped because CPU or Drive temperature too high"
            echo "Temperature of CPU or Drive too high auto killed" >> $throughPutFilename
            break
        fi
        if ps -o pid | grep -w $cmd_pid  > /dev/null; then
            echo "still running"
        else
            echo "Test completed Successfully" >> $throughPutFilename
            break
        fi
        sleep 5
    done 
}


function nasburnin::parse_options(){
    while :; do
        case $1 in
            -h|-\?|--help)
                nasburnin::show_help
                exit
            ;;
            --singledrive)
                nasburnin::singledrive
                exit
                ;;
            --multiple)
                nasburnin::multipledrives
                exit
                ;;
            --iop)
                nasburnin::ioptest
                exit
                ;;
            --throughput)
                nasburnin::throughput
                exit
                ;;
            --qnap)
                nasburnin::qnap
                exit
                ;;
            --qnapiop)
                nasburnin::qnapioptest
                exit
                ;;
            --qnapthroughput)
                nasburnin::qnapthroughputtest
                exit
                ;;
            *)
                nasburnin::singledrive
                exit
                ;;
        esac
    done
}

function nasburnin::ioptest(){
    fio  ioptest.fio >> $iopDrivetempfile &
    cmd_pid=$!
    device=$(cat  ioptest.fio | grep -i filename | sed 's/filename=//g' | cut -d':' -f1)
    echo $device
    while true; do
        cputemp=$(sensors | grep -i 'Core 0' | awk '{print $3}')
        echo $cputemp
        date >> $iopCputempfile
        sensors >> $iopCputempfile
        date >> $iopDrivetempfile
        devicearray=($(cat  ioptest.fio | grep -i filename | sed 's/filename=//g' | tr ':' ' '))
        # Print the array elements
        for i in "${devicearray[@]}"; do
                echo "$i" >> $iopDrivetempfile
                echo "$(smartctl -a $i | grep -i Temperature)" >> $iopDrivetempfile
        done
        drivetempcommand="smartctl -a $device | grep -i airflow_temperature_cel | awk '{print $10}'"
        drivetemp=$(smartctl -a $device | grep -i airflow_temperature_cel | awk '{print $10}')
        echo $drivetemp
        if [[ $cputemp == *"90"* || $drivetemp == *"55"* ]]; then
            sudo kill $cmd_pid
            echo "Test stopped because CPU or Drive temperature too high"
            echo "Temperature of CPU or Drive too high auto killed" >> $iopFilename
            break
        fi
        if ps -p $cmd_pid > /dev/null; then
            echo "still running"
        else
            echo "Test completed Successfully" >> $iopFilename
            break
        fi
        sleep 5
    done 
}



function nasburnin::throughput(){
    fio  throughputtest.fio >> $throughPutFilename &
    cmd_pid=$!
    device=$(cat  throughputtest.fio | grep -i filename | sed 's/filename=//g' | cut -d':' -f1)
    echo $device
    cputempcommand="sensors | grep -i 'Core 0' | awk '{print $3}'"
    drivetempcommand="smartctl -a $device | grep -i airflow_temperature_cel | awk '{print $10}'"
    while true; do
        cputemp=$(sensors | grep -i 'Core 0' | awk '{print $3}')
        echo $cputemp
        date >> $throughPutCputempfile
        sensors >> $throughPutCputempfile
        date >> $throughPutDrivetempfile
        devicearray=($(cat  throughputtest.fio | grep -i filename | sed 's/filename=//g' | tr ':' ' '))
        # Print the array elements
        multipledrivetemps=()
        for i in "${devicearray[@]}"; do
                echo "$i" >> $throughPutDrivetempfile
                smartctl -a $i | grep -i Temperature >> $throughPutDrivetempfile
                drivetemp=$(smartctl -a $i | grep -i airflow_temperature_cel | awk '{print $10}')
                multipledrivetemps+=("$drivetemp")
        done
        drivetemp=$(smartctl -a $device | grep -i airflow_temperature_cel | awk '{print $10}')
        echo $drivetemp
        if [[ $cputemp == *"90"* || $drivetemp == *"55"* ]]; then
            sudo kill $cmd_pid
            echo "Test stopped because CPU or Drive temperature too high"
            echo "Temperature of CPU or Drive too high auto killed" >> $throughPutFilename
        fi
        if ps -p $cmd_pid > /dev/null; then
            echo "still running"
        else
            echo "Test completed Successfully" >> $throughPutFilename
            break
        fi
        sleep 5
    done
}

function nasburnin::main(){
    nasburnin::parse_options "$@"
    nasburnin::ioptest
    sleep 120
    nasburnin::throughput
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "${BASH_SOURCE[0]##*/}"
    nasburnin::main "$@"
else
    if [[ "${USE_SOURCED_FUNCTION}" == true ]]; then
        echo "${0##*/} loaded ${BASH_SOURCE[0]##*/}"
    else
        echo "${0##*/} running ${BASH_SOURCE[0]##*/}"
        nasburnin::main "$@"
    fi
fi