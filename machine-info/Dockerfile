FROM debian:jessie

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get update && \
    apt-get install -y sudo \
                       build-essential \
                       hwinfo \
                       lshw \
                       dmidecode \
                       software-properties-common && \
    apt-get clean

VOLUME [ "/dev/mem:/dev/mem" ]
ADD . /
CMD ["/machine_info.sh"]
