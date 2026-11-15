#include "soc_regs.h"

#ifndef BLINK_CYCLES
#define BLINK_CYCLES (SOC_CLOCK_HZ / 2u)
#endif

static volatile uint32_t test_ram[16];
static volatile uint32_t initialized_data = 0x12345678u;

static uint32_t cycle_count(void) {
  uint32_t value;
  __asm__ volatile("csrr %0, mcycle" : "=r"(value));
  return value;
}

static void uart_putc(char c) {
  while (UART_STATUS & UART_BUSY) {}
  UART_TX = (uint8_t)c;
}

static void uart_puts(const char *s) {
  while (*s) uart_putc(*s++);
}

static void fail(void) {
  GPIO_OUT = 15u;
  uart_puts("RAM or GPIO test: FAIL\r\n");
  while (1) {}
}

int main(void) {
  // Check initialized data, reset-time BSS clearing, and RAM read/write paths.
  if (initialized_data != 0x12345678u) fail();
  for (uint32_t i = 0; i < 16; ++i) {
    if (test_ram[i] != 0u) fail();
    test_ram[i] = 0xa5a50000u ^ (i * 0x10203u);
  }
  for (uint32_t i = 0; i < 16; ++i) {
    if (test_ram[i] != (0xa5a50000u ^ (i * 0x10203u))) fail();
  }
  volatile uint8_t *bytes = (volatile uint8_t *)&test_ram[0];
  bytes[0] = 0x11;
  bytes[1] = 0x22;
  bytes[2] = 0x33;
  bytes[3] = 0x44;
  if (test_ram[0] != 0x44332211u) fail();
  volatile uint16_t *halves = (volatile uint16_t *)&test_ram[0];
  halves[1] = 0xa1b2;
  if (test_ram[0] != 0xa1b22211u) fail();

  GPIO_OUT = 1u;
  if (GPIO_OUT != 1u) fail();
  uart_puts("Ibex minimal SoC alive\r\n");
  uart_puts("RAM and GPIO test: PASS\r\n");

  uint32_t led = 1u;
  while (1) {
    GPIO_OUT = led;
    uart_puts("tick\r\n");
    uint32_t start = cycle_count();
    while ((uint32_t)(cycle_count() - start) < BLINK_CYCLES) {}
    led = (led == 8u) ? 1u : led << 1;
  }
}
