#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>

#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#include "image.c"
#include "pru_code.h"

#define PRU_NUM 0
#define PRU_IRAM PRUSS0_PRU0_IRAM
#define PRU_DRAM PRUSS0_PRU0_DATARAM
#define PRU_DRAM_SIZE 0x2000
#define PRU_SRAM PRUSS0_SHARED_DATARAM
#define PRU_SRAM_SIZE 0x3000

#define BYTETOBINARYPATTERN "%c%c%c%c%c%c%c%c"
#define BYTETOBINARY(byte)  \
  (byte & 0x01 ? '#' : '.'), \
  (byte & 0x02 ? '#' : '.'), \
  (byte & 0x04 ? '#' : '.'), \
  (byte & 0x08 ? '#' : '.'), \
  (byte & 0x10 ? '#' : '.'), \
  (byte & 0x20 ? '#' : '.'), \
  (byte & 0x40 ? '#' : '.'), \
  (byte & 0x80 ? '#' : '.')

//typedef volatile uint8_t PRU_data_t[PRU_DRAM_SIZE];
//typedef volatile uint8_t PRU_shared_t[PRU_SRAM_SIZE];

//#define COLS 100
//#define ROWS 75

#define COLS 40
#define ROWS 32

//#define COLS 24
//#define ROWS 255

//typedef volatile uint8_t data_t[COLS*ROWS];

//static PRU_data_t *pru_data;
//static PRU_shared_t *pru_shared;

static volatile uint8_t *pru_data;
static volatile uint8_t *pru_shared;

static config_s *config;
//static data_t *data;

static const tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

static struct timeval tv0, tv1;
static double cur_usec;

int main(const int argc, const char *argv[]) {
gettimeofday(&tv0, NULL);
uint32_t seed = ((tv0.tv_sec*1000000) + tv0.tv_usec) % UINT32_MAX;
srand(seed);
//	srand(time(NULL));
	prussdrv_init();

	long int threshold = 128;
	if (argc > 1) {
		threshold = atoi(argv[1]);
	}

	long int flags = 0;
	if (argc > 2) {
		flags = atoi(argv[2]);
	}

	// open driver and register PRU_EVTOUT_0 interrupt
	int rc = prussdrv_open(PRU_EVTOUT_0);
	if (rc) {
		fprintf(stderr, "prussdrv_open() failed\n");
		return(rc);
	}

	fprintf(stdout, "PRU version: %s\n", prussdrv_strversion(prussdrv_version()));

	// set default interrupt map
	prussdrv_pruintc_init(&pruss_intc_initdata);

	// map PRU memory
	prussdrv_map_prumem(PRU_DRAM, (void *)&pru_data);
	prussdrv_map_prumem(PRU_SRAM, (void *)&pru_shared);

	config = (config_s *)pru_data;

	config->version = 1;
	config->flags = flags;
//	config->flags = 0;
//	config->flags |= FLAGS_DITHER;
//	config->flags |= FLAGS_CLEAR;
	config->error = 0;
	config->width = COLS;
	config->height = ROWS;
	config->bytes_per_pixel = 1;
	config->threshold = threshold;
//	config->threshold = 64;
//	config->threshold = 128;
	config->data_size = config->width * config->height * config->bytes_per_pixel;
	config->dataptr = sizeof(*config);

time_t foo = time(NULL);
///*
	for (uint8_t y=0; y < config->height; y++) {
		for (uint8_t x=0; x < config->width; x++) {
			*(pru_data+sizeof(*config)+(y*config->width)+x) = (foo + (255/config->height)*y) % 256;
//			*(pru_data+sizeof(*config)+(y*config->width)+x) = (255/config->height)*y;
		}
	}
//*/

/*
	for (uint32_t i=0; i < config->width * config->height; i++) {
		*(pru_data+sizeof(*config)+i) = gimp_image.pixel_data[i*3];
	}
*/

	gettimeofday(&tv0, NULL);

	// send interrupt
	prussdrv_pru_send_event(ARM_PRU0_INTERRUPT);

	// wait for incoming interrupt
	prussdrv_pru_wait_event(PRU_EVTOUT_0);
	gettimeofday(&tv1, NULL);
	prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

	cur_usec = ((tv1.tv_sec*1000000) + tv1.tv_usec) - ((tv0.tv_sec*1000000) + tv0.tv_usec);
	printf("frame time: %.2fms\n", cur_usec / 1000);

	// print first 32 bits from PRU memory
	printf("local RAM:  0x%08x\nshared RAM: 0x%08x\n", ((uint32_t *)pru_data)[0], ((uint32_t *)pru_shared)[0]);

	for (uint32_t i=0; i < 5; i++) {
		printf("0x%02x : 0x%08x 0x%08x\n", i, ((uint32_t *)pru_data)[i], ((uint32_t *)pru_shared)[i]);
	}

	printf("data size: %u\n", config->data_size);
	int j = (COLS + 7)/8;
	for (uint32_t i=0; i < config->data_size; i++) {
		if (i % j == 0) {
			printf("\n");
//printf ("%02d : %03d : ", i/j, (255/config->height)*(i/j));
printf ("%02d : %03d : ", i/j, (unsigned int)((foo + (255/config->height)*(i/j)) % 256));
		}

		printf(BYTETOBINARYPATTERN, BYTETOBINARY(*(pru_shared + config->dataptr - 0x10000 + i)));
	}
	printf("\n");
	prussdrv_exit();
	return(0);
}
