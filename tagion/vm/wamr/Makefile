REPOROOT?=${shell git rev-parse --show-toplevel}
DC?=ldc2
MAIN:=Wamr
UTEST:=-unittest
DFLAGS:=-I$(REPOROOT)
DFLAGS+=-I$(REPOROOT)/../tagion_basic
DFILES?=${shell find . -name "*.d" -printf "%P "}
LIBS?=$(REPOROOT)/bin/libwarm.a


$(MAIN):
	$(DC) -of$@ $(LIBS)  $(DFLAGS)  $(DFILES)
test:
	$(DC) $(DFLAGS) $(LIBS) $(MAIN:=.d) $(UTEST)
clean:
	rm -rf $(MAIN) *.o
info:
	echo $(DFILES)
	echo $(OBJS)
	echo $(LIBS)
