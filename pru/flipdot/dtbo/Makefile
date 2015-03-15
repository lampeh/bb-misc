all: pru-flipdot-01-00A0.dtbo

clean:
	rm -f *.dtbo

install:
	install *.dtbo /lib/firmware

%.dtbo: %.dts
	dtc -O dtb -@ -o $@ $<

.PHONY: clean all
