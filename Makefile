
all:
	echo "Not supported" >&2

empty:=
space+= ${empty} ${empty}

EXAMPLES_TOP=f4pga-examples/${FPGA_FAM}

%.example:
	git -C ${EXAMPLES_TOP}/$(basename $@) clean -xdf .
	test -n "$$F4PGA_INSTALL_DIR"
	set -eux;. ${F4PGA_INSTALL_DIR}/${FPGA_FAM}/conda/etc/profile.d/conda.sh;\
	 conda activate ${FPGA_FAM};${MAKE} -C ${EXAMPLES_TOP}/$(basename $@)

%.example_bit:
	set -eux;file="${EXAMPLES_TOP}/$(basename $@)/build/${TARGET}/top.bit";\
	 test -f $$file;du -h $$file >&2;echo $$file

litex_demo-%.example:
	set -eux;\
	 dir="$(word 1,$(subst -,${space},$(basename $@)))";\
	 cpu="$(word 2,$(subst -,${space},$(basename $@)))";\
	 cd ${EXAMPLES_TOP}/$$dir;\
	 git clean -xdf .;\
	 . ${F4PGA_INSTALL_DIR}/${FPGA_FAM}/conda/etc/profile.d/conda.sh;\
	 conda activate ${FPGA_FAM};\
	 pip install -r requirements.txt;\
	 ./src/litex/litex/boards/targets/arty.py --toolchain=symbiflow --cpu-type=$$cpu\
	  --sys-clk-freq 80e6 --output-dir build/$$cpu/${TARGET} --variant a7-35 --build

litex_demo-%.example_bit:
	set -eux;\
	 dir="$(word 1,$(subst -,${space},$(basename $@)))";\
	 cpu="$(word 2,$(subst -,${space},$(basename $@)))";\
	 file="${EXAMPLES_TOP}/$$dir/build/$$cpu/${TARGET}/gateware/arty.bit";\
	 test -f $$file;echo $$file

hello-arty-%.example:
	set -eux;\
	 demo="$(word 3,$(subst -,${space},$(basename $@)))";\
	 cd f4pga-examples/projf-makefiles/hello/hello-arty/$$demo;\
	 git clean -xdf .;\
	 . ${F4PGA_INSTALL_DIR}/${FPGA_FAM}/conda/etc/profile.d/conda.sh;\
	 conda activate ${FPGA_FAM};\
	 ${MAKE}

hello-arty-%.example_bit:
	set -eux;\
	 demo="$(word 3,$(subst -,${space},$(basename $@)))";\
	 file="f4pga-examples/projf-makefiles/hello/hello-arty/$$demo/build/${TARGET}/top.bit";\
	 test -f $$file;du -h $$file >&2;echo $$file

DEVCONTAINER_ID=devcontainer=1
devcontainer.build:
	env BUILDKIT_PROGRESS=plain devcontainer build --workspace-folder .

devcontainer.test:
	-docker rm -f $$(docker ps -aq --filter label=${DEVCONTAINER_ID})
	env BUILDKIT_PROGRESS=plain devcontainer up --id-label ${DEVCONTAINER_ID} --workspace-folder .
	devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . sh -cex '. $$F4PGA_INSTALL_DIR/$$FPGA_FAM/conda/etc/profile.d/conda.sh; command -v conda'
	devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . bash -ceux '. $$F4PGA_INSTALL_DIR/$$FPGA_FAM/conda/etc/profile.d/conda.sh; conda activate $$FPGA_FAM; command -v f4pga'
	devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make counter_test.example
	echo devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make pulse_width_led.example
	echo devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make counter_test.example
	echo devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make picosoc_demo.example
	echo devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make linux_litex_demo.example
	echo devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make timer.example TARGET=basys3
	devcontainer exec --id-label ${DEVCONTAINER_ID} --workspace-folder . make litex_demo-picorv32.example
