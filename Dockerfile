FROM debian:jessie

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get update && \
    apt-get install -y sudo \
                       numactl \
                       build-essential \
                       curl \
                       lshw \
                       ethtool \
                       git \
                       fio \
                       msr-tools \
                       cpufrequtils \
                       uuid-runtime \
                       hwinfo \
                       dmidecode \
                       software-properties-common \
                       libssl-dev \
                       libffi-dev \
                       python3 \
                       iperf3 && \
    apt-get clean && \
    mkdir -p ~/complete

ADD . /
CMD ["/run_benchmarks.sh"]
