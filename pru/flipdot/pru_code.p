#include <pruss_intc_mapping.h>

#include "pru_code.ph"

.assign global_s, r0, r17, global
.assign config_s, r26, r29, config

.enter dithering_scope
.assign dithering_s, r21, r25, dithering
.leave dithering_scope

.enter diff_scope
.assign diff_s, r22, r25, diff
.leave diff_scope

.setcallreg  global.jal2
.origin 0

start:
	// clear all outputs
	mov		r30.w0, 0

	// clear registers r0-r29
	zero	&r0, (30*4)

	// set r1 to 0xFFFFFFFF
	fill	&global.ones, 4

	// shut down ECAP clock
	mov		global.tmpaddr0, 12
	call	shutdown_clock

	// shut down IEP clock
	mov		global.tmpaddr0, 15
	call	shutdown_clock

	// shut down UART clock
//	mov		global.tmpaddr0, 9
//	call	shutdown_clock

/*
	// r30[13:8] GPIO output pins occupied by eMMC interface
	// pin_mux_sel[1] = 1: map r30[13:8] to r30[5:0] on PRU1
	lbco	&global.tmpdata0, c4, 0x40, 4
	set		global.tmpdata0, global.tmpdata0, 1
	sbco	&global.tmpdata0, c4, 0x40, 4
*/

	// enable OCP master port in SYSCFG register
	// required for shared RAM access
	lbco	&global.tmpdata0, c4, 0x04, 4
	clr		global.tmpdata0, global.tmpdata0, 4
	sbco	&global.tmpdata0, c4, 0x04, 4

/*
	// set CTPPR0[15:0] to 0x0100
	// sets constant c28 to shared RAM base address 0x010000
	mov		global.tmpaddr0, 0x22028
	mov		global.tmpdata0.w0, 0x0100
	sbbo	&global.tmpdata0.w0, global.tmpaddr0, 0, 2
*/

	// set CTPPR0[15:0] to 0x0000
	// sets constant c28 to local RAM base address 0x000000
	mov		global.tmpaddr0, 0x22028
	mov		global.tmpdata0.w0, 0x0000
	sbbo	&global.tmpdata0.w0, global.tmpaddr0, 0, 2

/*
	// DEBUG: enable cycle counter in CONTROL register
	mov		global.tmpaddr0, 0x22000
	lbbo	&global.tmpdata0, global.tmpaddr0, 0, 4
	set		global.tmpdata0, global.tmpdata0, 3
	sbbo	&global.tmpdata0, global.tmpaddr0, 0, 4
*/

	// enable wakeup by interrupt 0 (PRU0)
	mov		global.tmpaddr0, 0x22008
	mov		global.tmpdata0, (1<<30)
	sbbo	&global.tmpdata0, global.tmpaddr0, 0, 4

main_loop:
	// wait for interrupt
	slp		1

	// TODO: check which interrupt actually triggered
	// ARM_PRU0_INTERRUPT or PRU1_PRU0_INTERRUPT

	// DEBUG: counter
	add		global.dbg_count0, global.dbg_count0, 1

	// load config
	lbco	&config, c28, 0, SIZE(config)
	qbne	version_mismatch, config.version, CONFIG_VERSION

	// TODO: support other formats
	qbne	version_mismatch, config.bytes_per_pixel, 1

	// width/height must be > 0
	qbge	version_mismatch, config.width, 0
	qbge	version_mismatch, config.height, 0

	// width/height limited to 8bit
	qblt	version_mismatch, config.width, 255
	qblt	version_mismatch, config.height, 255

	mov		global.jal0, resize_ok
	qbne	resize_mem, global.width, config.width
	qbne	resize_mem, global.height, config.height

resize_ok:
	// TODO: check flags
	qbbs	clear, config.flags, FLAGS_CLEAR_BIT

.using dithering_scope
	mov		dithering.y, 0

	// fill current line errors array with 0x0000
	mov		global.bbo_count0, 2
	mov		global.arg0, global.width
	mov		global.arg1, global.ditherptr0
	call	clear_array

	mov		global.frameptr, 0
	mov		global.dataptr, 0

dither_loop_y:
	add		global.tmpdata1, dithering.y, 1

	zero	&dithering, SIZE(dithering)
	mov		dithering.y, global.tmpdata1

	// fill next line errors array with 0x0000
	mov		global.bbo_count0, 2
	mov		global.arg0, global.width
	mov		global.arg1, global.ditherptr1
	call	clear_array

