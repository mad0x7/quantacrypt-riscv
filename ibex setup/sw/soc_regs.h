#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

#define SOC_CLOCK_HZ 50000000u
#define GPIO_OUT (*(volatile uint32_t *)0x80000000u)
#define UART_TX (*(volatile uint32_t *)0x80001000u)
#define UART_STATUS (*(volatile uint32_t *)0x80001004u)
#define UART_BUSY 1u

#endif
