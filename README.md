# Baseliner Docker 

### Building Instruction
```
git clone https://github.com/ivotron/baseliner-docker
docker build -t baseliner-docker baseliner-docker/
```

### Running Instruction
```
docker run --rm --privileged --cap-add=ALL -v /dev:/dev -v /lib/modules:/lib/modules --name baseliner-container -e BL
ACKSWAN_HOST=scruffy.soe.ucsc.edu -e BLACKSWAN_USER=root -e BLACKSWAN_PASSWD=root -e BLACKSWAN_DB=blackswan_dev baseliner-docker
```

If you want to set up a cron job to run the benchmarks every hour, you can,
```
crontab -e
```
And, copy-paste this line
```
0 * * * * /usr/bin/docker run --rm --privileged --cap-add=ALL -v /dev:/dev -v /lib/modules:/lib/modules --name baseliner-container -e BL
ACKSWAN_HOST=scruffy.soe.ucsc.edu -e BLACKSWAN_USER=root -e BLACKSWAN_PASSWD=root -e BLACKSWAN_DB=blackswan_dev baseliner-docker
```
