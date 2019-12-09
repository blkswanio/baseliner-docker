#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive
timestamp=$(date -u +%s)
run_uuid=$(uuidgen)
gcc_ver=$(gcc --version | grep gcc | awk '{print $4}')


# HW info, no PCI bus on ARM means lshw doesn't have as much information
# Collect information about hardware, architecturem, BIOS, OS.
# All the collected data will be stored in the machine collection in
# database.
echo -n "[+] Collecting Enviroment Information" - 
date

nthreads=$(nproc --all)
total_mem=$(sudo hwinfo --memory | grep "Memory Size" | awk '{print $3 $4}')
cpu_arch=$(uname -m)
cpu_speed=$(lscpu | grep "CPU MHz:" | awk -F ":" {'print $2'})
cpu_vendor=$(lscpu | grep "Vendor ID:" | awk -F ":" {'print $2'} | xargs)
cpu_cores=$(lscpu | grep "CPU(s):" | awk -F ":" {'print $2'} | xargs)
kernel_release=$(uname -r)
os_release=$(. /etc/os-release; echo "Ubuntu" ${VERSION/*, /})
bios_vendor=$(sudo dmidecode --type bios | grep "Vendor" | awk '{print $2}')
bios_version=$(sudo dmidecode --type bios | grep "Version" | awk '{print $2}')
bios_rom_size=$(sudo dmidecode --type bios | grep "ROM Size" | awk {'print $3 $4'})

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

# Prepare data for storing Machine Details in Server
data='{ 
        "machine_name": "'$MACHINE_NAME'"
        "timestamp": "'${timestamp}'"
        "cpu_model": "'${cpu_model}'", 
        "cpu_arch": "'${cpu_arch}'", 
        "cpu_vendor": "'${cpu_vendor}'", 
        "cpu_cores": "'${cpu_cores}'",
        "bios_rom_size": "'${bios_rom_size}'", 
        "bios_version": "'${bios_version}'", 
        "bios_vendor": "'${bios_vendor}'",
        "memory_size": "'${total_mem}'", 
        "kernel_release": "'${kernel_release}'"
    }'

echo $data

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

python3 make_json.py $machine_id


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
