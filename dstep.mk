dodi: $(IWASM_DIFILES)
#	echo $(IWASM_DIFILES)

vpath %.h ${IWASM_INC}

$(IWASM_DI_ROOT)/%.di: %.h makeway
	dstep $< -o $@ $(IWASM_FLAGS)
	$(DSTEP_CORRECT) $@
	$(DSTEP_CORRECT_2) $@

# dstep:
# 	@echo IWASM_DIFILES=$(IWASM_DIFILES)
# 	@echo IWASM_HFILES=$(IWASM_HFILES)
# 	@echo IWASM_FLAGS=$(IWASM_FLAGS)

CLEANER+=clean-dstep

clean-dstep:
	rm -f $(IWASM_DIFILES)
