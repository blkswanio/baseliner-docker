FROM debian:jessie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo \
                       numactl \
                       build-essential \
                       libxml2-dev \ 
                       pkg-config \
                       gdisk \
                       ethtool \
                       git \
                       fio \
                       gfortran \
                       uuid-runtime \
                       parted \
                       hwinfo \
                       software-properties-common \
                       libssl-dev \
                       libcap-dev \
                       libidn2-0-dev \
                       nettle-dev \
                       libnuma-dev \
                       libffi-dev \
                       facter \
                       python3-pandas \
                       python3 \
                       python3-pip \
                       iperf3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p ~/complete
RUN pip3 install --upgrade pip && pip install --no-cache-dir influxdb
ADD . /
CMD ["/benchmark.sh"]
