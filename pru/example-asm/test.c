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

	// map PRU memory
	prussdrv_map_prumem(PRU_DRAM, (void *)&pru_data);
	prussdrv_map_prumem(PRU_SRAM, (void *)&pru_shared);

	// send interrupt
	prussdrv_pru_send_event(ARM_PRU0_INTERRUPT);

	// wait for incoming interrupt
	prussdrv_pru_wait_event(PRU_EVTOUT_0);
	prussdrv_pru_clear_event(PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

	// print first 32 bits from PRU memory
	printf("local RAM:  0x%08x\nshared RAM: 0x%08x\n", ((uint32_t *)pru_data)[0], ((uint32_t *)pru_shared)[0]);

	prussdrv_exit();
	return(0);
}
