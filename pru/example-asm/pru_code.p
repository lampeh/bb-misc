#include <pruss_intc_mapping.h>

// #define USE_SHARED_RAM

.setcallreg r29.w2
.origin 0

start:
	// r30[13:8] GPIO output pins occupied by eMMC interface
	// pin_mux_sel[1] = 1: map r30[13:8] to r30[5:0] on PRU1
	lbco	&r28, c4, 0x40, 4
	set		r28, r28, 1
	sbco	&r28, c4, 0x40, 4

	// clear all outputs
	mov		r30.w0, 0

#ifdef USE_SHARED_RAM
	// enable OCP master port in SYSCFG register
	// required for shared RAM access
	lbco	&r28, c4, 0x04, 4
	clr		r28, r28, 4
	sbco	&r28, c4, 0x04, 4

	// set CTPPR0[15:0] to 0x0100
	// sets constant c28 to shared RAM base address 0x010000
	mov		r27, 0x22028
	mov		r28.w0, 0x0100
	sbbo	&r28.w0, r27, 0, 2
#else
	// set CTPPR0[15:0] to 0x0000
	// sets constant c28 to local RAM base address 0x000000
	mov		r27, 0x22028
	mov		r28.w0, 0x0000
	sbbo	&r28.w0, r27, 0, 2
#endif

	// DEBUG: enable cycle counter in CONTROL register
//	mov		r27, 0x22000
//	lbbo	&r28, r27, 0, 4
//	set		r28, r28, 3
//	sbbo	&r28, r27, 0, 4

	// enable wakeup by interrupt 0 (PRU0)
	mov		r27, 0x22008
	mov		r28, (1<<30)
	sbbo	&r28, r27, 0, 4

	// DEMO: reset counter
	mov		r26, 0

main_loop:
	// wait for interrupt
	slp		1

	// DEMO: increment counter and store in RAM
	add		r26, r26, 1
	sbco	&r26, c28, 0, 4

	// DEMO: toggle GPIOs
	xor		r30.b0, r30.b0, 0xFF

	// clear interrupt through SICR register
	mov		r28, ARM_PRU0_INTERRUPT
	sbco	&r28, c0, 0x24, 4

	// send event to CPU
	mov		r31.b0, PRU0_ARM_INTERRUPT+16

	// go back to sleep
	qba		main_loop
