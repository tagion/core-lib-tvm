dodi: $(WAVM_DIFILES)
	echo $(WAVM_DIFILES)

$(WAVM_DI_ROOT)/%.di: ${WAVM_INC}/%.h makeway
	dstep $< -o $@ --package $(WAVM_PACKAGE)
	${WAVMa2p} $@

dstep:
	echo $(WAVM_DIFILES)
	echo $(WAVM_HFILES)
	echo $(WAVM_INC)