dither_loop_x:
	// load pixel
	lbbo	&dithering.input, config.dataptr, global.dataptr, 1
	add		global.dataptr, global.dataptr, 1

	// load downward error
	lsl		global.tmpaddr0, dithering.x, 1
	lbbo	&global.tmpdata1, global.ditherptr0, global.tmpaddr0, 2

	// add errors to pixel value
	add		global.tmpdata1, global.tmpdata1, dithering.forward1
	add		global.tmpdata1, global.tmpdata1, dithering.input

	// overwrite with input if dither flag unset
	// TODO: skip error distribution
	qbbs	dither_clamp, config.flags, FLAGS_DITHER_BIT
	mov		global.tmpdata1, dithering.input

dither_clamp:
	// clamp value to 0-255
	min		global.tmpdata1, global.tmpdata1, 255
	max		global.tmpdata1, global.tmpdata1, 0

	qble	dither_white, global.tmpdata1, config.threshold

	// config.threshold > pixel: black, error = pixel value
	clr		dithering.bitmap, dithering.bit
	clr		global.flags, FLAGS_INV_BIT
	qba		dither_pixels

dither_white:
	// config.threshold <= pixel: white, error = pixel value - 255
	set		dithering.bitmap, dithering.bit
	// use absolute value for bit shifts, negate later
	rsb		global.tmpdata1, global.tmpdata1, 255
	set		global.flags, FLAGS_INV_BIT

dither_pixels:
	// store pixels in bitmap
	add		dithering.bit, dithering.bit, 1
	qbgt	dither_errors, dithering.bit, 32
	call	dither_store

dither_errors:
/*
	// Sierra Lite filter
	lsr		dithering.error1, global.tmpdata1, 1 // 2/4 = 1/2
	lsr		dithering.error2, global.tmpdata1, 2 // 1/4
*/

	// Burkes filter
	lsr		dithering.error1, global.tmpdata1, 2 // 8/32 = 1/4
	lsr		dithering.error2, global.tmpdata1, 3 // 4/32 = 1/8
	lsr		dithering.error3, global.tmpdata1, 4 // 2/32 = 1/16

	// negate error values after bit shift
	qbbc	dither_distribute, global.flags, FLAGS_INV_BIT
	rsb		dithering.error1, dithering.error1, 0
	rsb		dithering.error2, dithering.error2, 0
	rsb		dithering.error3, dithering.error3, 0

dither_distribute:
	// x+1, y
	add		dithering.forward1, dithering.forward2, dithering.error1

	// x+2, y
	mov		dithering.forward2, dithering.error2

	// last line
	qble	dither_next_x, dithering.y, global.height

	// x, y+1
	lsl		global.tmpaddr0, dithering.x, 1
	lbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2
	add		global.tmpdata1, global.tmpdata1, dithering.error1
//	add		global.tmpdata1, global.tmpdata1, dithering.error2
	sbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2

//qba dither_backward

	// x+1, y+1
	add		global.tmpaddr0, dithering.x, 1
	qble	dither_backward, global.tmpaddr0, global.width

	lsl		global.tmpaddr0, global.tmpaddr0, 1
	lbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2
	add		global.tmpdata1, global.tmpdata1, dithering.error2
	sbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2

	// x+2, y+1
	add		global.tmpaddr0, dithering.x, 2
	qble	dither_backward, global.tmpaddr0, global.width

	lsl		global.tmpaddr0, global.tmpaddr0, 1
	lbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2
	add		global.tmpdata1, global.tmpdata1, dithering.error3
	sbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2

dither_backward:
	// x-1, y+1
	sub		global.tmpaddr0, dithering.x, 1
	qbgt	dither_next_x, global.tmpaddr0, 0

	lsl		global.tmpaddr0, global.tmpaddr0, 1
	lbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2
	add		global.tmpdata1, global.tmpdata1, dithering.error2
	sbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2

//qba dither_next_x

	// x-2, y+1
	sub		global.tmpaddr0, dithering.x, 2
	qbgt	dither_next_x, global.tmpaddr0, 0

	lsl		global.tmpaddr0, global.tmpaddr0, 1
	lbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2
	add		global.tmpdata1, global.tmpdata1, dithering.error3
	sbbo	&global.tmpdata1, global.ditherptr1, global.tmpaddr0, 2

