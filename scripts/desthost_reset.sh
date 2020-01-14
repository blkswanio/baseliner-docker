#!/bin/bash
  
sudo pkill -f simplehttp
sudo killall iperf3
cd ~/HTTP
nohup python "$(dirname ${BASH_SOURCE[0]})"/simplehttp.py 192.168.1.100:8000 > ~/http.log 2> ~/http_error.log &
iperf3 -s -D
if [ ! -z $(grep -E 'hp|ms|apt' /var/emulab/boot/nodeid) ]; then
        sudo killall probed
        vlan=$(sudo ifconfig | grep vlan | awk {'print $1'} | sed 's/://g')
        screen -d -m sudo ~/cloudlab-benchmarks/SLANG-probed/probed -s -i $vlan -l
fi
