#include "Vibex_minimal_soc.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

static constexpr unsigned kBitCycles = 434;

class SerialReceiver {
 public:
  void sample(bool tx) {
    if (!receiving_) {
      if (previous_ && !tx) {
        receiving_ = true;
        countdown_ = kBitCycles + kBitCycles / 2;
        bit_ = 0;
        value_ = 0;
      }
    } else if (--countdown_ == 0) {
      if (bit_ < 8) {
        value_ |= static_cast<uint8_t>(tx) << bit_++;
        countdown_ = kBitCycles;
      } else {
        if (!tx) throw std::runtime_error("UART stop-bit error");
        output += static_cast<char>(value_);
        receiving_ = false;
      }
    }
    previous_ = tx;
  }

  std::string output;

 private:
  bool previous_ = true;
  bool receiving_ = false;
  unsigned countdown_ = 0;
  unsigned bit_ = 0;
  uint8_t value_ = 0;
};

int main(int argc, char **argv) {
  auto context = std::make_unique<VerilatedContext>();
  context->commandArgs(argc, argv);
  auto dut = std::make_unique<Vibex_minimal_soc>(context.get());
  // Establish a high reset level first so the first assertion creates a real
  // falling edge, including inside Ibex's gated-clock domain.
  dut->clk_i = 0;
  dut->rst_ni = 1;
  dut->eval();

  auto tick = [&]() {
    dut->clk_i = 0;
    dut->eval();
    context->timeInc(10);
    dut->clk_i = 1;
    dut->eval();
    context->timeInc(10);
  };

  try {
    // Reset the same model twice. The second boot verifies startup clears BSS
    // even though RAM contents from the first run remain present.
    for (unsigned boot = 0; boot < 2; ++boot) {
      dut->rst_ni = 0;
      for (unsigned i = 0; i < 16; ++i) tick();
      if (dut->uart_tx_o != 1 || dut->led_o != 0) {
        throw std::runtime_error("UART/LED reset state is incorrect");
      }
      dut->rst_ni = 1;
      SerialReceiver serial;
      unsigned led_patterns = 0;
      bool passed = false;
      for (unsigned cycle = 0; cycle < 2000000; ++cycle) {
        tick();
        serial.sample(dut->uart_tx_o);
        if (dut->led_o == 15 || serial.output.find("FAIL") != std::string::npos) {
          throw std::runtime_error("Firmware reached its failure/trap indication");
        }
        if (dut->led_o == 1) led_patterns |= 1;
        if (dut->led_o == 2) led_patterns |= 2;
        if (dut->led_o == 4) led_patterns |= 4;
        if (dut->led_o == 8) led_patterns |= 8;
        if (serial.output.find("Ibex minimal SoC alive\r\n") != std::string::npos &&
            serial.output.find("RAM and GPIO test: PASS\r\n") != std::string::npos &&
            led_patterns == 15) {
          std::cout << "Boot " << boot + 1 << " passed after " << cycle + 1
                    << " clocks: UART framing, firmware RAM/GPIO checks, LED sequence.\n";
          std::cout << serial.output;
          passed = true;
          break;
        }
      }
      if (!passed) {
        std::cerr << "UART received before timeout: " << serial.output << '\n';
        throw std::runtime_error("Timed out waiting for firmware/LED sequence");
      }
    }
    dut->final();
    std::cout << "PASS: two successful Ibex boots, including reset with retained RAM.\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "FAIL: " << error.what() << '\n';
    dut->final();
    return 1;
  }
}