dither_next_x:
	add		dithering.x, dithering.x, 1
	qbgt	dither_loop_x, dithering.x, global.width

	// swap error arrays for current/next line
	mov		global.tmpaddr0, global.ditherptr1
	mov		global.ditherptr1, global.ditherptr0
	mov		global.ditherptr0, global.tmpaddr0

	// store remaining pixels in bitmap
	qbeq	dither_next_y, dithering.bit, 0
	call	dither_store

dither_next_y:
	qbgt	dither_loop_y, dithering.y, global.height
.leave dithering_scope

	// frameptr0 now contains the new dithered bitmap
mov config.dataptr, global.frameptr0
mov config.data_size, global.frameptr

.using diff_scope
	zero	&diff, SIZE(diff)
/*
	// store col GPIOs in scratch pad
	mov		global.gpio_clk, GPIO_COL_CLK_BIT
	mov		global.gpio_data, GPIO_COL_DATA_BIT
	mov		global.gpio_strobe, GPIO_COL_STROBE_BIT
	xout	SCRATCH_BANK0, &global.gpio_clk, 3
*/

	mov		global.gpio_clk, GPIO_ROW_CLK_BIT
	mov		global.gpio_data, GPIO_ROW_DATA_BIT
	mov		global.gpio_strobe, GPIO_ROW_STROBE_BIT

	mov		global.frameptr, 0

	add		global.tmpdata1, global.width, 7
	lsr		diff.x, global.tmpdata1, 3

	mov		global.data, 1

diff_loop_y:
	// advance row register
	mov		global.shift_count, 1
	jal		global.jal0, shiftbits

	mov		global.dataptr, 0
	and		global.flags, global.flags, (~(FLAGS_ROW0 | FLAGS_ROW1) & 0xFF)

	loop	diff_last_x, diff.x

	lbbo	&diff.input0.b0, global.frameptr0, global.frameptr, 1
	lbbo	&diff.input1.b0, global.frameptr1, global.frameptr, 1

	// cols_to_0[col] = ~((old) & ~(new));
	not		global.tmpdata0.b0, diff.input0.b0
	and		diff.diff_bits.b0, diff.input1.b0, global.tmpdata0.b0
	not		diff.diff_bits.b0, diff.diff_bits.b0
	qbeq	diff_x_store0, diff.diff_bits.b0, 0xFF
	set		global.flags, FLAGS_ROW0_BIT

diff_x_store0:
	sbbo	&diff.diff_bits.b0, global.dataptr0, global.dataptr, 1

	// cols_to_1[col] = (~(old) & (new));
	not		global.tmpdata0.b0, diff.input1.b0
	and		diff.diff_bits.b0, diff.input0.b0, global.tmpdata0.b0
	qbeq	diff_x_store1, diff.diff_bits.b0, 0x00
	set		global.flags, FLAGS_ROW1_BIT

diff_x_store1:
	sbbo	&diff.diff_bits.b0, global.dataptr1, global.dataptr, 1

	add		global.frameptr, global.frameptr, 1
	add		global.dataptr, global.dataptr, 1

diff_last_x:
	// dataptr0/1 now contain the difference pattern for this line

	and		global.tmpdata0, global.flags, ((FLAGS_ROW0 | FLAGS_ROW1) & 0xFF)
	qbeq	diff_next_y, global.tmpdata0, 0

	// load col register GPIOs
//	xchg	SCRATCH_BANK0, &global.gpio_clk, 3
	mov		global.gpio_clk, GPIO_COL_CLK_BIT
	mov		global.gpio_data, GPIO_COL_DATA_BIT
	mov		global.gpio_strobe, GPIO_COL_STROBE_BIT

	qbbc	diff_to_1, global.flags, FLAGS_ROW0_BIT
	mov		global.arg1, global.dataptr0
	mov		global.arg0, global.width
	call	shift_from_ram

	mov		global.gpio_oe, GPIO_OE0_BIT
	jal		global.jal0, oe

diff_to_1:
	qbbc	diff_reload_gpio, global.flags, FLAGS_ROW1_BIT
	mov		global.arg1, global.dataptr1
	mov		global.arg0, global.width
	call	shift_from_ram

	mov		global.gpio_oe, GPIO_OE1_BIT
	jal		global.jal0, oe
diff_reload_gpio:
	// load row register GPIOs
//	xchg	SCRATCH_BANK0, &global.gpio_clk, 3
	mov		global.gpio_clk, GPIO_ROW_CLK_BIT
	mov		global.gpio_data, GPIO_ROW_DATA_BIT
	mov		global.gpio_strobe, GPIO_ROW_STROBE_BIT

