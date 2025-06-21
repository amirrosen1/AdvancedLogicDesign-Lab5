// Parameters Declerations
parameter DATA_WIDTH = 8;
parameter PTR_WIDTH = 4;
parameter FIFO_DEPTH = 16;

// SYNC_BRIDGE MODULE
module  sync_bridge #(DATA_WIDTH = 8) (
			     input  logic clka,
			     input  logic clkb,
			     input  logic resetb_clkb,
			     input  logic data_req_clkb,
			     input  logic data_valid_clka,
			     output logic data_req_clka,
			     output logic data_valid_clkb,
			     input  logic [DATA_WIDTH-1:0] din_clka,
			     output logic [DATA_WIDTH-1:0] dout_clkb
			     );
  
	// Internal logic signals
	logic data_req_clkb_sync;
	logic resetb_clka;
	logic enable_write;
	logic fifo_full;
	logic fifo_empty;


        // Reset Synchronization
	dff_sync #(.WIDTH(1)) resetb_sync
	(
	.clk(clka),
	.resetb(resetb_clkb),
	.d(1'b1),
        .q(resetb_clka));


	// Synchronize data_req_clkb to clka domain
 	always_ff @ (posedge clkb or negedge resetb_clkb)
		if(~resetb_clkb)
			data_req_clkb_sync <= 1'b0;
		else
			data_req_clkb_sync <= data_req_clkb;


	dff_sync #(.WIDTH(1)) data_req_sync(
	.clk(clka),
	.resetb(resetb_clka),
	.d(data_req_clkb_sync),
	.q(data_req_clka));	


	// Write enable logic
	assign enable_write = ~fifo_full & data_valid_clka & resetb_clka & resetb_clkb;

    
	always_ff @ (posedge clkb or negedge resetb_clkb)
		if(~resetb_clkb)
			data_valid_clkb <= 1'b0;
		else
			data_valid_clkb <= ~fifo_empty;
	
	
	// Instantiate Asynchronous FIFO
	async_fifo #(.FIFO_DEPTH(16)) gna_fifo
			   (.wr_clk(clka),
	  		    .rd_clk(clkb),
			    .wr_resetb(resetb_clka),
                            .rd_resetb(resetb_clkb),
			    .wr_en(enable_write),
		            .rd_en(1'b1),
			    .wr_full(fifo_full),
		            .rd_empty(fifo_empty),
			    .wr_data(din_clka),	
		            .rd_data(dout_clkb)												);
endmodule // sync_bridge

// ASYNC_FIFO MODULE
module async_fifo #(FIFO_DEPTH = 16) (
			     input  logic wr_clk,
			     input  logic rd_clk,
			     input  logic wr_resetb,
			     input  logic rd_resetb,
			     input  logic wr_en,
			     input  logic rd_en,
			     output logic wr_full,
			     output logic rd_empty,
			     input  logic [DATA_WIDTH-1:0] wr_data,
			     output logic [DATA_WIDTH-1:0] rd_data
			     );

	logic [PTR_WIDTH-1:0] wr_ptr_bin;                 
	logic [PTR_WIDTH-1:0] wr_ptr_gray;                 
	logic [PTR_WIDTH-1:0] rd_ptr_bin;                  
	logic [PTR_WIDTH-1:0] rd_ptr_gray;                
	logic [PTR_WIDTH-1:0] wr_bin_ptr_next;            
	logic [PTR_WIDTH-1:0] rd_bin_ptr_next;             

	logic [PTR_WIDTH-1:0] wr_gray_ptr_comparator;	   
	logic [PTR_WIDTH-1:0] rd_gray_ptr_comparator;	   

	logic [PTR_WIDTH-1:0] wr_bin_ptr_comparator; 	   
	logic [PTR_WIDTH-1:0] rd_bin_ptr_comparator; 	   	

	
	bin2gray #(.PTR_WIDTH(4)) rd_ptr_b2g      
	(.bin_in(rd_ptr_bin),
	.gray_out(rd_ptr_gray));

	bin2gray #(.PTR_WIDTH(4)) wr_ptr_b2g      
	(.bin_in(wr_ptr_bin),
	.gray_out(wr_ptr_gray));



	

	// Create memory
	logic [DATA_WIDTH-1:0] mem[FIFO_DEPTH-1:0];       

	// Write memory
	always_ff @ (posedge wr_clk)
		if(wr_en & ~wr_full)
			mem[wr_ptr_bin] <= wr_data;

	// Read memory
	assign rd_data = (wr_resetb&rd_resetb) ? mem[rd_ptr_bin] : 8'b0;

	// wr_ptr increment
	always_ff@(posedge wr_clk or negedge wr_resetb)
		if(~wr_resetb)
			 wr_ptr_bin <= 4'b0;   
		else if (wr_en & ~ wr_full)
			wr_ptr_bin <= wr_bin_ptr_next;

	// rd_ptr increment
	always_ff@(posedge rd_clk or negedge rd_resetb)
		if(~rd_resetb)
			 rd_ptr_bin <= 4'b1111;     
		else if (rd_en & ~ rd_empty)
			rd_ptr_bin <= rd_bin_ptr_next;

	
	always_comb
		begin
			if(wr_ptr_bin < 4'b1111)
				wr_bin_ptr_next = wr_ptr_bin + 4'b0001;
			else
				wr_bin_ptr_next = 4'b0000;
			if(rd_ptr_bin < 4'b1111)
				rd_bin_ptr_next = rd_ptr_bin + 4'b0001;
			else
				rd_bin_ptr_next = 4'b0000;
		end

	dff_sync #(.WIDTH(4)) wr_ptr_sync 
		(.clk(rd_clk),
		.resetb(rd_resetb),
		.d(wr_ptr_gray),
		.q(wr_gray_ptr_comparator));

	gray2bin #(.PTR_WIDTH(4)) wr_comp_g2b
		(.gray_in(wr_gray_ptr_comparator),
		.bin_out(wr_bin_ptr_comparator));


	dff_sync #(.WIDTH(4)) rd_ptr_sync
		(.clk(wr_clk),
		.resetb(wr_resetb),
		.d(rd_ptr_gray),
		.q(rd_gray_ptr_comparator));

	gray2bin #(.PTR_WIDTH(4)) rd_comp_g2b
		(.gray_in(rd_gray_ptr_comparator),
		.bin_out(rd_bin_ptr_comparator));

	assign wr_full = (wr_bin_ptr_next == rd_bin_ptr_comparator);
	assign rd_empty = (rd_bin_ptr_next == wr_bin_ptr_comparator);

endmodule // async_fifo


module bin2gray #(PTR_WIDTH = 4)
		 (
		   input  logic [PTR_WIDTH-1:0]   bin_in,
		   output logic [PTR_WIDTH-1:0]   gray_out
		);

	function [PTR_WIDTH-1:0] binary2gray;
      		input [PTR_WIDTH-1:0] value;
      		integer idx;
     		begin 
       			  binary2gray[PTR_WIDTH-1] = value[PTR_WIDTH-1];
       			  for (idx = PTR_WIDTH-1; idx > 0; idx = idx - 1)
         			   binary2gray[idx - 1] = value[idx] ^ value[idx - 1];
     		end
   	endfunction // binary2gray

   	assign gray_out = binary2gray(bin_in);

endmodule //bin2gray


module gray2bin #(PTR_WIDTH = 4)
		 (
		   input  logic [PTR_WIDTH-1:0]   gray_in,
		   output logic [PTR_WIDTH-1:0]   bin_out
		);
	
	genvar idx;          		  
	generate 
     	for (idx=0; idx < PTR_WIDTH; idx = idx + 1) begin
        assign bin_out[idx] = ^ gray_in[PTR_WIDTH-1:idx];
      	end
   	endgenerate

endmodule //gray2bin