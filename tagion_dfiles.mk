BASIC_DFILES+=tagion/basic/TagionExceptions.d
BASIC_DFILES+=tagion/basic/Basic.d
BASIC_DFILES+=tagion/basic/Message.d
BASIC_DFILES:=$(addprefix $(TAGION_BASIC)/,$(BASIC_DFILES))

TAGION_DFILES+=$(BASIC_DFILES)

UTILS_DFILES+=tagion/utils/LRU.d
UTILS_DFILES+=tagion/utils/Gene.d
UTILS_DFILES+=tagion/utils/DList.d
#UTILS_DFILES+=tagion/utils/BSON.d
UTILS_DFILES+=tagion/utils/Queue.d
UTILS_DFILES+=tagion/utils/StdTime.d
UTILS_DFILES+=tagion/utils/Term.d
UTILS_DFILES+=tagion/utils/LEB128.d
UTILS_DFILES+=tagion/utils/Miscellaneous.d
UTILS_DFILES+=tagion/utils/Random.d
UTILS_DFILES:=$(addprefix $(TAGION_UTILS)/,$(UTILS_DFILES))

TAGION_DFILES+=$(UTILS_DFILES)

HIBON_DFILES+=tagion/hibon/HiBON.d
HIBON_DFILES+=tagion/hibon/Document.d
HIBON_DFILES+=tagion/hibon/HiBONBase.d
HIBON_DFILES+=tagion/hibon/HiBONJSON.d
HIBON_DFILES+=tagion/hibon/HiBONException.d
HIBON_DFILES+=tagion/hibon/HiBONRecord.d
HIBON_DFILES+=tagion/hibon/BigNumber.d
HIBON_DFILES+=tagion/hibon/HiBONtoText.d
HIBON_DFILES:=$(addprefix $(TAGION_HIBON)/,$(UTILS_DFILES))
