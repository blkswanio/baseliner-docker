Benchmarks for CloudLab Nodes
===========

This repository contains a script to run various benchmarks on CloudLab machines 
to generate performance metrics as well as the sources of some of these benchmarks.

Work was done across repositories, so for more complete commit histories beyond 
what is present here, please see:

- https://gitlab.flux.utah.edu/amaricq/STREAM-modified
- https://gitlab.flux.utah.edu/amaricq/awreece-memory-bandwidth
- https://gitlab.flux.utah.edu/amaricq/iputils-ns
- https://gitlab.flux.utah.edu/amaricq/SLANG-probed


The structure of the repository is the following:

- `STREAM/`. John McCalpin's STREAM benchmark with some minor modifications.
  See the `STREAM/README` file for more details.
- `membench/`. Memory tests originally implemented by Alex W. Reece whose goal
  is to achieve maximum peak throughput. See the `membench/README.md` file
  for more details.
- `iputils-ns/`. Standard iputils ping modified to use nanosecond timing.
- `SLANG-probed/`. Latency measurement tool that uses NIC HW timestamping 
  functionality.
- `run_benchmarks.sh`. The main script that is executed on each node.