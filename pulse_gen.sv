module pulse_sync1 (
    input  logic clka,
    input  logic clkb,
    input  logic rst_n_a,
    input  logic rst_n_b,
    input  logic pulse_in, 
    output logic pulse_out  
);

    logic  [2:0] sync_ff;       

    always_ff @(posedge clkb or negedge rst_n_b) 
	begin
        if (!rst_n_b) 
	begin
            sync_ff <= 3'b0;
        end 
	else 
	begin
            sync_ff <= {sync_ff[1:0], pulse_in};
        end
    end

    assign pulse_out = sync_ff[1] & ~sync_ff[2];

endmodule



module pulse_sync2 (
    input  logic clka,
    input  logic clkb,
    input  logic rst_n_a,
    input  logic rst_n_b,
    input  logic pulse_in,
    output logic pulse_out  
);

    logic  [2:0] sync_ff_b;
    logic  [2:0] sync_ff_a;

    always_ff @(posedge clkb or negedge rst_n_b) 
	begin
        if (! rst_n_b) 
	begin
            sync_ff_b <= 3'b0;
        end 
	else 
	begin
            sync_ff_b <= {sync_ff_b[1:0], sync_ff_a[2]};
        end
    end

    assign pulse_out = sync_ff_b[1] & ~ sync_ff_b[2];

    always_ff @(posedge clka or negedge rst_n_a) 
	begin
        if (! rst_n_a) 
	begin
            sync_ff_a <= 3'b0;
        end 
	else 
	begin
            sync_ff_a[0] <= pulse_in;
            sync_ff_a[1] <= pulse_in || sync_ff_a[0];
            sync_ff_a[2] <= pulse_in || sync_ff_a[1];
	end
    end


endmodule

module pulse_sync3 (
    input  logic clka,
    input  logic clkb,
    input  logic rst_n_a,
    input  logic rst_n_b,
    input  logic pulse_in,
    output logic pulse_out  
);

    logic  [2:0] sync_ff_b;
    logic  original_pulse;
    logic  [1:0] sync_ff_a;

    always_ff @(posedge clkb or negedge rst_n_b) 
	begin
        if (!rst_n_b) 
	begin
            sync_ff_b <= 3'b0;
        end 
	else 
	begin
            sync_ff_b <= {sync_ff_b[1:0], sync_ff_a[2]};
        end
    end

    assign pulse_out = sync_ff_b[1] & ~ sync_ff_b[2];

    always_ff @(posedge clka or negedge rst_n_a) 
	begin
        if (! rst_n_a) 
	begin
            original_pulse <= 0;
        end 
	else 
	begin
            original_pulse <= pulse_in || (~sync_ff_a[1] && original_pulse);
	end
    end

    always_ff @(posedge clka or negedge rst_n_a) 
	begin
        if (!rst_n_a) 
	begin
            sync_ff_a <= 2'b0;
        end 
	else 
	begin
            sync_ff_a <= {sync_ff_b[0], sync_ff_b[1]};
        end
    end


endmodule