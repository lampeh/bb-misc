// static configuration
#define GPIO_COL_CLK_BIT 0
#define GPIO_COL_DATA_BIT 1
#define GPIO_COL_STROBE_BIT 2
#define GPIO_ROW_CLK_BIT 3
#define GPIO_ROW_DATA_BIT 4
#define GPIO_ROW_STROBE_BIT 2
#define GPIO_OE0_BIT 6
#define GPIO_OE1_BIT 7

// Delay loop: 3 instructions @ 200MHz = ~15ns per loop
#define DELAY_OE 33333 // ~500µs
#define DELAY_STROBE 2 // ~30ns

#define DELAY_OE_NS (500*1000)
#define DELAY_STROBE_NS (30)

// xin/xout device ID
#define SCRATCH_BANK0 10

#define PRU_MEM_BASE 0
#define PRU_MEM_SIZE 0x2000

#define SHARED_MEM_BASE 0x10000
#define SHARED_MEM_SIZE 0x3000

#define CONFIG_VERSION 1

// config.flags
#define FLAGS_CLEAR		0b00000001
#define FLAGS_RESET		0b00000010
#define FLAGS_DITHER	0b00000100
#define FLAGS_ERROR		0b10000000

#define FLAGS_CLEAR_BIT 0
#define FLAGS_RESET_BIT 1
#define FLAGS_DITHER_BIT 2
#define FLAGS_ERROR_BIT 7

// global.flags
#define FLAGS_INV		0b00000001
#define FLAGS_ROW0		0b00000010
#define FLAGS_ROW1		0b00000100

#define FLAGS_INV_BIT 0
#define FLAGS_ROW0_BIT 1
#define FLAGS_ROW1_BIT 2

#define ERROR_VERSION 1
#define ERROR_MEM 2
#define ERROR_OTHER 255

#define nop mov	r0, r0

.struct global_s
	.u8		bbo_count0
	.u8		bbo_count1
	.u16	frameptr

	.u32	ones

	.u16	dbg_count0
	.u16	dbg_count1

	.u32	ditherptr0
	.u32	ditherptr1

	.u32	frameptr_new
	.u32	frameptr_old

	.u32	dataptr0
	.u32	dataptr1

	.u16	dataptr
	.u8		flags
	.u8		shift_count

	.u32	data  // TODO: data and shift_count -> arg1, arg0?

	.u8		gpio_clk  // TODO: -> shift scope?
	.u8		gpio_data
	.u8		gpio_strobe
	.u8		gpio_oe

	.u32	arg1

	.u16	arg0
	.u16	jal0

	.u16	jal1
	.u16	jal2 // call/ret register

	.u8		width
	.u8		height
	.u16	tmpdata1

	.u32	tmpdata0
	.u32	tmpaddr0
.ends

.struct dithering_s
	.u8		x
	.u8		y
	.u8		input
	.u8		bit

	.u32	bitmap

    .u16    forward1
    .u16    forward2

    .u16    error1
    .u16    error2

    .u16    error3
	.u16	dummy0
.ends

.struct diff_s
	.u8		x
	.u8		y
	.u16	dummy0

	.u32	diff_bits

	.u32	input_new
	.u32	input_old
.ends

.struct config_s
	.u8		version
	.u8		flags
	.u8		error
	.u8		bytes_per_pixel

	.u16	width
	.u16	height

	.u8		threshold
	.u8		dummy0
	.u16	data_size

	.u32	dataptr
.ends
