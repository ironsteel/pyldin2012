module ram(
  input clk,
  input rw,
	input cs,
	input read,
  input [2:0] page,
  input [18:0] addr,
  input [7:0] data_in,
  output reg [7:0] data_out
);

reg [7:0] ram[0:1048575];

initial $readmemh("./roms/roms.mem", ram, 19'h10000);
/*initial $readmemh("./roms/rom1.mem", ram, 19'h20000);
initial $readmemh("./roms/rom2.mem", ram, 19'h30000);
initial $readmemh("./roms/rom3.mem", ram, 19'h40000);
initial $readmemh("./roms/rom4.mem", ram, 19'h50000);
*/
always @(posedge clk) begin
  if (!rw && cs) begin
    ram[addr] <= data_in;
  end
  if (read && cs) begin 
    data_out <= ram[addr];
  end else 
    data_out <= 8'b0;
end

endmodule
