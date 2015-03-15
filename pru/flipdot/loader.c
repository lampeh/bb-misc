#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include <prussdrv.h>
#include <pruss_intc_mapping.h>

#define PRU_NUM 0
#define PRU_IRAM PRUSS0_PRU0_IRAM
#define PRU_DRAM PRUSS0_PRU0_DATARAM
#define PRU_DRAM_SIZE 0x2000
#define PRU_SRAM PRUSS0_SHARED_DATARAM
#define PRU_SRAM_SIZE 0x3000

// include assembled PRU binary
// const unsigned int PRUcode[]
#include "pru_code_bin.h"

typedef volatile uint8_t PRU_data_t[PRU_DRAM_SIZE];
typedef volatile uint8_t PRU_shared_t[PRU_SRAM_SIZE];

static PRU_data_t *pru_data;
static PRU_shared_t *pru_shared;

static const tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;

int main(void) {
	prussdrv_init();

	// open driver and register PRU_EVTOUT_0 interrupt
	int rc = prussdrv_open(PRU_EVTOUT_0);
	if (rc) {
		fprintf(stderr, "prussdrv_open() failed\n");
		return(rc);
	}

	fprintf(stdout, "PRU version: %s\n", prussdrv_strversion(prussdrv_version()));

	// set default interrupt map
	prussdrv_pruintc_init(&pruss_intc_initdata);

	fprintf(stdout, "Initializing PRU%d\n", PRU_NUM);
	prussdrv_pru_disable(PRU_NUM);
	prussdrv_pru_reset(PRU_NUM);

	fprintf(stdout, "Clearing local RAM in PRU%d\n", PRU_NUM);
	prussdrv_map_prumem(PRU_DRAM, (void *)&pru_data);
	memset(pru_data, 0x00, sizeof(*pru_data));

	fprintf(stdout, "Clearing shared RAM\n");
	prussdrv_map_prumem(PRU_SRAM, (void *)&pru_shared);
	memset(pru_shared, 0x00, sizeof(*pru_shared));

	fprintf(stdout, "Uploading code into PRU%d\n", PRU_NUM);
	prussdrv_pru_write_memory(PRU_IRAM, 0, (const unsigned int *)&PRUcode, sizeof(PRUcode)); 

	// Memory barrier: Think again - all writes to PRU memory must complete before pru_enable()
	asm volatile ("" : : : "memory");

	fprintf(stdout, "Starting PRU%d\n", PRU_NUM);
	prussdrv_pru_enable(PRU_NUM);

	prussdrv_exit();
	return(0);
}