diff_next_y:
	mov		global.data, 0
	add		diff.y, diff.y, 1
	qbgt	diff_loop_y, diff.y, global.height

	// exchange new/old frame buffers
	mov		global.tmpaddr0, global.frameptr0
	mov		global.frameptr0, global.frameptr1
	mov		global.frameptr1, global.tmpaddr0

.leave diff_scope

	sbco	&config, c28, 0, SIZE(config)
	qba		last

.using dithering_scope
dither_store:
	// round dithering.bit-1 to full bytes
	add		global.bbo_count0, dithering.bit, 6
	lsr		global.bbo_count0, global.bbo_count0, 3
	qbge	dither_store_end, global.bbo_count0, 0
	sbbo	&dithering.bitmap, global.frameptr0, global.frameptr, b0
	add		global.frameptr, global.frameptr, global.bbo_count0
dither_store_end:
	mov		dithering.bit, 0
	mov		dithering.bitmap, 0
	ret
.leave dithering_scope

clear:
	// xin/xout/xchg might use register offset in r0.b0
	mov		global.bbo_count0, 0

mov r0.w0, 0

	// store col GPIOs in scratch pad
	mov		global.gpio_clk, GPIO_COL_CLK_BIT
	mov		global.gpio_data, GPIO_COL_DATA_BIT
	mov		global.gpio_strobe, GPIO_COL_STROBE_BIT
	xout	SCRATCH_BANK0, &global.gpio_clk, 3

	mov		global.gpio_clk, GPIO_ROW_CLK_BIT
	mov		global.gpio_data, GPIO_ROW_DATA_BIT
	mov		global.gpio_strobe, GPIO_ROW_STROBE_BIT

	// clear row register
	mov		global.data, 0
	mov		global.arg0, global.height
	call	shift_constant

	// set first bit
	mov		global.data, 1

	// loop counter
	mov		global.dataptr, global.height
	qbeq	clear_loop_end, global.dataptr, 0

clear_loop:
	// advance row register
	mov		global.shift_count, 1
	jal		global.jal0, shiftbits
//	jal		global.jal0, strobe

	// load col register GPIOs
//	xchg	SCRATCH_BANK0, &global.gpio_clk, 3
	mov		global.gpio_clk, GPIO_COL_CLK_BIT
	mov		global.gpio_data, GPIO_COL_DATA_BIT
	mov		global.gpio_strobe, GPIO_COL_STROBE_BIT

	// flip row to black
	mov		global.data, global.ones
	mov		global.arg0, global.width
	call	shift_constant

	mov		global.gpio_oe, GPIO_OE1_BIT
	jal		global.jal0, oe

	// flip row to white
	mov		global.data, 0
	mov		global.arg0, global.width
	call	shift_constant

	mov		global.gpio_oe, GPIO_OE0_BIT
	jal		global.jal0, oe

	// load row register GPIOs
//	xchg	SCRATCH_BANK0, &global.gpio_clk, 3
	mov		global.gpio_clk, GPIO_ROW_CLK_BIT
	mov		global.gpio_data, GPIO_ROW_DATA_BIT
	mov		global.gpio_strobe, GPIO_ROW_STROBE_BIT

	mov		global.data, 0

	sub		global.dataptr, global.dataptr, 1
	qbne	clear_loop, global.dataptr, 0

clear_loop_end:
	qba		last

version_mismatch:
	mov		config.error, ERROR_VERSION
	qba		return_error

oom:
	mov		config.error, ERROR_MEM
	qba		return_error

return_error:
	or		config.flags, config.flags, FLAGS_ERROR
	sbco	&config, c28, 0, SIZE(config)
	qba		last

last:
	// clear all outputs
	mov		r30.w0, 0

	// clear interrupt through SICR register
	mov		global.tmpdata0, ARM_PRU0_INTERRUPT
	sbco	&global.tmpdata0, c0, 0x24, 4

	// send event to CPU
	mov		r31.b0, PRU0_ARM_INTERRUPT+16

	// go back to sleep
	qba		main_loop

exit:
	// clear all outputs
	mov		r30.w0, 0

	// DEBUG: return control register contents
	mov		global.tmpaddr0, 0x22000
	lbbo	&r0, global.tmpaddr0, 0, 20
	sbco	&r0, c28, 0, 20

	// send event to CPU and halt
	mov		r31.b0, PRU0_ARM_INTERRUPT+16
	halt

