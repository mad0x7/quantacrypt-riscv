module arty_top #(
  parameter MEM_FILE = "program.mem"
) (
  input  logic       CLK100MHZ,
  input  logic       ck_rst,
  output logic [3:0] led,
  output logic       uart_tx
);
  logic clk_fb_raw, clk_fb, clk_raw, clk, locked;
  MMCME2_BASE #(
    .CLKIN1_PERIOD (10.0),
    .DIVCLK_DIVIDE (1),
    .CLKFBOUT_MULT_F (8.0),
    .CLKOUT0_DIVIDE_F (16.0)
  ) u_mmcm (
    .CLKIN1 (CLK100MHZ),
    .CLKFBIN (clk_fb),
    .CLKFBOUT (clk_fb_raw),
    .CLKOUT0 (clk_raw),
    .LOCKED (locked),
    .PWRDWN (1'b0),
    .RST (1'b0)
  );
  BUFG u_feedback_buf (.I(clk_fb_raw), .O(clk_fb));
  BUFG u_clock_buf (.I(clk_raw), .O(clk));

  // Assert reset asynchronously; release it after three stable clock edges.
  wire async_rst_n = ck_rst && locked;
  (* ASYNC_REG = "TRUE" *) logic [2:0] rst_sync;
  always_ff @(posedge clk or negedge async_rst_n) begin
    if (!async_rst_n) rst_sync <= 3'b0;
    else rst_sync <= {rst_sync[1:0], 1'b1};
  end

  ibex_minimal_soc #(.MEM_FILE(MEM_FILE)) u_soc (
    .clk_i (clk),
    .rst_ni (rst_sync[2]),
    .led_o (led),
    .uart_tx_o (uart_tx)
  );
endmodule
