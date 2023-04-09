# Devcontainer for F4GPA examples

[![F4GPA examples](https://github.com/TheCBaH/fpga_example/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/TheCBaH/fpga_example/actions/workflows/build.yml)

Devcontainer to create development environment for F4FPGA, and tested with [F4FPGA examples](https://symbiflow-examples.readthedocs.io/en/latest/building-examples.html).

## Get started
* [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=master&repo=624968379)
* run
  * `.devcontainer/with_swap.sh` to add swap (needed by fasm)
  * `make counter_test.example` build counter_test examp;e
  * `make litex_demo-picorv32.example` build picorv32 variant of the litex_demo example

## Prebuilt images
Prebuilt images for [F4FPGA examples](https://symbiflow-examples.readthedocs.io/en/latest/building-examples.html) available
in the [release](https://github.com/TheCBaH/fpga_example/releases) section.
