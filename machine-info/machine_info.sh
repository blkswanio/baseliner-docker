#!/bin/bash 
set -e

# This module is meant to gather environment information 
# about the BIOS and Hardware of a particulat machine.


# BIOS Details 
vendor=$(sudo dmidecode --type bios | grep "Vendor" | awk '{print $2}')
version=$(sudo dmidecode --type bios | grep "Version" | awk '{print $2}')
release_date=$(sudo dmidecode --type bios | grep "Release Date" | awk '{print $3}')
rom_size=$(sudo dmidecode --type bios | grep "ROM Size" | awk {'print $3 $4'})
bios_revision=$(sudo dmidecode --type bios | grep "BIOS Revision" | awk {'print $3'})

echo $vendor
echo $version
echo $release_date
echo $rom_size
echo $bios_revision

# CPU Details
cpu_model=$(lscpu | grep "Model name:" | awk -F ":" {'print $2'})
cpu_num=$(lscpu | grep "CPU(s):" | awk -F ":" {'print $2'})
cpu_architecture=$(lscpu | grep "Architecture:" | awk -F ":" {'print $2'})
cpu_vendor=$(lscpu | grep "Vendor ID:" | awk -F ":" {'print $2'})
cpu_speed=$(lscpu | grep "CPU MHz:" | awk -F ":" {'print $2'})

echo $cpu_architecture
echo $cpu_num
echo $cpu_model
echo $cpu_vendor
echo $cpu_speed

# RAM Details
ram_size=$(lshw -C memory | grep "size" | awk -F ":" {'print $2'})
echo $ram_size