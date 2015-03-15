PASM?=pasm

# -Wa,-adhlmns=$(<:.c=.lst)
CFLAGS+= -std=gnu99 -g -Wall -O3 -mcpu=cortex-a8 -march=armv7-a
LDFLAGS+= -lprussdrv
PFLAGS+= -I/usr/include -V3 -c -l

all: loader test

clean:
	rm -f test loader pru_code_bin.h *.o *.lst

loader.o: pru_code_bin.h

%_bin.h: %.p
	$(PASM) $(PFLAGS) $<

#%.h: %.ph
#	echo "#include <stdint.h>" >$@
#	sed -e 's/\.struct\(.*\)/typedef struct\1 {/;s/\.u\([0-9]*\)\(.*\)/uint\1_t\2/;s/\.ends/};/' $< >>$@

.PHONY: clean all
