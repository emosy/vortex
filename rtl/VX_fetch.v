
`include "VX_define.v"

module VX_fetch (
	input  wire           clk,
	input  wire           reset,
	input  wire           in_branch_dir,
	input  wire           in_freeze,
	input  wire[31:0]     in_branch_dest,
	input  wire           in_branch_stall,
	input  wire           in_fwd_stall,
	input  wire           in_branch_stall_exe,
	input  wire           in_clone_stall,
	input  wire           in_jal,
	input  wire[31:0]     in_jal_dest,
	input  wire           in_interrupt,
	input  wire           in_debug,
	input  wire[31:0]     in_instruction,
	input  wire           in_thread_mask[`NT_M1:0],
	input  wire           in_change_mask,
	input  wire[`NW_M1:0] in_decode_warp_num,
	input  wire[`NW_M1:0] in_memory_warp_num,
	input  wire           in_wspawn,
	input  wire[31:0]     in_wspawn_pc,
	input  wire           in_ebreak,

	output wire[31:0]     out_instruction,
	output wire           out_delay,
	output wire[`NW_M1:0] out_warp_num,
	output wire[31:0]     out_curr_PC,
	output wire           out_valid[`NT_M1:0],
	output wire           out_ebreak,
	output wire[`NW_M1:0] out_which_wspawn
);

		reg       stall;
		reg[31:0] out_PC;

		reg[`NW_M1:0] warp_num;
		reg[`NW_M1:0] warp_state;
		reg[`NW_M1:0] warp_count;

		// reg[31:0] num_ecalls;

		initial begin
			warp_num   = 0;
			warp_state = 0;
			// num_ecalls = 0;
			warp_count = 1;
		end


		// always @(posedge clk) begin
		// 	if (in_ebreak) begin
		// 		num_ecalls <= num_ecalls + 1;
		// 		$display("--------> New num_ecalls = %h", num_ecalls+1);
		// 	end
		// end

		wire add_warp    = in_wspawn && !in_ebreak && !in_clone_stall;
		wire remove_warp = in_ebreak && !in_wspawn && !in_clone_stall;

		always @(posedge clk or posedge reset) begin
			if (reset || (warp_num >= warp_state) || remove_warp || add_warp) begin
				warp_num   <= 0;
			`ifndef ONLY
			end else if (!warp_glob_valid[warp_num+1]) begin
				// $display("Skipping one");
				warp_num   <= warp_num + 2;
			`endif
			end else begin
				warp_num   <= warp_num + 1;
			end

			if (add_warp) begin
				warp_state <= warp_state + 1;
				warp_count <= warp_count + 1;
				// $display("Adding a new warp %h", warp_state+1);
			end else if (remove_warp) begin // No removing, just invalidating
				warp_count <= warp_count - 1;
				// $display("Removing a warp %h %h", in_decode_warp_num, warp_count);
				if (warp_count == 2) begin
					// $display("&&&&&&&&&&&&& STATE 0");
					warp_state <= 0;
				end
			end
		end

		assign out_ebreak = (in_decode_warp_num == 0) && in_ebreak;


		assign stall = in_clone_stall || in_branch_stall || in_fwd_stall || in_branch_stall_exe || in_interrupt || in_freeze || in_debug;

		assign out_which_wspawn = (warp_state+1);

		`ifdef ONLY

			wire       warp_zero_change_mask = in_change_mask && (in_decode_warp_num == 0);
			wire       warp_zero_jal         = in_jal         && (in_memory_warp_num == 0);
			wire       warp_zero_branch      = in_branch_dir  && (in_memory_warp_num == 0);
			wire       warp_zero_stall       = stall          || (warp_num != 0);
			wire       warp_zero_wspawn      = (0 == 0) ? 0 : (in_wspawn && ((warp_state+1) == 0));
			wire[31:0] warp_zero_wspawn_pc   = in_wspawn_pc;
			wire       warp_zero_remove      = remove_warp && (in_decode_warp_num == 0);

			// always @(*) begin : proc_
			// 	if (warp_zero_remove) $display("4Removing warp: %h", 0);
			// end

			VX_warp VX_Warp(
				.clk           (clk),
				.reset         (reset),
				.stall         (warp_zero_stall),
				.remove        (warp_zero_remove),
				.in_thread_mask(in_thread_mask),
				.in_change_mask(warp_zero_change_mask),
				.in_jal        (warp_zero_jal),
				.in_jal_dest   (in_jal_dest),
				.in_branch_dir (warp_zero_branch),
				.in_branch_dest(in_branch_dest),
				.in_wspawn     (warp_zero_wspawn),
				.in_wspawn_pc  (warp_zero_wspawn_pc),
				.out_PC        (out_PC),
				.out_valid     (out_valid)
				);

		`else 

			wire[31:0] warp_glob_pc[`NW-1:0];
			wire       warp_glob_valid[`NW-1:0][`NT_M1:0];
			genvar cur_warp;
			generate
				for (cur_warp = 0; cur_warp < `NW; cur_warp = cur_warp + 1)
				begin
					wire       warp_zero_change_mask = in_change_mask && (in_decode_warp_num == cur_warp);
					wire       warp_zero_jal         = in_jal         && (in_memory_warp_num == cur_warp);
					wire       warp_zero_branch      = in_branch_dir  && (in_memory_warp_num == cur_warp);
					wire       warp_zero_stall       = stall          || (warp_num != cur_warp);
					wire       warp_zero_wspawn      = (cur_warp == 0) ? 0 : (in_wspawn && ((warp_state+1) == cur_warp));
					wire[31:0] warp_zero_wspawn_pc   = in_wspawn_pc;
					wire       warp_zero_remove      = remove_warp && (in_decode_warp_num == cur_warp);

					// always @(*) begin : proc_
					// 	if (warp_zero_remove) $display("4Removing warp: %h", cur_warp);
					// end

					VX_warp VX_Warp(
						.clk           (clk),
						.reset         (reset),
						.stall         (warp_zero_stall),
						.remove        (warp_zero_remove),
						.in_thread_mask(in_thread_mask),
						.in_change_mask(warp_zero_change_mask),
						.in_jal        (warp_zero_jal),
						.in_jal_dest   (in_jal_dest),
						.in_branch_dir (warp_zero_branch),
						.in_branch_dest(in_branch_dest),
						.in_wspawn     (warp_zero_wspawn),
						.in_wspawn_pc  (warp_zero_wspawn_pc),
						.out_PC        (warp_glob_pc[cur_warp]),
						.out_valid     (warp_glob_valid[cur_warp])
						);
				end
			endgenerate


			reg[31:0] out_PC_var;
			reg      out_valid_var[`NT_M1:0];

			always @(*) begin : help
				integer g;
				integer h;
				for (g = 0; g < `NW; g = g + 1)
				begin
					if (warp_num == g[`NW_M1:0])
					begin
						 out_PC_var    = warp_glob_pc[g][31:0];
						 for (h = 0; h < `NT; h = h + 1) out_valid_var[h] = warp_glob_valid[g][h];
					end
				
				end
			end

			assign out_PC    = out_PC_var;
			assign out_valid = out_valid_var;

			// always @(*) begin
			// 	if (out_valid[0]) begin
			// 		$display("[%d] %h #%b#",out_warp_num, out_PC, out_valid);
			// 	end
			// end

		`endif




		assign out_curr_PC     = out_PC;
		assign out_warp_num    = warp_num;
		assign out_delay       = 0;

		assign out_instruction = stall ? 32'b0 : in_instruction;



endmodule