shutdown_clock:
	// set request bit
	lbco	&global.tmpdata0, c4, 0x10, 4
	set		global.tmpdata0, global.tmpdata0, global.tmpaddr0
	sbco	&global.tmpdata0, c4, 0x10, 4
	add		global.tmpaddr0, global.tmpaddr0, 1

shutdown_clock_wait:
	// wait for ACK bit
	// TODO: add timeout
	lbco	&global.tmpdata0, c4, 0x10, 4
	qbbc	shutdown_clock_wait, global.tmpdata0, global.tmpaddr0
	add		global.tmpaddr0, global.tmpaddr0, 1

	// clear clock bit
	clr		global.tmpdata0, global.tmpdata0, global.tmpaddr0
	sbco	&global.tmpdata0, c4, 0x10, 4
	ret

clear_array:
	// global.bbo_count0: word size
	// global.arg0: words
	// global.arg1: ptr
	mov		global.tmpdata0, 0
	mov		global.tmpaddr0, 0
clear_array_loop:
	min		global.tmpdata1, global.arg0, 255
	loop	clear_array_loop_end, global.tmpdata1
	sbbo	&global.tmpdata0, global.arg1, global.tmpaddr0, b0
	add		global.tmpaddr0, global.tmpaddr0, global.bbo_count0
clear_array_loop_end:
	sub		global.arg0, global.arg0, global.tmpdata1
	qblt	clear_array_loop, global.arg0, 0
	ret

shift_constant:
	// % 32
	and		global.shift_count, global.arg0, 31
	qbeq	shift_constant_div32, global.shift_count, 0
	jal		global.jal0, shiftbits

shift_constant_div32:
	// / 32
	lsr		global.tmpdata1, global.arg0, 5
	qbeq	shift_constant_end, global.tmpdata1, 0
	mov		global.shift_count, 32

shift_constant_32:
	jal		global.jal0, shiftbits
	sub		global.tmpdata1, global.tmpdata1, 1
	qbne	shift_constant_32, global.tmpdata1, 0

shift_constant_end:
	jal		global.jal0, strobe
	ret

shift_from_ram:
	add		global.tmpdata1, global.arg0, 7
	lsr		global.tmpdata1, global.tmpdata1, 3

	add		global.tmpaddr0, global.arg1, global.tmpdata1

	// last byte
	and		global.bbo_count0, global.tmpdata1, 1
	qbeq	shift_from_ram_div16, global.bbo_count0, 0

	sub		global.tmpaddr0, global.tmpaddr0, 1

	lbbo	&global.data, global.tmpaddr0, 0, 1
// XXX: think again
	and		global.shift_count, global.arg0, 7
	jal		global.jal0, shiftbits

shift_from_ram_div16:
	lsr		global.tmpdata1, global.tmpdata1, 1
	qbeq	shift_from_ram_end, global.tmpdata1, 0

	mov		global.shift_count, 16

shift_from_ram_loop16:
	sub		global.tmpaddr0, global.tmpaddr0, 2
	lbbo	&global.data, global.tmpaddr0, 0, 2
	jal		global.jal0, shiftbits

	sub		global.tmpdata1, global.tmpdata1, 1
	qblt	shift_from_ram_loop16, global.tmpdata1, 0

shift_from_ram_end:
	jal		global.jal0, strobe
	ret

shiftbits:
//	qbge	shiftbits_loop_end, global.shift_count, 0
//	qblt	shiftbits_loop_end, global.shift_count, 32

	// bit number
	sub		global.tmpdata0.b0, global.shift_count, 1

	loop	shiftbits_loop_end, global.shift_count
	qbbs	shiftbits_set, global.data, global.tmpdata0.b0

shiftbits_clr:
	clr		r30, global.gpio_data
	qba		shiftbits_clock

shiftbits_clock:
	set		r30, global.gpio_clk
	sub		global.tmpdata0.b0, global.tmpdata0.b0, 1
	// balance duty cycle with NOPs
	nop
	nop

/*
	nop
	nop
	nop
	nop
*/
	clr		r30, global.gpio_clk
/*
	nop
	nop
	nop
	nop
*/

shiftbits_loop_end:
	jmp		global.jal0

shiftbits_set:
	set		r30, global.gpio_data
	qba		shiftbits_clock

strobe:
	mov		global.arg1, DELAY_STROBE
	set		r30, global.gpio_strobe
	jal		global.jal1, delay_loop
	clr		r30, global.gpio_strobe
	jmp		global.jal0

