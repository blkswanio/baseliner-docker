#!/bin/bash
set -ex

cd ~/complete
nohup python3 "$(dirname ${BASH_SOURCE[0]})"/simplehttp.py 0.0.0.0:8000 > ~/http.log 2> ~/http_error.log &

cd "$(dirname ${BASH_SOURCE[0]})"

###############################
### Environment Information ###
###############################
echo -n "Getting Environment Information - "
date
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install hwinfo numactl -y
timestamp=$(date -u +%s)
run_uuid=$(uuidgen)
nodeid=$(cat /var/emulab/boot/nodeid)
nodeuuid=$(cat /var/emulab/boot/nodeuuid)
gcc_ver=$(gcc --version | grep gcc | awk '{print $4}')

# HW info, no PCI bus on ARM means lshw doesn't have as much information
nthreads=$(nproc --all)
total_mem=$(sudo hwinfo --memory | grep "Memory Size" | awk '{print $3 $4}')
arch=$(uname -m)
kernel_release=$(uname -r)
os_release=$(. /etc/os-release; echo "Ubuntu" ${VERSION/*, /})
# Because ARM has to do cpuinfo so differently, hardcode for non x86_64...
nsockets=1
if [ ${arch} == 'x86_64' ]; then
    nsockets=$(cat /proc/cpuinfo | grep "physical id" | sort -n | uniq | wc -l)
    cpu_model=$(lscpu | grep "Model name:" | awk '{print substr($0, index($0, $3))}')
    mem_clock_speed=$(sudo dmidecode --type 17  | grep "Configured Clock Speed" | head -n 1 | awk '{print $4}')
    mem_clock_speed=${mem_clock_speed}MHz
elif [ ${arch} == 'aarch64' ]; then
    cpu_model="ARMv8 (Atlas/A57)"
    mem_clock_speed="Unknown(ARM)"
else
    # Temp placeholder for unknown architecture
    cpu_model="Unknown(Unknown_Arch)"
    mem_clock_speed="Unknown(Unknown_Arch)"
fi

# Hash
version_hash=$(git rev-parse HEAD)

# Write to file
echo "run_uuid,timestamp,nodeid,nodeuuid,arch,gcc_ver,version_hash,total_mem,mem_clock_speed,nthreads,nsockets,cpu_model,kernel_release,os_release" > ~/env_out.csv
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$arch,$gcc_ver,$version_hash,$total_mem,$mem_clock_speed,$nthreads,$nsockets,$cpu_model,$kernel_release,$os_release" >> ~/env_out.csv

###########################
### Network Information ###
###########################
echo -n "Getting Network Information - "
date
# Grab the physical interface serving the VLAN
vlan_to_link=$(sudo ip link | grep vlan | awk '{print $2}' | tr '@' ' ' | tr -d ':')

# Parse VLAN info
vlan_name=$(echo $vlan_to_link | awk '{print $1}')
vlan_ip=$(sudo ip addr show dev $vlan_name | grep 'inet' | grep -v 'inet6' | awk '{print $2}' |  cut -d"/" -f 1)
vlan_hwaddr=$(sudo ip addr show dev $vlan_name | grep 'link/ether' | awk '{ print $2 }')
vlan_driver=$(sudo ethtool -i $vlan_name | grep driver | awk '{print substr($0, index($0, $2))}')
vlan_driver_ver=$(sudo ethtool -i $vlan_name | grep version | grep -v -E 'firmware|rom' | awk '{print substr($0, index($0, $2))}')

# Parse interface info
if_name=$(echo $vlan_to_link | awk '{print $2}')
if_hwaddr=$(sudo ip addr show dev $if_name | grep 'link/ether' | awk '{ print $2 }')
# Utah machines (actually now only m510s) like to put the vendor information on the parent, so here's a workaround
# This actually seems to not be an issue anymore.  Commenting out and seeing what happens.
#if [ ! -z $(grep 'ms' /var/emulab/boot/nodeid) ] && [ ${arch} == 'x86_64' ]; then
#    if_hwinfo=$(sudo lshw -class network -businfo | grep ${if_name::-2} | grep -v $if_name | awk '{print substr($0, index($0, $4))}')
#else
if_hwinfo=$(sudo lshw -class network -businfo | grep $if_name | awk '{print substr($0, index($0, $4))}')
#fi
if_speed=$(sudo ethtool $if_name | grep Speed | awk '{print $2}')
if_duplex=$(sudo ethtool $if_name | grep Duplex | awk '{print $2}')
if_port_type=$(sudo ethtool $if_name | grep Port | awk '{print substr($0, index($0, $2))}')
if_driver=$(sudo ethtool -i $if_name | grep driver | awk '{print substr($0, index($0, $2))}')
if_driver_ver=$(sudo ethtool -i $if_name | grep version | grep -v -E 'firmware|rom' | awk '{print substr($0, index($0, $2))}')
if_bus_location=$(sudo ethtool -i $if_name | grep bus | awk '{print $2}')

echo "run_uuid,timestamp,nodeid,nodeuuid,vlan_name,vlan_ip,vlan_hwaddr,vlan_driver,vlan_driver_ver,if_name,if_hwaddr,if_hwinfo,if_speed,if_duplex,if_port_type,if_driver,if_driver_ver,if_bus_location" > ~/net_info.csv
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$vlan_name,$vlan_ip,$vlan_hwaddr,$vlan_driver,$vlan_driver_ver,$if_name,$if_hwaddr,$if_hwinfo,$if_speed,$if_duplex,$if_port_type,$if_driver,$if_driver_ver,$if_bus_location" >> ~/net_info.csv


# #######################
# ### Network Latency ###
# #######################
# echo -n "Running Standard Network Latency Tests - "
# date
# # Install dependencies
# sudo apt-get install libcap-dev libidn2-0-dev nettle-dev libnuma-dev -y

# # Build ping from source
# cd ./iputils-ns
# make

# # Define destination host and get the exposed dest_nodeid from server
# net_server=192.168.1.100
# dest_nodeid=$(curl $net_server:8000/nodeid)
# # Check status of previous command.
# if [ $? -ne 0 ]; then
#     dest_nodeid="NOTFOUND"
# fi

# # Run ping before everything else.
# # Ping can potentially affect iperf3 results, so to be safe we run ping
# # at such a point that it can never run at the same time as iperf3.
# # Gather info and set up vars first
# ping_version=$(./ping -V | awk '{print $3}')
# ping_count=10000
# ping_size=56

# echo "run_uuid,timestamp,nodeid,nodeuuid,ping_version,ping_count,ping_source_ip,ping_dest_ip,ping_dest_nodeid,ping_size" > ~/ping_info.csv
# echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$ping_version,$ping_count,$vlan_ip,$net_server,$dest_nodeid,$ping_size" >> ~/ping_info.csv

# # Run ping as a flood, and in quiet mode.  Must be sudo.
# sudo timeout 30 ./ping -s $ping_size -f -q -c $ping_count $net_server > ~/temp_ping.out

# # Check status of previous command.
# if [ $? -eq 0 ]; then
#     pkts_sent=$(grep packets ~/temp_ping.out | awk '{print $1}')
#     pkts_received=$(grep packets ~/temp_ping.out | awk '{print $4}')
#     pkt_loss=$(grep packets ~/temp_ping.out | awk '{print $6}')
#     ping_time=$(grep packets ~/temp_ping.out | awk '{print $10}')

#     ping_stats=$(grep rtt ~/temp_ping.out | awk '{print $4}' | tr '/' ' ')
#     ping_min=$(echo $ping_stats | awk '{print $1}')
#     ping_avg=$(echo $ping_stats | awk '{print $2}')
#     ping_max=$(echo $ping_stats | awk '{print $3}')
#     ping_mdev=$(echo $ping_stats | awk '{print $4}')

#     ping_stats=$(grep rtt ~/temp_ping.out | awk '{print $7}' | tr '/' ' ')
#     ping_ipg=$(echo $ping_stats | awk '{print $1}')
#     ping_ewma=$(echo $ping_stats | awk '{print $2}')

#     ping_units=ms

#     echo "run_uuid,timestamp,nodeid,nodeuuid,runtime,packets_sent,packets_received,packet_loss,max,min,mean,stdev,ipg,ewma,units" > ~/ping_results.csv
#     echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$ping_time,$pkts_sent,$pkts_received,$pkt_loss,$ping_max,$ping_min,$ping_avg,$ping_mdev,$ping_ipg,$ping_ewma,$ping_units" >> ~/ping_results.csv
# fi

##############
### STREAM ###
##############
# DVFS init
dvfs="yes"

# Set up make vars
stream_ntimes=500
stream_array_size=10000000
stream_offset=0
stream_type=double
stream_optimization=O2
cd ../STREAM

# make from source and run
make clean
make NTIMES=$stream_ntimes STREAM_ARRAY_SIZE=$stream_array_size OFFSET=$stream_offset STREAM_TYPE=$stream_type OPT=$stream_optimization
echo "run_uuid,timestamp,nodeid,nodeuuid,stream_ntimes,stream_array_size,stream_offset,stream_type,stream_optimization" > ~/stream_info.csv
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$stream_ntimes,$stream_array_size,$stream_offset,$stream_type,$stream_optimization" >> ~/stream_info.csv

for (( n=0; n<=$((nsockets-1)); n++ ))
do
    echo -n "Running STREAM (dvfs $dvfs, socket $n) - "
    date
    numactl -N $n ./streamc
    mv stream_out.csv ~/stream_out_socket${n}_dvfs.csv
    # Write to file
    sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/stream_out_socket${n}_dvfs.csv
    sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/stream_out_socket${n}_dvfs.csv
done

################
### membench ###
################
# Set up make vars
membench_samples=5
membench_times=5
# membench_size=1073741824LL # 1024*1024*1024, LL is required due to int overflow issues
membench_size=$(python3 -c "multiple=$nthreads * 32; list = [n for n in range(1024**3, 1024**3 + multiple) if n % multiple == 0]; print str(list[0]) + 'LL'")
membench_optimization=O3
cd ../membench

# make from source and run
make clean
make SAMPLES=$membench_samples TIMES=$membench_times SIZE=$membench_size OPT=$membench_optimization
echo "run_uuid,timestamp,nodeid,nodeuuid,membench_samples,membench_times,membench_size,membench_optimization" > ~/membench_info.csv
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$membench_samples,$membench_times,$membench_size,$membench_optimization" >> ~/membench_info.csv
for (( n=0; n<=$((nsockets-1)); n++ ))
do
    echo -n "Running membench (dvfs $dvfs, socket $n) - "
    date
    numactl -N $n ./memory_profiler
    mv memory_profiler_out.csv ~/membench_out_socket${n}_dvfs.csv
    # Write to file
    sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/membench_out_socket${n}_dvfs.csv
    sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/membench_out_socket${n}_dvfs.csv
done

#####################
### NPB CPU Tests ###
#####################
cd ../NPB-CPUTests
# Most of these tests are in fortran
sudo apt-get install gfortran -y

# ST first
cp config/make-ST.def config/make.def
cp config/suite-ST.def config/suite.def
rm -f bin/*
make clean
make suite
cd bin
for (( n=0; n<=$((nsockets-1)); n++ ))
do
    for filename in * 
    do 
        echo -n "Running NPB CPU Test $filename (dvfs $dvfs, socket $n, ST) - "
        date
        numactl -N ${n} ./$filename > ~/npb.$filename.socket${n}.dvfs.ST.out
        sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.dvfs.ST.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.dvfs.ST.csv
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/npb.$filename.socket${n}.dvfs.ST.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/npb.$filename.socket${n}.dvfs.ST.csv
    done
done
cd ..

# MT next
cp config/make-MT.def config/make.def
if [[ $(echo $total_mem | cut -d"G" -f 1) -lt 20 ]]; then
    cp config/suite-MT-lowmem.def config/suite.def
else
    cp config/suite-MT.def config/suite.def
fi
rm -f bin/*
make clean
make suite
cd bin
for (( n=0; n<=$((nsockets-1)); n++ ))
do
    for filename in * 
    do 
        echo -n "Running NPB CPU Test $filename (dvfs $dvfs, socket $n, MT) - "
        date
        numactl -N ${n} ./$filename > ~/npb.$filename.socket${n}.dvfs.MT.out
        sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.dvfs.MT.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.dvfs.MT.csv
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/npb.$filename.socket${n}.dvfs.MT.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/npb.$filename.socket${n}.dvfs.MT.csv
    done
done
cd ..


############
### DVFS ###
############
# Only works on x86_64, and for some reason doesn't currently work on Xeon Gold 6142 procs
if [ ${arch} == 'x86_64' ] && [ -z $(lscpu | grep "Model name:" | grep -o -m 1 6142 | head -1) ]; then
    # Turn DVFS stuff off, re-run memory experiments
    dvfs="no"
    sudo apt-get install msr-tools cpufrequtils -y
    sudo modprobe msr
    oldgovernor=$(sudo cpufreq-info -p | awk '{print $3}')
    for (( n=0; n<=$((nthreads-1)); n++ ))
    do
        sudo wrmsr -p$n 0x1a0 0x4000850089
        sudo cpufreq-set -c $n -g performance
    done
    
    
    # STREAM
    cd ../STREAM
    for (( n=0; n<=$((nsockets-1)); n++ ))
    do
        echo -n "Running STREAM $filename (dvfs $dvfs, socket $n) - "
        date
        numactl -N $n ./streamc
        mv stream_out.csv ~/stream_out_socket${n}_nodvfs.csv
        # Write to file
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/stream_out_socket${n}_nodvfs.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/stream_out_socket${n}_nodvfs.csv
    done
    
    # membench
    cd ../membench
    for (( n=0; n<=$((nsockets-1)); n++ ))
    do
        echo -n "Running membench (dvfs $dvfs, socket $n, ST) - "
        date
        numactl -N $n ./memory_profiler
        mv memory_profiler_out.csv ~/membench_out_socket${n}_nodvfs.csv
        # Write to file
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/membench_out_socket${n}_nodvfs.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/membench_out_socket${n}_nodvfs.csv
    done
    
    # NPB CPU ST
    cd ../NPB-CPUTests
    cp config/make-ST.def config/make.def
    cp config/suite-ST.def config/suite.def
    rm -f bin/*
    make clean
    make suite
    cd bin
    for (( n=0; n<=$((nsockets-1)); n++ ))
    do
        for filename in * 
        do 
            echo -n "Running NPB CPU Test $filename (dvfs $dvfs, socket $n, ST) - "
            date
            numactl -N ${n} ./$filename > ~/npb.$filename.socket${n}.nodvfs.ST.out
            sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.nodvfs.ST.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.nodvfs.ST.csv
            sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/npb.$filename.socket${n}.nodvfs.ST.csv
            sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/npb.$filename.socket${n}.nodvfs.ST.csv
        done
    done
    cd ..

    # NPB CPU MT
    cp config/make-MT.def config/make.def
    if [[ $(echo $total_mem | cut -d"G" -f 1) -lt 20 ]]; then
        cp config/suite-MT-lowmem.def config/suite.def
    else
        cp config/suite-MT.def config/suite.def
    fi
    rm -f bin/*
    make clean
    make suite
    cd bin
    for (( n=0; n<=$((nsockets-1)); n++ ))
    do
        for filename in * 
        do 
            echo -n "Running NPB CPU Test $filename (dvfs $dvfs, socket $n, MT) - "
            date
            numactl -N ${n} ./$filename > ~/npb.$filename.socket${n}.nodvfs.MT.out
            sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.nodvfs.MT.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.nodvfs.MT.csv
            sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/npb.$filename.socket${n}.nodvfs.MT.csv
            sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/npb.$filename.socket${n}.nodvfs.MT.csv
        done
    done
    
    # NPB CPU MT Extra EP tests
    for (( n=0; n<=$((nsockets-1)); n++ ))
    do
        for (( i=1; i<=30; i++ ))
        do 
            for filename in ft*
            do
                echo -n "Running Extra NPB CPU Test $filename (dvfs $dvfs, socket $n, MT, run $i) - "
                date
                numactl -N ${n} -m ${n} ./$filename > ~/extra-npb.$filename.socket${n}.nodvfs.MT.run${i}.out
                sed '1,/nas.nasa.gov/d' ~/extra-npb.$filename.socket${n}.nodvfs.MT.run${i}.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/extra-npb.$filename.socket${n}.nodvfs.MT.run${i}.csv
                sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs,run_num/' ~/extra-npb.$filename.socket${n}.nodvfs.MT.run${i}.csv
                sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs,$i/" ~/extra-npb.$filename.socket${n}.nodvfs.MT.run${i}.csv
            done
        done
    done
    cd ..
    
    # Change everything back to normal
    for (( n=0; n<=$((nthreads-1)); n++ ))
    do
        sudo wrmsr -p$n 0x1a0 0x850089
        sudo cpufreq-set -c $n -g $oldgovernor
    done
fi

####################
### SLANG-probed ###
####################
# If we're not at Utah or APT (r320s), don't run this.
# Mellanox ConnectX-3 or better experimental NIC is required.

if [[ ! -z $(echo ${if_hwinfo} | grep 'ConnectX') ]]; then
    echo -n "Running NIC -> NIC Network Latency Tests - "
    date
    cd ../SLANG-probed
    sudo apt-get install libxml2-dev pkg-config -y
    autoreconf -i
    ./configure
    make
    probed_version=$(./probed | head -1)
    probed_interval=1 #1 ms
    probed_count=10000

    # Run NIC -> NIC latency measurements
    sudo ./probed -c $net_server -w $probed_interval -n $probed_count -i $vlan_name -o
    if [ $? -eq 0 ]; then
        mv probed_out.csv ~/probed_out.csv
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid/' ~/probed_out.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid/" ~/probed_out.csv
    fi
    # Generate info file
    echo "run_uuid,timestamp,nodeid,nodeuuid,probed_version,probed_count,probed_source_ip,probed_dest_ip,probed_dest_nodeid,probed_interval" > ~/probed_info.csv
    echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$probed_version,$probed_count,$vlan_ip,$net_server,$dest_nodeid,$probed_interval" >> ~/probed_info.csv
fi


###########
### FIO ###
###########
cd ~
sudo apt-get install fio -y
fio_version=$(fio -v)

# Huge hardcoded FIO header, this is the worst...
fioheader="terse_version,fio_version,jobname,groupid,error,READ_kb,READ_bandwidth,READ_IOPS,READ_runtime,READ_Slat_min,READ_Slat_max,READ_Slat_mean,READ_Slat_dev,READ_Clat_max,READ_Clat_min,READ_Clat_mean,READ_Clat_dev,READ_clat_pct01,READ_clat_pct02,READ_clat_pct03,READ_clat_pct04,READ_clat_pct05,READ_clat_pct06,READ_clat_pct07,READ_clat_pct08,READ_clat_pct09,READ_clat_pct10,READ_clat_pct11,READ_clat_pct12,READ_clat_pct13,READ_clat_pct14,READ_clat_pct15,READ_clat_pct16,READ_clat_pct17,READ_clat_pct18,READ_clat_pct19,READ_clat_pct20,READ_tlat_min,READ_lat_max,READ_lat_mean,READ_lat_dev,READ_bw_min,READ_bw_max,READ_bw_agg_pct,READ_bw_mean,READ_bw_dev,WRITE_kb,WRITE_bandwidth,WRITE_IOPS,WRITE_runtime,WRITE_Slat_min,WRITE_Slat_max,WRITE_Slat_mean,WRITE_Slat_dev,WRITE_Clat_max,WRITE_Clat_min,WRITE_Clat_mean,WRITE_Clat_dev,WRITE_clat_pct01,WRITE_clat_pct02,WRITE_clat_pct03,WRITE_clat_pct04,WRITE_clat_pct05,WRITE_clat_pct06,WRITE_clat_pct07,WRITE_clat_pct08,WRITE_clat_pct09,WRITE_clat_pct10,WRITE_clat_pct11,WRITE_clat_pct12,WRITE_clat_pct13,WRITE_clat_pct14,WRITE_clat_pct15,WRITE_clat_pct16,WRITE_clat_pct17,WRITE_clat_pct18,WRITE_clat_pct19,WRITE_clat_pct20,WRITE_tlat_min,WRITE_lat_max,WRITE_lat_mean,WRITE_lat_dev,WRITE_bw_min,WRITE_bw_max,WRITE_bw_agg_pct,WRITE_bw_mean,WRITE_bw_dev,CPU_user,CPU_sys,CPU_csw,CPU_mjf,PU_minf,iodepth_1,iodepth_2,iodepth_4,iodepth_8,iodepth_16,iodepth_32,iodepth_64,lat_2us,lat_4us,lat_10us,lat_20us,lat_50us,lat_100us,lat_250us,lat_500us,lat_750us,lat_1000us,lat_2ms,lat_4ms,lat_10ms,lat_20ms,lat_50ms,lat_100ms,lat_250ms,lat_500ms,lat_750ms,lat_1000ms,lat_2000ms,lat_over_2000ms,disk_name,disk_read_iops,disk_write_iops,disk_read_merges,disk_write_merges,disk_read_ticks,write_ticks,disk_queue_time,disk_utilization,device,iod\n"

# iodepth set here, but we'll run tests both with this setting and iodepth=1
iodepth=4096
direct=1
numjobs=1
ioengine="libaio"
blocksize="4k"
size="10G"
# timeout is 12 minutes
timeout=720 

# This segment generates a list of block device targets for use in fio
testdevs=()
# Get the base raw block device names (sda, sdb, nvme0n1, etc...)
rawnames=($(sudo lsblk -d -io NAME | grep -v NAME | awk '{print $1}'))

# r320s have a hardware raid controller, don't want to use any of the other devices
if [[ ${#rawnames[@]} = 4 ]]; then
    rawnames=($(sudo lsblk -d -io NAME | grep -v NAME | awk '{print $1}' | head -1))
fi
for name in "${rawnames[@]}"
do
    # Check if base raw block device has partitions
    echo -n "Checking block device $name - "
    date
    nparts=$(sudo fdisk -l /dev/$name | grep -v Disk | grep -c $name)
    if [ ${nparts} != 0 ]; then
        # If it does, check whether any are labeled "Empty"
        testpart=$(sudo fdisk -l /dev/$name | grep Empty | tail -1 | awk '{print $1}' | sed 's@.*/@@')
        if [ -z "$testpart" ]; then
            echo -n "No test partitions, partitioning..."
            date
            # If not, assume we're on m400 where free space is not partitioned automatically
            # So we create a new partition using the free space on the disk
            # NOTE: This has been tested on all currently relevant machines in
            # Cloudlab Utah, Cloudlab Wisconsin, and Cloudlab Clemson
            # However, this assumption might not hold through future machine types 
            oldparts=($(sudo fdisk -l /dev/$name | grep -v Disk | grep $name | awk '{print $1}' | sed 's@.*/@@'))
            sudo apt-get install gdisk -y
            sudo sgdisk -n 0:0:0 /dev/$name
            sudo partprobe
            newparts=($(sudo fdisk -l /dev/$name | grep -v Disk | grep $name | awk '{print $1}' | sed 's@.*/@@'))
            testpart=$(echo ${oldparts[@]} ${newparts[@]} | tr ' ' '\n' | sort | uniq -u)
        fi
        echo -n "Using partition $testpart on $name - "
        date
        testdevs+=($testpart)
    else
        # Otherwise, if it has no partitions we can do with the disk as we please
        testdevs+=($name)
    fi
done

# Iterate again over the raw block device names to generate disk_info files
for name in "${rawnames[@]}"
do
    echo -n "Collecting information for block device $name - "
    date
    filename="disk_info_${name}.csv"
    disk_name="/dev/$name"
    disk_model=$(sudo lsblk -d -io MODEL $disk_name | grep -v MODEL | sed -e 's/[[:space:]]*$//')
    if [ -z "$disk_model" ]; then
        disk_model="N/A"
    fi
    disk_serial=$(sudo lsblk -d -io SERIAL $disk_name | grep -v SERIAL | sed -e 's/[[:space:]]*$//')
    if [ -z "$disk_serial" ]; then
        disk_serial="N/A"
    fi
    disk_size=$(sudo lsblk -d -io SIZE $disk_name | grep -v SIZE | sed -e 's/[[:space:]]*$//')
    if [ -z "$disk_size" ]; then
        disk_size="N/A"
    fi
    isrotational=$(sudo lsblk -d -io ROTA $disk_name | grep -v ROTA | sed -e 's/[[:space:]]*$//')
    if [ -z "$isrotational" ]; then
        disk_type="N/A"
    else
        if [ ${isrotational} == 1 ]; then
            disk_type="HDD"
        else
            disk_type="SSD"
        fi
    fi
    nparts=$(sudo fdisk -l $disk_name | grep -v Disk | grep -c $name)
    echo "run_uuid,timestamp,nodeid,nodeuuid,disk_name,disk_model,disk_serial,disk_size,disk_type,npartitions" > $filename
    echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$disk_name,$disk_model,$disk_serial,$disk_size,$disk_type,$nparts" >> $filename
done

# Iterate over list of devices generated above
# Run multiple fio commands targeting each
for device in "${testdevs[@]}"
do
    disk="/dev/$device"
    
    # Sequential Write
    rw="write"
    echo -n "Running fio on $disk with operation $rw and iodepth $iodepth - "
    date
    name="fio_write_seq_io${iodepth}_${device}"
    output="$name.csv"
    sudo blkdiscard $disk
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=$iodepth --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;$iodepth@" $output
    echo -n "Running fio on $disk with operation $rw and iodepth 1 - "
    date
    name="fio_write_seq_io1_${device}"
    output="$name.csv"
    sudo blkdiscard $disk
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=1 --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;1@" $output

    # Random Write
    rw="randwrite"
    echo -n "Running fio on $disk with operation $rw and iodepth $iodepth - "
    date
    name="fio_write_rand_io${iodepth}_${device}"
    output="$name.csv"
    sudo blkdiscard $disk
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=$iodepth --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;$iodepth@" $output
    echo -n "Running fio on $disk with operation $rw and iodepth 1 - "
    date
    name="fio_write_rand_io1_${device}"
    output="$name.csv"
    sudo blkdiscard $disk
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=1 --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;1@" $output

    # Sequential Read
    rw="read"
    echo -n "Running fio on $disk with operation $rw and iodepth $iodepth - "
    date
    name="fio_read_seq_io${iodepth}_${device}"
    output="$name.csv"
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=$iodepth --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;$iodepth@" $output
    echo -n "Running fio on $disk with operation $rw and iodepth 1 - "
    date
    name="fio_read_seq_io1_${device}"
    output="$name.csv"
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=1 --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;1@" $output

    # Random Read
    rw="randread"
    echo -n "Running fio on $disk with operation $rw and iodepth $iodepth - "
    date
    name="fio_read_rand_io${iodepth}_${device}"
    output="$name.csv"
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=$iodepth --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;$iodepth@" $output
    echo -n "Running fio on $disk with operation $rw and iodepth 1 - "
    date
    name="fio_read_rand_io1_${device}"
    output="$name.csv"
    sudo fio --name=$rw --filename=$disk --bs=$blocksize --size=$size --runtime=$timeout --iodepth=1 --direct=$direct --numjobs=$numjobs --ioengine=$ioengine --rw=$rw --minimal --output=$output
    sed -i "1s@\$@;$disk;1@" $output
done
output="fio_*"
sed -i 's/\;/\,/g' $output
sed -i "1s/^/$fioheader/" $output
output="fio_info.csv"
echo "run_uuid,timestamp,nodeid,nodeuuid,fio_version,fio_size,fio_iodepth,fio_direct,fio_numjobs,fio_ioengine,fio_blocksize,fio_timeout" > $output
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$fio_version,$size,$iodepth,$direct,$numjobs,$ioengine,$blocksize,$timeout" >> $output

# #########################
# ### Network Bandwidth ###
# #########################
# # Having temporary issues with the d710s and their 1GbE links.
# if [[ -z $(echo ${if_hwinfo} | grep 'NetXtreme') ]]; then
#     # iperf3 client -> server first
#     sudo apt-get install iperf3 -y
#     iperf_omit=1
#     iperf_time=60
#     if [ ! -z $(grep 'hp' /var/emulab/boot/nodeid) ]; then
#         # 25Gbps links seem to like higher buffer size
#         iperf_buff_size=1M
#     else
#         # Default buffer size
#         iperf_buff_size=128k
#     fi
#     timeout=0
#     max_timeout=660
#     skip=0

#     echo -n "Running iperf3 client -> server - "
#     date
#     until iperf3 -V -J -N -O $iperf_omit -t $iperf_time -l $iperf_buff_size -c $net_server > iperf3_normal.json
#     do
#         sleep 5
#         let "timeout+=5"
#         if [ "$timeout" -gt "$max_timeout" ]; then
#             rm iperf3_normal.json
#             skip=1
#             break
#         fi
#     done

#     # If the previous command timed out, no reason to run this segment
#     if [ "$skip" -eq 0 ]; then
#         # Probably unnecessary, but this might let other machines have a moment to sneak in
#         sleep 15

#         timeout=0
#         # iperf3 server -> client last
#         echo -n "Running iperf3 server -> client - "
#         date
#         until iperf3 -V -R -J -N -O $iperf_omit -t $iperf_time -l $iperf_buff_size -c $net_server > iperf3_reversed.json
#         do
#             sleep 5
#             let "timeout+=5"
#             if [ "$timeout" -gt "$max_timeout" ]; then
#                 rm iperf3_reversed.json
#                 break
#             fi
#         done
#     fi
# fi

# Strip extra whitespace
sed -i 's/  \+/ /g' *.csv

# Push a file to signal run is complete
echo "COMPLETED" > ~/complete/run_complete
echo "TESTS COMPLETED"