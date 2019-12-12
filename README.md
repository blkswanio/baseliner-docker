# Baseliner Docker 

### Building Instruction
```
git clone https://github.com/ivotron/baseliner-docker
docker build -t baseliner-docker baseliner-docker/
docker run --rm --privileged -e HOST=<server-host> -e PORT=<server-port> --name bld-container baseliner-docker
```
