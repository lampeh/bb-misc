#include <stdint.h>

#define SCRATCH_BANK0 10

#define CONFIG_VERSION 1

#define FLAGS_CLEAR		0b00000001
#define FLAGS_RESET		0b00000010
#define FLAGS_DITHER	0b00000100
#define FLAGS_ERROR		0b10000000

#define FLAGS_CLEAR_BIT 0
#define FLAGS_RESET_BIT 1
#define FLAGS_DITHER_BIT 2
#define FLAGS_ERROR_BIT 7

#define ERROR_VERSION 1
#define ERROR_OTHER 255

#define GPIO_COL_CLK_BIT 0
#define GPIO_COL_DATA_BIT 1
#define GPIO_COL_STROBE_BIT 2
#define GPIO_ROW_CLK_BIT 3
#define GPIO_ROW_DATA_BIT 4
#define GPIO_ROW_STROBE_BIT 5
#define GPIO_OE0_BIT 6
#define GPIO_OE1_BIT 7

#define DELAY_OE 33334 // ~500µs, 3 instructions @ 200MHz
#define DELAY_STROBE 2 // ~30ns, 3 instructions @ 200MHz

#define nop mov	r0, r0

typedef struct __attribute__((__packed__)) {
	uint8_t		version;
	uint8_t		flags;
	uint8_t		error;
	uint8_t		bytes_per_pixel;
	uint16_t	width;
	uint16_t	height;
	uint8_t		threshold;
	uint8_t		dummy0;
	uint16_t	data_size;
	uint32_t	dataptr;
} config_s;
