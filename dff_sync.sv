//----------------------------------------------------------------------------------------------------
// Module name: dff_sync
// Author:      Refael Gantz
// Description: RTL simulation model of double ff synchronizer which models 1 cycle delay uncertainty on output.
//----------------------------------------------------------------------------------------------------

`timescale 1ps / 1ps
module  dff_sync #(WIDTH = 1) (
			     input  logic               clk,
			     input  logic               resetb,
			     input  logic [WIDTH-1:0]   d,
			     output logic [WIDTH-1:0]   q
			     );
  
  logic [WIDTH-1:0] q1;
  logic [WIDTH-1:0] q2;

  // dff uncertainty model
  //--------------------------------------------
  logic [WIDTH-1:0] rand_delay;
  logic [WIDTH-1:0] rand_flop;
  logic [WIDTH-1:0] d_delayed;
  
  always_ff @ (posedge clk or negedge resetb)
    if (~resetb)
      rand_flop <= '0;
    else
      rand_flop <= d;

  always
    begin
      #5ns;
      rand_delay = $random;
      for (int i = 0; i<WIDTH; i=i+1)
	d_delayed[i] = rand_delay[i] ? rand_flop[i] : d[i];
    end
  //--------------------------------------------
  
  always_ff @ (posedge clk or negedge resetb)
    if (~resetb)
      begin
	q1 <= '0;
	q2 <= '0;
      end
    else
      begin
	q1 <= d_delayed;
	q2 <= q1;
      end

  assign q = q2;
  
endmodule


