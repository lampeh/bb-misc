PASM?=pasm

# -Wa,-adhlmns=$(<:.c=.lst)
CFLAGS+= -std=gnu99 -g -Wall -O3 -mcpu=cortex-a8 -march=armv7-a
LDFLAGS+= -lprussdrv
PFLAGS+= -I/usr/include -V3 -c -l

all: loader test

clean:
	rm -f test loader pru_code_bin.h *.o *.lst

loader: pru_code_bin.h

%_bin.h: %.p
	$(PASM) $(PFLAGS) $<

.PHONY: clean all