oe:
	mov		global.arg1, DELAY_OE
	set		r30, global.gpio_oe
	jal		global.jal1, delay_loop
	clr		r30, global.gpio_oe
	jmp		global.jal0

resize_mem:
	mov		global.tmpaddr0, (PRU_MEM_BASE + PRU_MEM_SIZE)

	// width*16bit
//	lsl		global.tmpdata0, config.width, 1
// TODO: dither function writes too many elements?
add global.tmpdata0, config.width, 2
lsl global.tmpdata0, global.tmpdata0, 1

	// ditherptr1: width*16bit forward error array (next line)
	sub		global.tmpaddr0, global.tmpaddr0, global.tmpdata0
	qbgt	oom, global.tmpaddr0, PRU_MEM_BASE
	mov		global.ditherptr1, global.tmpaddr0

	// ditherptr0: width*16bit forward error array (current line)
	sub		global.tmpaddr0, global.tmpaddr0, global.tmpdata0
	qbgt	oom, global.tmpaddr0, PRU_MEM_BASE
	mov		global.ditherptr0, global.tmpaddr0

	// round width*1bit to full bytes
	add		global.tmpdata0, config.width, 7
	lsr		global.tmpdata0, global.tmpdata0, 3

	// dataptr1: width*1bit black pixel bitmap
	sub		global.tmpaddr0, global.tmpaddr0, global.tmpdata0
	qbgt	oom, global.tmpaddr0, PRU_MEM_BASE
	mov		global.dataptr1, global.tmpaddr0

	// dataptr0: width*1bit white pixel bitmap
	sub		global.tmpaddr0, global.tmpaddr0, global.tmpdata0
	qbgt	oom, global.tmpaddr0, PRU_MEM_BASE
	mov		global.dataptr0, global.tmpaddr0

	// no OOM if dataptr >= PRU_MEM
	mov		global.tmpdata0, (PRU_MEM_BASE + PRU_MEM_SIZE)
	qble	resize_frameptr, config.dataptr, global.tmpdata0

	// OOM if dataptr+data_size > dataptr0
	add		global.tmpdata0, config.dataptr, config.data_size
	qbgt	oom, global.tmpaddr0, global.tmpdata0

resize_frameptr:
	// round width*1bit to full bytes
	add		global.tmpaddr0, config.width, 7
	lsr		global.tmpaddr0, global.tmpaddr0, 3
	mov		global.tmpdata0, 0

	// multiply by config.height
	loop	resize_mul_end, config.height
	add		global.tmpdata0, global.tmpdata0, global.tmpaddr0

resize_mul_end:
	mov		global.dataptr, global.tmpdata0

	// place frame arrays into shared RAM
	mov		global.data, SHARED_MEM_BASE
	mov		global.tmpaddr0, (SHARED_MEM_BASE + SHARED_MEM_SIZE)
	mov		global.tmpdata1, 0

	qbge	resize_clear_frame1_end, global.tmpdata0, 0

	// frameptr1: width*height*1bit bitmap (last frame)
resize_clear_frame1:
	sub		global.tmpaddr0, global.tmpaddr0, 1
	qbgt	oom, global.tmpaddr0, global.data
	sbbo	&global.tmpdata1, global.tmpaddr0, 0, 1

	sub		global.tmpdata0, global.tmpdata0, 1
	qblt	resize_clear_frame1, global.tmpdata0, 0
resize_clear_frame1_end:
	mov		global.frameptr1, global.tmpaddr0

	mov		global.tmpdata0, global.dataptr

	// frameptr0: width*height*1bit bitmap (new frame)
resize_clear_frame0:
	sub		global.tmpaddr0, global.tmpaddr0, 1
	qbgt	oom, global.tmpaddr0, global.data
	sbbo	&global.tmpdata1, global.tmpaddr0, 0, 1

	sub		global.tmpdata0, global.tmpdata0, 1
	qblt	resize_clear_frame0, global.tmpdata0, 0
resize_clear_frame0_end:
	mov		global.frameptr0, global.tmpaddr0

	// OOM if dataptr+data_size > frameptr0
	add		global.tmpdata0, config.dataptr, config.data_size
	qbgt	oom, global.tmpaddr0, global.tmpdata0

resize_end:
	mov		global.width, config.width
	mov		global.height, config.height
	set		global.flags, FLAGS_RESET_BIT

	jmp		global.jal0

delay_loop:
	qbge	delay_loop_end, global.arg1, 0
	sub		global.arg1, global.arg1, 1
	qba		delay_loop

delay_loop_end:
	jmp		global.jal1
