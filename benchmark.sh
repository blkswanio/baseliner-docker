#!/bin/bash
set -e

###############################
### Environment Information ###
###############################
echo -n "Getting Environment Information - " 
date
export DEBIAN_FRONTEND=noninteractive
timestamp=$(date -u +%s)
run_uuid=$(uuidgen)
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

# Write the environment info to file
echo "run_uuid,timestamp,nodeid,nodeuuid,arch,gcc_ver,version_hash,total_mem,mem_clock_speed,nthreads,nsockets,cpu_model,kernel_release,os_release" > ~/env_out.csv
echo "$run_uuid,$timestamp,$nodeid,$nodeuuid,$arch,$gcc_ver,$version_hash,$total_mem,$mem_clock_speed,$nthreads,$nsockets,$cpu_model,$kernel_release,$os_release" >> ~/env_out.csv
set -e


#####################
### NBP-CPU Tests ###
#####################
cd ../NPB-CPUTests

# ST
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

# MT
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
        numactl -N 0 ./$filename > ~/npb.$filename.socket${n}.dvfs.MT.out
        sed '1,/nas.nasa.gov/d' ~/npb.$filename.socket${n}.dvfs.MT.out | sed 's/ *, */,/g' | sed '/./,$!d' > ~/npb.$filename.socket${n}.dvfs.MT.csv
        sed -i '1s/$/,run_uuid,timestamp,nodeid,nodeuuid,socket_num,dvfs/' ~/npb.$filename.socket${n}.dvfs.MT.csv
        sed -i "2s/$/,$run_uuid,$timestamp,$nodeid,$nodeuuid,$n,$dvfs/" ~/npb.$filename.socket${n}.dvfs.MT.csv
    done
done
cd ..
