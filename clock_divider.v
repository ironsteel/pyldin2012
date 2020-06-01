// File clock_didived.vhdl translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// no timescale needed

module clock_div(
input wire i_clk,
input wire i_rst,
input wire [3:0] i_clk_divider,
output reg o_clk
);




reg [3:0] r_clk_counter = 0;
reg [3:0] r_clk_divider = 0;
reg [3:0] r_clk_divider_half = 0;

  always @(posedge i_clk) begin
    if((i_rst == 1'b0)) begin
      r_clk_counter <= {4{1'b0}};
      r_clk_divider <= {4{1'b0}};
      r_clk_divider_half <= {4{1'b0}};
      o_clk <= 1'b0;
    end else begin
      r_clk_divider <= (i_clk_divider) - 1;
      r_clk_divider_half <= {1'b0,i_clk_divider[3:1]};
      // half
      if((r_clk_counter < r_clk_divider_half)) begin
        r_clk_counter <= r_clk_counter + 1;
        o_clk <= 1'b0;
      end
      else if((r_clk_counter == r_clk_divider)) begin
        r_clk_counter <= {4{1'b0}};
        o_clk <= 1'b1;
      end
      else begin
        r_clk_counter <= r_clk_counter + 1;
        o_clk <= 1'b1;
      end
    end
  end


endmodule
