FROM debian:jessie

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
                       iperf3 && \
    apt-get clean && \
    mkdir -p ~/complete

ADD . /
CMD ["/benchmark.sh"]
