FROM ubuntu:xenial

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get update && \
    apt-get install -y sudo \
                       numactl \
                       build-essential \
                       curl \
                       lshw \
                       libxml2-dev \ 
                       pkg-config \
                       gdisk \
                       ethtool \
                       git \
                       fio \
                       gfortran \
                       msr-tools \
                       cpufrequtils \
                       uuid-runtime \
                       gdisk \
                       parted \
                       hwinfo \
                       dmidecode \
                       software-properties-common \
                       libssl-dev \
                       libcap-dev \
                       libidn2-0-dev \
                       nettle-dev \
                       libnuma-dev \
                       libffi-dev \
                       python3 \
                       python3-pip \
                       iperf3 && \
    apt-get clean && \
    mkdir -p ~/complete
RUN apt-get install -y facter
RUN apt-get install -y python3-pandas
RUN pip3 install influxdb
ADD . /
CMD ["/benchmark.sh"]
