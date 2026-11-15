PYTHON ?= python3

.PHONY: help dependencies firmware simulate bitstream

help:
	@echo "make dependencies - fetch the pinned upstream Ibex sources"
	@echo "make firmware     - build the board firmware and RAM image"
	@echo "make simulate     - run the two-boot Verilator regression"
	@echo "make bitstream    - build the Arty A7-100T bitstream with Vivado"

dependencies:
	$(PYTHON) tools/fetch_ibex.py

firmware:
	$(PYTHON) tools/build_firmware.py

simulate:
	$(PYTHON) tools/build_soc.py sim

bitstream:
	$(PYTHON) tools/build_soc.py synth
