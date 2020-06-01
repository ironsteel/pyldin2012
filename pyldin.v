module pyldin(
  input clk_25mhz,
  input rst,
  output [2:0] vga_r,
  output [2:0] vga_g,
  output [2:0] vga_b,
  output vga_hs,
  output vga_vs,
  output vga_de, 
  /*
  output led_capslock,
  output led_latkir,
  output speaker_port,
  output mmc_cs,
  output mmc_ck,
  output mmc_di,
  input mmc_do,*/

  output sdram_csn,       // chip select
  output sdram_clk,       // clock to SDRAM
  output sdram_cke,       // clock enable to SDRAM
  output sdram_rasn,      // SDRAM RAS
  output sdram_casn,      // SDRAM CAS
  output sdram_wen,       // SDRAM write-enable
  output [12:0] sdram_a,  // SDRAM address bus
  output  [1:0] sdram_ba, // SDRAM bank-address
  output  [1:0] sdram_dqm,// byte select
  input esp32_ps2clk,
  input esp32_ps2data,
`ifdef SIM
  input [15:0] sd_data_in,
  output [15:0] sd_data_out,
  output write
`else
  output  [3:0] gpdi_dp,
  inout  [15:0] sdram_d,  // data bus to/from SDRAM
  input ftdi_txd,
  output ftdi_rxd,
  input wifi_txd,
  output wifi_rxd,
  output [6:0] led,
  output flash_csn,
  output flash_mosi,
  input  flash_miso,
  output [3:0] audio_l,
  output [3:0] audio_r
`endif
);

wire clk;
wire clk_shift;
wire sdram_clock;
wire clock_locked;
wire clk25;
`ifdef SIM
  assign sdram_clock = clk;
  assign write = memory_write;
  assign clk = clk_25mhz;
  assign clock_locked = 1;
  assign sdram_a = sdram_a_1;
  assign sdram_rasn =  sdram_rasn_1;
  assign sdram_casn = sdram_casn_1;
  assign sdram_wen = sdram_wen_1;


  clock_div div_i(
    .i_clk(clk),
    .i_rst(!rst),
    .i_clk_divider(2),
    .o_clk(clock)
  );

  clock_div div_i1(
    .i_clk(clk),
    .i_rst(!rst),
    .i_clk_divider(8),
    //.o_clk(clock_ref)
  );

  reg [2:0] counter = 0; 

  assign clock_ref = (counter == 3);
  always @(posedge clock) begin
    counter <= counter + 1;
  end

  clock_div div_i2(
    .i_clk(clk),
    .i_rst(!rst),
    .i_clk_divider(4),
    .o_clk(clk25)
  );

  assign load_done = ready; 

`else 
  //assign wifi_rxd = ftdi_txd;
  //assign ftdi_rxd = wifi_txd;
  wire flash_sck;
  wire tristate = 1'b0;
  USRMCLK u1 (.USRMCLKI(flash_sck), .USRMCLKTS(tristate));
  assign sdram_clock = clk;
  assign led[0] = rst;
  assign led[1] = load_done;
  wire [15:0] sd_data_in;
  wire [15:0] sd_data_out;
  clk_25_100 clk_25_100i(
    .clk25_i(clk_25mhz),
    .clk100_o(clk),
  //  .clk50_o(clock),
    //.clk12_o(clock_ref),
  //  .cl25_o(clk25),
    .locked(clock_locked)
  );

  clock_div div_i(
    .i_clk(clk),
    .i_clk_divider(2),
    .i_rst(clock_locked),
    .o_clk(clock)
  );

  clock_div div_i1(
    .i_clk(clk),
    .i_rst(clock_locked),
    .i_clk_divider(8),
    .o_clk(clock_ref)
  );

  clock_div div_i2(
    .i_clk(clk),
    .i_rst(clock_locked),
    .i_clk_divider(4),
    .o_clk(clk25)
  );
  pll_dvi pll_dvi_i(
    .clkin(clk_25mhz),
    .clkout0(clk_shift)
  );

  flash_loader
  flash_load_i
  (
    .clock(clock_ref),
    .reset(!ready),
    .reload(1'b0),
    .load_write_data(flash_loader_data_out),
    .data_valid(flash_loader_data_ready),
    .load_done(load_done),
    //Flash load interface
    .flash_csn(flash_csn),
    .flash_sck(flash_sck),
    .flash_mosi(flash_mosi),
    .flash_miso(flash_miso)
  );
  always @(posedge clock_ref) begin 
    if (rst == 1'b1) begin
      load_addr <= 25'h10000;
      end else begin
        if (flash_loader_data_ready && !load_done) load_addr <= load_addr + 1;
    end
  end

  // VGA to digital video converter
  wire [1:0] tmds[3:0];
  vga2dvid
  #(
    .C_ddr(1'b1),
    .C_shift_clock_synchronizer(1'b0)
  )
  vga2dvid_instance
  (
    .clk_pixel(clk_25mhz),
    .clk_shift(clk_shift),
    .in_red(vga_r_r),
    .in_green(vga_g_r),
    .in_blue(vga_b_r),
    .in_hsync(vga_hs),
    .in_vsync(vga_vs),
    .in_blank(!vga_de),
    .out_clock(tmds[3]),
    .out_red(tmds[2]),
    .out_green(tmds[1]),
    .out_blue(tmds[0])
  );

  wire [31:0] la_capture;
  /*sump2_top sump2_i(
    .clk_lb_tree(clk_25mhz),
    .clk_cap_tree(clk),
    .ftdi_wi(ftdi_txd),
    .ftdi_ro(ftdi_rxd),
    .events_din(la_capture)
  );*/
  wire speaker_port;
  assign audio_l = {4{speaker_port}};
  assign audio_r = {4{speaker_port}};

  //assign la_capture[7:0] = mux_ram_data_out; 
  assign la_capture[0] = esp32_ps2clk; 
  assign la_capture[1] = esp32_ps2data; 
  /*assign la_capture[0] = clk_25mhz;
  assign la_capture[1] = clock;
  assign la_capture[2] = clock_ref;
  assign la_capture[3] = clk;*/
  assign la_capture[26:8] = {mux_ram_page, mux_ram_addr[15:0]}; 
  assign la_capture[27] = mux_ram_read;

  //assign la_capture[15:8] = mux_ram_data_in; 
  // vendor specific DDR modules
  // convert SDR 2-bit input to DDR clocked 1-bit output (single-ended)
  ODDRX1F ddr_clock (.D0(tmds[3][0]), .D1(tmds[3][1]), .Q(gpdi_dp[3]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_red   (.D0(tmds[2][0]), .D1(tmds[2][1]), .Q(gpdi_dp[2]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_green (.D0(tmds[1][0]), .D1(tmds[1][1]), .Q(gpdi_dp[1]), .SCLK(clk_shift), .RST(0));
  ODDRX1F ddr_blue  (.D0(tmds[0][0]), .D1(tmds[0][1]), .Q(gpdi_dp[0]), .SCLK(clk_shift), .RST(0));

  sdram_glue glue(
    .clk(clk),
    .pin_clk(sdram_clk),
    .pin_ras_n(sdram_rasn),
    .pin_cas_n(sdram_casn),
    .pin_we_n(sdram_wen),
    .pin_addr(sdram_a),
    .pin_data(sdram_d),
    .ras_n(sdram_rasn_1),
    .cas_n(sdram_casn_1),
    .we_n(sdram_wen_1),
    .addr(sdram_a_1),
    .data_i(sd_data_in),
    .data_o(sd_data_out),
    .data_oe(memory_write)
  );


`endif
  wire [7:0] ledseg;
  wire [7:0] ledcom;

  wire ram_hold;
  wire clkref;
  wire [7:0] mux_ram_data_in;
  wire [7:0] mux_ram_data_out;
  wire mux_ram_cs;
  wire mux_ram_rw;
  wire mux_ram_read;
  wire [2:0] mux_ram_page;
  wire [15:0] mux_ram_addr;

  wire [7:0] vga_r_r;
  wire [7:0] vga_g_r;
  wire [7:0] vga_b_r;

  wire [7:0] flash_loader_data_out;
  wire flash_loader_data_ready;
  wire load_done;
  reg [24:0] load_addr = 25'h10000;

  pyldin2012 pyldin_i(
    .clk(clock),
    .clk25(clk25),
    .rst(load_done),
    .ps2_kbd_clk(esp32_ps2clk),
    .ps2_kbd_data(esp32_ps2data),
    .swt(1'b0),
    .step(1'b0),
    .vga_r(vga_r_r),
    .vga_g(vga_g_r),
    .vga_b(vga_b_r),
    .vga_vs(vga_vs),
    .vga_hs(vga_hs),
    .vga_de(vga_de),
    .led_capslock(led_capslock),
    .led_latkir(led_latkir),
    .mmc_cs(mmc_cs),
    .mmc_ck(mmc_ck),
    .mmc_di(mmc_di),
    .mmc_do(mmc_do),
    .ledseg(ledseg),
    .ledcom(ledcom),
    .ram_hold(ram_hold),
    .mux_ram_cs(mux_ram_cs),
    .mux_ram_rw(mux_ram_rw),
    .mux_ram_page(mux_ram_page),
    .mux_ram_addr(mux_ram_addr),
    .mux_ram_data_in(mux_ram_data_in),
    .mux_ram_data_out(mux_ram_data_out),
    .mux_ram_read(mux_ram_read),
    .speaker_port(speaker_port)
  );

  assign vga_r = vga_r_r[2:0];
  assign vga_g = vga_g_r[2:0];
  assign vga_b = vga_b_r[2:0];

  wire clock;
  wire clock_ref;

  /*ram ram_i(
    .clk(clk),
    .rw(mux_ram_rw),
    .cs(mux_ram_cs),
    .read(mux_ram_read),
    .addr({mux_ram_page, mux_ram_addr}),
    .data_in(mux_ram_data_in),
    .data_out(mux_ram_data_out)
  );*/


  wire [7:0] sdram_data_out;
  wire memory_write;
  wire ready;
  sdram
  sdram_i(
   .sd_data_in(sd_data_in),
   .sd_data_out(sd_data_out),
   .sd_addr(sdram_a_1),
   .sd_dqm({sdram_dqm[1], sdram_dqm[0]}),
   .sd_cs(sdram_csn),
   .sd_ba(sdram_ba),
   .sd_we(sdram_wen_1),
   .sd_ras(sdram_rasn_1),
   .sd_cas(sdram_casn_1),
   // system interface
   .clk(sdram_clock),
   .clkref(clock_ref),
   .init(rst || !clock_locked),
   .we(memory_write),
   // cpu/chipset interface
   .addrA     	   (!load_done ? load_addr : {mux_ram_page, mux_ram_addr}),
   
   .weA            (ready == 0 ? 0 : (!load_done ? flash_loader_data_ready : (mux_ram_cs & !mux_ram_rw))),

   .dinA           (!load_done ? flash_loader_data_out : mux_ram_data_in),

   .oeA            (mux_ram_cs & mux_ram_read),
   .doutA          (mux_ram_data_out),
   .ready(ready)
  );

  wire sdram_rasn_1;
  wire sdram_casn_1;
  wire sdram_wen_1;
  wire [12:0] sdram_a_1;


  assign sdram_cke = 1'b1;

endmodule

`ifndef SIM
// Copyright 2020, Brian Swetland <swetland@frotz.net>
// Licensed under the Apache License, Version 2.0.
module sdram_glue #(
	parameter AWIDTH = 13,
	parameter DWIDTH = 16,
	parameter CLK_DELAY = 0, // delay clock by 1..128 x 25pS
	parameter CLK_SHIFT = 0  // delay clock by 1/2 cycle
	) (
	input wire clk,
	output wire pin_clk,
	output wire pin_ras_n,
	output wire pin_cas_n,
	output wire pin_we_n,
	output wire [AWIDTH-1:0]pin_addr,
	inout wire [DWIDTH-1:0]pin_data,
	input wire ras_n,
	input wire cas_n,
	input wire we_n,
	input wire [AWIDTH-1:0]addr,
	input wire [DWIDTH-1:0]data_i,
	output wire [DWIDTH-1:0]data_o,
	output wire data_oe
);

assign pin_ras_n = ras_n;
assign pin_cas_n = cas_n;
assign pin_we_n = we_n;
assign pin_addr = addr;

wire delay_clk;

DELAYG #(
	.DEL_MODE("USER_DEFINED"),
	.DEL_VALUE(CLK_DELAY)
	) clock_delay (
	.A(delay_clk),
	.Z(pin_clk)
);

ODDRX1F clock_ddr (
        .Q(delay_clk),
        .SCLK(clk),
        .RST(0),
        .D0(CLK_SHIFT ? 0 : 1),
        .D1(CLK_SHIFT ? 1 : 0)
);

genvar n;
generate
for (n = 0; n < DWIDTH; n++) begin
	BB iobuf (
		.I(data_o[n]),
		.T(~data_oe),
		.O(data_i[n]),
		.B(pin_data[n])
	);
end
endgenerate

endmodule
`endif

