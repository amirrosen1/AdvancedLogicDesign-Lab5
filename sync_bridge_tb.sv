`timescale 1ns/1ns
module sync_bridge_tb();
	
	logic clka;
	logic clkb;
	logic data_req_clka;
	logic data_valid_clka;
	logic [7:0] din_clka;
	logic resetb_clkb;
	logic data_req_clkb;
	logic data_valid_clkb;
	logic [7:0] dout_clkb;
	logic [7:0] popped_data;
	integer queue1[$];	//Queue declaration

	// Instantiate the sync_bridge module
	sync_bridge sync_bridge (
		.clka(clka),
		.clkb(clkb),
		.resetb_clkb(resetb_clkb),
		.data_req_clkb(data_req_clkb),
		.data_valid_clka(data_valid_clka),
		.data_req_clka(data_req_clka),
		.data_valid_clkb(data_valid_clkb),
		.din_clka(din_clka),
		.dout_clkb(dout_clkb));

	 // Clock Generation
	always #6.25ns clka = ~clka;
	always #10ns clkb = ~clkb;

	// Synchronization Task
	task automatic sync();
		@(posedge clkb)
		#1ns;
	endtask

	// Random Input Generator
	function void randomize_inputs();
		din_clka = $random();
	endfunction 
	
	
	// Driver A - Mimicking Block A Behavior
	task automatic drive_a();
		@(posedge clka)
		randomize_inputs();
		data_valid_clka = 1'b1;
	endtask

	// Driver B - Mimicking Block B Behavior
	task automatic drive_b();
		sync();
		resetb_clkb = 1'b1;
		#20ns;
		sync();
		data_req_clkb = 1'b1;
	endtask		

	//MONITOR
	initial
		forever
			begin
				@(posedge clka);
					#1ns;
					if (data_valid_clka == 1'b1)
						queue1.push_back(din_clka);			end
		
	initial
		forever
			begin
				@(posedge clkb)
					#1ns; 
					if (data_valid_clkb == 1'b1)
						check_sync();
			end
							


	//CHECKER
	function void check_sync();
		popped_data = queue1.pop_front();
		if (popped_data != dout_clkb)
			$display("ERROR: Mismatch! Queue data = %b , dout_clkb = %b, (%d)", popped_data, dout_clkb, popped_data, dout_clkb);
		else if (popped_data == dout_clkb)
			$display("SUCCESS: Data transmitted correctly!");
	endfunction

	//CHECKER
	task automatic check_req_clka();
		fork
			begin
				wait (data_req_clka);
				$display("data_req_clka asserted correctly.");
			end

			begin
				#52ns;
				$display("ERROR: data_req_clka was not asserted in time!");
				$stop;
			end
		join_any
		disable fork;
	endtask
		
	initial
		begin
			{clka, clkb, resetb_clkb, data_req_clka, data_req_clkb, data_valid_clka, data_valid_clkb, din_clka, dout_clkb, popped_data}=0;
			#10ns;
			drive_b();
			check_req_clka();
			wait(data_req_clka);
			repeat (21) 
				drive_a(); 
			din_clka = 1'b0;
			#13ns;
			data_valid_clka = 1'b0;
			#1000ns;
			$stop;		
		end	
endmodule