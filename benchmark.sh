#!/bin/bash
set -x

export DEBIAN_FRONTEND=noninteractive
timestamp=$(date -u +%s)
run_uuid=$(uuidgen)


# Collect information about the machine where the 
# benchmarks will be run using facter 
# and some other linux command line tools.
echo -n "[+] Collecting Enviroment Information" - 
date

# Check the number of threads, sockets and total memory present.
nthreads=$(nproc --all)
total_mem=$(sudo hwinfo --memory | grep "Memory Size" | awk '{print $3 $4}')
# Because ARM has to do cpuinfo so differently, hardcode for non x86_64.
nsockets=1
if [ ${arch} == 'x86_64' ]; then
    nsockets=$(cat /proc/cpuinfo | grep "physical id" | sort -n | uniq | wc -l)
fi

data=$(facter --json)

response=$(curl \
  --header "Content-Type: application/json" \
  --request "POST" \
  --data "$data" \
  "http://$HOST:$PORT/api/v1/save-machine-details")

machine_id=$(echo $response | tail -c +2 | head -c -2 | awk -F ":" {'print $2'} | tail -c +2 | head -c -2)
echo $machine_id


########################
### NBP-CPU-ST TESTS ###
########################
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
        numactl -N ${n} ./$filename > ~/npb.$filename.socket${n}.dvfs.ST.out
        sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.dvfs.ST.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.dvfs.ST.csv
    done
done
cd ..


################
### membench ###
################
# Set up make vars
membench_samples=5
membench_times=5
# membench_size=1073741824LL # 1024*1024*1024, LL is required due to int overflow issues
membench_size=$(python -c "multiple=$nthreads * 32; list = [n for n in range(1024**3, 1024**3 + multiple) if n % multiple == 0]; print str(list[0]) + 'LL'")
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


# # MT
# cp config/make-MT.def config/make.def
# if [[ $(echo $total_mem | cut -d"G" -f 1) -lt 20 ]]; then
#     cp config/suite-MT-lowmem.def config/suite.def
# else
#     cp config/suite-MT.def config/suite.def
# fi
# rm -f bin/*
# make clean
# make suite
# cd bin
# for (( n=0; n<=$((nsockets-1)); n++ ))
# do
#     for filename in * 
#     do 
#         echo -n "Running NPB CPU Test $filename (dvfs $dvfs, socket $n, MT) - "
#         date
#         numactl -N 0 ./$filename > ~/npb.$filename.socket${n}.dvfs.MT.out
#         sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.dvfs.MT.out | sed 's/ *, */,/g' | sed '/./,$!d'
#     done
# done
# cd ..


###########
### FIO ###
###########
cd ~

# check whether FIO is installed or not.
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
# Get the base raw block device names (sda, sdb, sr0, nvme0n1, etc...)
rawnames=($(sudo lsblk -d -io NAME | grep -v NAME | awk '{print $1}'))

# r320s have a hardware raid controller, don't want to use any of the other devices
if [[ ${#rawnames[@]} = 4 ]]; then
    rawnames=($(sudo lsblk -d -io NAME | grep -v NAME | awk '{print $1}' | head -1))
fi

# iterate through all the raw drives
for name in "${rawnames[@]}"
do
    # Since `/dev/sda` contains the primary boot partition
    # we don't like to create any partition on it. Otherwise
    # it may corrupt the entire system.
    if [ ${name} == "sda" ]; then
    continue
    fi

    # Check if base raw block device has partitions,
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
            sudo sgdisk -n 0:0:0 /dev/$name
            sudo partprobe
            newparts=($(sudo fdisk -l /dev/$name | grep -v Disk | grep $name | awk '{print $1}' | sed 's@.*/@@'))
            testpart=$(echo ${oldparts[@]} ${newparts[@]} | tr ' ' '\n' | sort | uniq -u)
        fi
        echo -n "Using partition $testpart on $name - "
        date
        testdevs+=($testpart)
    else
        # Otherwise, if it has no partitions we can do with the disk as we please,
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


###########################
### STREAM MEMORY TESTS ###
###########################
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


echo "Bye ! Exiting."
