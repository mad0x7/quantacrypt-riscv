// Minimal polling UART: 8 data bits, no parity, one stop bit.
module uart_tx #(
  parameter int unsigned ClockHz = 50_000_000,
  parameter int unsigned Baud = 115_200
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       start_i,
  input  logic [7:0] data_i,
  output logic       busy_o,
  output logic       tx_o
);
  localparam int unsigned BitCycles = (ClockHz + Baud / 2) / Baud;
  localparam int unsigned CounterWidth = $clog2(BitCycles);
  logic [CounterWidth-1:0] cycles_q;
  logic [3:0] bits_left_q;
  logic [9:0] shift_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycles_q <= '0;
      bits_left_q <= '0;
      shift_q <= '1;
      busy_o <= 1'b0;
      tx_o <= 1'b1;
    end else if (!busy_o) begin
      if (start_i) begin
        shift_q <= {1'b1, data_i, 1'b0};
        cycles_q <= CounterWidth'(BitCycles - 1);
        bits_left_q <= 4'd9;
        busy_o <= 1'b1;
        tx_o <= 1'b0;
      end
    end else if (cycles_q != 0) begin
      cycles_q <= cycles_q - 1'b1;
    end else if (bits_left_q == 0) begin
      busy_o <= 1'b0;
      tx_o <= 1'b1;
    end else begin
      tx_o <= shift_q[1];
      shift_q <= {1'b1, shift_q[9:1]};
      bits_left_q <= bits_left_q - 1'b1;
      cycles_q <= CounterWidth'(BitCycles - 1);
    end
  end
endmodule
