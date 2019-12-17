# Baseliner Docker 

### Building Instruction
```
git clone https://github.com/ivotron/baseliner-docker
docker build -t baseliner-docker baseliner-docker/
docker run --rm --privileged -e HOST=<server-host> -e PORT=<server-port> --name bld-container baseliner-docker
```

### Example
```
docker run --rm --privileged -e HOST=scruffy.soe.ucsc.edu -e PORT=5000 --name bld-container baseliner-docker
```
