dodi: $(IWASM_DIFILES)
#	echo $(IWASM_DIFILES)

vpath %.h ${IWASM_INC_1} ${IWASM_INC_2}

$(IWASM_DI_ROOT)/%.di: %.h makeway
	dstep $< -o $@ $(IWASM_FLAGS)

# dstep:
# 	@echo IWASM_DIFILES=$(IWASM_DIFILES)
# 	@echo IWASM_HFILES=$(IWASM_HFILES)
# 	@echo IWASM_FLAGS=$(IWASM_FLAGS)

CLEANER+=clean-dstep

clean-dstep:
	rm -f $(IWASM_DIFILES)
