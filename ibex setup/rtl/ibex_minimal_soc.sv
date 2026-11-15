// Board bring-up platform. RAM is intentionally executable and writable here;
// the later secure-boot design must add trusted ROM and execution protection.
module ibex_minimal_soc #(
  parameter MEM_FILE = "program.mem"
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  output logic [3:0] led_o,
  output logic       uart_tx_o
);
  localparam logic [31:0] GpioOut = 32'h8000_0000;
  localparam logic [31:0] UartTx = 32'h8000_1000;
  localparam logic [31:0] UartStatus = 32'h8000_1004;

  logic instr_req, instr_gnt, instr_rvalid, instr_err;
  logic [31:0] instr_addr, instr_rdata;
  logic data_req, data_gnt, data_rvalid, data_we, data_err;
  logic [3:0] data_be;
  logic [31:0] data_addr, data_wdata, data_rdata;

  // Matches the Ibex revision already installed in riscv-project/ibex.
  ibex_top #(
    .RegFile (ibex_pkg::RegFileFPGA),
    .BaseIsa (ibex_pkg::BaseIsaRV32I),
    .RV32M (ibex_pkg::RV32MFast),
    .RV32B (ibex_pkg::RV32BNone),
    .ICache (1'b0),
    .SecureIbex (1'b0)
  ) u_ibex (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    .test_en_i (1'b0),
    .ram_cfg_icache_tag_i ('0),
    .ram_cfg_icache_tag_o (),
    .ram_cfg_icache_data_i ('0),
    .ram_cfg_icache_data_o (),
    .cheriot_enable_i (ibex_pkg::IbexMuBiOff),
    .hart_id_i (32'b0),
    .boot_addr_i (32'b0), // Ibex's first instruction is at 0x00000080.
    .trvk_heap_base_addr_i (32'b0),
    .instr_req_o (instr_req),
    .instr_gnt_i (instr_gnt),
    .instr_rvalid_i (instr_rvalid),
    .instr_addr_o (instr_addr),
    .instr_rdata_i (instr_rdata),
    .instr_rdata_intg_i ('0),
    .instr_err_i (instr_err),
    .data_req_o (data_req),
    .data_gnt_i (data_gnt),
    .data_rvalid_i (data_rvalid),
    .data_we_o (data_we),
    .data_be_o (data_be),
    .data_addr_o (data_addr),
    .data_wdata_o (data_wdata),
    .data_wdata_intg_o (),
    .data_tag_o (),
    .data_rdata_i (data_rdata),
    .data_rdata_intg_i ('0),
    .data_tag_i (1'b0),
    .data_err_i (data_err),
    .trvk_revbm_req_o (),
    .trvk_revbm_gnt_i (1'b0),
    .trvk_revbm_rvalid_i (1'b0),
    .trvk_revbm_addr_o (),
    .trvk_revbm_rdata_i ('0),
    .trvk_revbm_rdata_intg_i ('0),
    .trvk_revbm_err_i (1'b0),
    .irq_software_i (1'b0),
    .irq_timer_i (1'b0),
    .irq_external_i (1'b0),
    .irq_fast_i ('0),
    .irq_nm_i (1'b0),
    .scramble_key_valid_i (1'b0),
    .scramble_key_i ('0),
    .scramble_nonce_i ('0),
    .scramble_req_o (),
    .debug_req_i (1'b0),
    .crash_dump_o (),
    .double_fault_seen_o (),
    .fetch_enable_i (ibex_pkg::IbexMuBiOn),
    .mcounteren_writable_i (ibex_pkg::IbexMuBiOff),
    .alert_minor_o (),
    .alert_major_internal_o (),
    .alert_major_bus_o (),
    .core_sleep_o (),
    .scan_rst_ni (1'b1),
    .lockstep_cmp_en_o (),
    .data_req_shadow_o (),
    .data_we_shadow_o (),
    .data_be_shadow_o (),
    .data_addr_shadow_o (),
    .data_wdata_shadow_o (),
    .data_wdata_intg_shadow_o (),
    .instr_req_shadow_o (),
    .instr_addr_shadow_o ()
  );

  // Two independent synchronous read ports, one byte-enabled write port.
  (* ram_style = "block" *) logic [31:0] mem [0:16383];
  initial $readmemh(MEM_FILE, mem);

  logic instr_accept, instr_ram;
  logic data_accept, data_ram, data_gpio, data_uart_tx, data_uart_status;
  logic instr_busy_q, instr_pending_q, instr_fault_q;
  logic data_busy_q, data_pending_q, data_fault_q;
  logic instr_ram_req_q, data_ram_req_q, data_write_q;
  logic [13:0] instr_ram_addr_q, data_ram_addr_q;
  logic [3:0] data_byte_en_q;
  logic [31:0] data_ram_wdata_q;
  logic ram_response_q;
  logic [31:0] ram_rdata_q, mmio_rdata_q;
  logic uart_busy, uart_start;

  assign instr_ram = (instr_addr[31:16] == 16'b0);
  assign instr_gnt = instr_req && rst_ni && !instr_busy_q;
  assign instr_accept = instr_req && instr_gnt;
  assign data_ram = (data_addr[31:16] == 16'b0);
  assign data_gpio = (data_addr[31:2] == GpioOut[31:2]);
  assign data_uart_tx = (data_addr[31:2] == UartTx[31:2]);
  assign data_uart_status = (data_addr[31:2] == UartStatus[31:2]);
  // A UART write waits for a free transmitter even if software skips polling.
  assign data_gnt = data_req && rst_ni && !data_busy_q &&
                    !(data_uart_tx && data_we && data_be[0] && uart_busy);
  assign data_accept = data_req && data_gnt;
  assign uart_start = data_accept && data_uart_tx && data_we && data_be[0];
  assign data_rdata = ram_response_q ? ram_rdata_q : mmio_rdata_q;

  // Clocked input staging prevents Ibex's asynchronous-reset address/control
  // flops from directly driving BRAM pins. These staging flops have no reset.
  // An already accepted RAM store can finish when CPU reset is asserted;
  // its address, data and byte enables stay stable throughout that operation.
  always_ff @(posedge clk_i) begin
    instr_ram_req_q <= instr_accept && instr_ram;
    data_ram_req_q <= data_accept && data_ram;
    if (instr_accept) instr_ram_addr_q <= instr_addr[15:2];
    if (data_accept) begin
      data_ram_addr_q <= data_addr[15:2];
      data_ram_wdata_q <= data_wdata;
      data_byte_en_q <= data_be;
      data_write_q <= data_we;
    end
  end

  // Do not reset RAM or its read-data flops: this permits BRAM inference.
  always_ff @(posedge clk_i) begin
    if (instr_ram_req_q) instr_rdata <= mem[instr_ram_addr_q];
    if (data_ram_req_q) begin
      ram_rdata_q <= mem[data_ram_addr_q];
      if (data_write_q) begin
        for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
          if (data_byte_en_q[byte_idx]) begin
            mem[data_ram_addr_q][8*byte_idx +: 8] <= data_ram_wdata_q[8*byte_idx +: 8];
          end
        end
      end
    end
  end

  // Two-cycle responses align with the staged RAM read. Limit each CPU port
  // to one outstanding request; stores and invalid accesses also complete.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_busy_q <= 1'b0;
      instr_pending_q <= 1'b0;
      instr_fault_q <= 1'b0;
      instr_rvalid <= 1'b0;
      instr_err <= 1'b0;
      data_busy_q <= 1'b0;
      data_pending_q <= 1'b0;
      data_fault_q <= 1'b0;
      data_rvalid <= 1'b0;
      data_err <= 1'b0;
      ram_response_q <= 1'b0;
      mmio_rdata_q <= 32'b0;
      led_o <= 4'b0;
    end else begin
      instr_busy_q <= instr_accept || (instr_busy_q && !instr_pending_q);
      instr_pending_q <= instr_accept;
      instr_rvalid <= instr_pending_q;
      instr_err <= instr_pending_q && instr_fault_q;
      if (instr_accept) instr_fault_q <= !instr_ram;
      data_busy_q <= data_accept || (data_busy_q && !data_pending_q);
      data_pending_q <= data_accept;
      data_rvalid <= data_pending_q;
      data_err <= data_pending_q && data_fault_q;
      if (data_accept) begin
        ram_response_q <= data_ram;
        data_fault_q <= !(data_ram || data_gpio || data_uart_tx ||
                         (data_uart_status && !data_we));
        mmio_rdata_q <= 32'b0;
        if (data_gpio) begin
          mmio_rdata_q <= {28'b0, led_o};
          if (data_we && data_be[0]) led_o <= data_wdata[3:0];
        end else if (data_uart_status) begin
          mmio_rdata_q <= {31'b0, uart_busy};
        end
      end
    end
  end

  uart_tx #(.ClockHz(50_000_000), .Baud(115_200)) u_uart_tx (
    .clk_i (clk_i),
    .rst_ni (rst_ni),
    .start_i (uart_start),
    .data_i (data_wdata[7:0]),
    .busy_o (uart_busy),
    .tx_o (uart_tx_o)
  );
endmodule
