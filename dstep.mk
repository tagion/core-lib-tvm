dodi: $(WAMR_DIFILES)
#	echo $(WAMR_DIFILES)

vpath %.h ${WAMR_INC}

$(WAMR_DI_ROOT)/%.di: %.h makeway
	dstep $(DSTEP_FLAGS) $< -o $@ $(WAMR_FLAGS)
	$(DSTEP_CORRECT) $@
	$(DSTEP_CORRECT_2) $@

CLEANER+=clean-dstep

clean-dstep:
	rm -f $(WAMR_DIFILES)

info-dstep:
	@echo $(WAMR_DIFILES)
