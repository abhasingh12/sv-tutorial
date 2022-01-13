// Greg Stitt
// University of Florida
//
// This file illustrates how to create a controller and datapath to implement
// a higher-level algorithm. See bit_diff.pdf for an illustration of the
// different implementations.
//
// The algorithm being implemented is a bit-difference calculator. Given a
// parameter for a specified WIDTH, the modules calculate the difference
// between the number of 1s and 0s. E.g., if there are 3 more 1s than 0s, the
// out is 3. If there are 3 more 0s than 1s, the output is -3.
//
// Note: There are dozens of ways of implementing the bit difference
// calculator. The following examples are not necessarily the most efficient,
// and are simply used to introduce the FSMD and FSM+D models. 
//
// The examples illustrate two different categories of controller+datapath
// strategies: FSMDs and FSM+Ds. An FSMD specifies the controller and datapath
// in a combined behavioral description. An FSM+D specifies an explicit datapath
// and a separate controller, which are then connected together.
//
// FSMDs are demonstrated in two ways: a 1-process and 2-process model. Similar
// to the FSMs, the 1-process model registers everything and the 2-process
// model provides the flexibility to decide what is registered and what isn't.

/*=============================================================================
 Parameter Descriptions
 
 WIDTH : An integer representing the bits of the input data (should be > 0) 
 ===============================================================================

 ===============================================================================
 Interface Description (all control inputs are active high)

 --- INPUTS ---
 clk   : Clock
 rst   : Asynchronous reset
 go    : Asserting starts the calculator for the specific data input. Has no
 impact when the module is currently active (!done).
 data  : The input to be used to calculate the bit difference
 
 --- OUTPUTS ---
 result : The calculated result. Is valid when done is asserted.
 done : Asserted when the result output is valid. Remains asserted indefinitely
 until go is asserted again, and then is cleared on the next cycle.
 ============================================================================ */


////////////////////////////////////////////////////////////////////////////
// FSMD implementations

// Module: bit_dff_fsmd_1p
// Description: A 1-process FSMD implementation of the calculator.
//
// See the FSMD illustration in bit_diff.pdf for a graphical representation
// of this module.

module bit_diff_fsmd_1p
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
   
    // The range of results can be from WIDTH to -WIDTH, which is
    // 2*WIDTH + 1 possible values, where the +1 includes 0.
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );
   
   typedef enum 				{START, COMPUTE, RESTART} state_t;
   // We only have one process, so we'll only have a state_r variable.
   state_t state_r;

   // Create variables for the internal registers.
   logic [$bits(data)-1:0] 			data_r;
   logic [$bits(result)-1:0] 			result_r;
   logic [$clog2(WIDTH)-1:0] 			count_r;
   logic signed [$clog2(2*WIDTH+1)-1:0] 	diff_r;
   logic 					done_r;

   // These concurrent assignments aren't necessary, but they preserve the 
   // naming convention of having all registers use a _r suffix without 
   // requiring the outputs to have the suffix. I prefer to not name the
   // outputs based on the internal representation for several reasons. First,
   // there may be parameters for a module that change whether or not the
   // output is registered, which could make the suffix misleading. Second,
   // the user of the module usually doesn't need to know if an output is
   // registered. They might need to know the timing, but that can be specified
   // in documentation, which is more meaningful than just knowing the 
   // existence of a register. Finally, retiming might move all the registers
   // anyway, in which case there might not be a register on the output.
   //
   // For simple modules, this convention is overkill, but becomes useful when
   // using large modules because every variable that appears on the LHS of
   // an assignment within an always_ff should have a _r suffix. If you
   // accidentally assign a signal that isn't intended to be a register, then
   // the naming convention helps catch that mistake.
   assign result = result_r;
   assign done = done_r;

   // In the 1-process FSMD, everything is captured in a single always block.
   // It doesn't have to be an always_ff block in case there is combinational
   // logic mixed into the assignments, but use the always_ff when possible.
   always_ff @(posedge clk or posedge rst) begin
      if (rst == 1'b1) begin	 
	 
	 result_r <= '0;
	 done_r <= 1'b0;	 	 
	 diff_r <= '0;	 
	 count_r <= '0;
	 data_r <= '0;	 
	 state_r <= START;	 
      end
      else begin

	 done_r <= 1'b0;
	 
	 case (state_r)
	   START : begin

	      // Assign outputs.
	      done_r <= 1'b0;
	      result_r <= '0;
	      
	      // Initialize internal state.
	      diff_r <= '0;
	      count_r <= '0;
	      data_r <= data;

	      // Wait for go to be asserted.
	      if (go == 1'b1) state_r <= COMPUTE;	       
	   end

	   COMPUTE : begin

	      // Add one to the difference if asserted, else subtract one.
	      diff_r <= data_r[0] == 1'b1 ? diff_r + 1'b1 : diff_r - 1'b1;	  

	      // Shift out the current lowest bit.
	      data_r <= data_r >> 1;
	      count_r <= count_r + 1'b1;

	      // We are done after checking WIDTH bits. The -1 is used because
	      // the count_r assignment is non-blocking, which means that
	      //  count_r hasn't been updated with the next value yet. 
	      // When subtracting from a variable, this would create an 
	      // extra subtractor, which we definitely want to avoid. However, 
	      // in this case, WIDTH is a parameter, which is treated as a 
	      // constant. Synthesis will do constant propagation and replace 
	      // WIDTH-1 with a constant, so this will just be a comparator.
	      //
	      // We could also use a blocking assignment in the previous
	      // statement and then get rid of the -1, but since this is an
	      // always_ff block, it could introduce warnings.
	      if (count_r == WIDTH-1) state_r <= RESTART; 
	   end

	   // This state could easily be combined with START, but was done
	   // this way on purpose to match the FSM+D version, where done is
	   // not registered.
	   RESTART : begin
	      // Assign outputs.
	      result_r <= diff_r;
	      done_r <= 1'b1;

	      // Reset internal state.
	      diff_r <= '0;
	      count_r <= '0;
	      data_r <= data;
	      
	      if (go == 1'b1) begin
		 // If we don't clear done here, then we'll get an assertion
		 // error because it will take an extra cycle for done to be
		 // cleared after the circuit is restarted.
		 done_r <= 1'b0;		 
		 state_r <= COMPUTE;
	      end
	   end
	 endcase	  
      end      
   end   
endmodule


// Module: bit_diff_fsmd_2p
// Description: This module implements a 2-process version of the FSMD.

module bit_diff_fsmd_2p
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   typedef enum 				{START, COMPUTE, RESTART} state_t;

   // For a 2-process FSMD, every register needs a variable for the output of
   // the register, which is the current value represented by the _r suffix,
   // and a variable for the input to the register (i.e., the value for the
   // next cycle), which is determined by combinational logic.
   state_t state_r, next_state;
   logic [$bits(data)-1:0] 			data_r, next_data;
   logic [$bits(result)-1:0] 			result_r, next_result;
   logic [$clog2(WIDTH)-1:0] 			count_r, next_count;
   logic signed [$clog2(2*WIDTH+1)-1:0] 	diff_r, next_diff;

   assign result = result_r;
   
   // The first process simply implements all the registers.
   // Done is now combinational logic, so it doesn't appear here.
   always_ff @(posedge clk or posedge rst) begin
      if (rst == 1'b1) begin
	 result_r <= '0;
	 diff_r <= '0;	 
	 count_r <= '0;
	 data_r <= '0;	 
	 state_r <= START;	 
      end
      else begin
	 result_r <= next_result;
	 diff_r <= next_diff;
	 count_r <= next_count;
	 data_r <= next_data;
	 state_r <= next_state;
      end 
   end 

   // The second process implements any combinational logic, which includes
   // the inputs to all the registers, and any other combinational logic. For
   // example, in this module the done output is not registered like in the
   // the 1-process model. Although the 2-process model seems like overkill for
   // this example, the advantage is that you can control exactly what is
   // registered. For complex designs, registering everything is usually not
   // ideal, which makes the 2-process model version.
   always_comb begin
      
      logic [$bits(diff_r)-1:0] diff_temp;
      
      // Since this is combinational logic, we should never be assigning a
      // _r version of the signals. The left hand side should either be a next_
      // signal, or other variables that correspond to combinational logic.
      //
      // Here we assign default values to all the register inputs to make sure
      // we don't have latches. For a register, a good default value is usually
      // the current value because then we only have to assign the signal later
      // if the register is going to change.
      next_result = result_r;
      next_diff = diff_r;
      next_data = data_r;
      next_count = count_r;
      next_state = state_r;

      // Done is combinational logic in this module, so it doesn't have a 
      // "next" version. 
      done = 1'b0;
      
      case (state_r)	
	START : begin	   
	   done <= 1'b0;
	   next_result = '0;	   
	   next_diff <= '0;
	   next_data <= data;
	   next_count <= '0;

	   // Without the default assignment at the beginning of the block,
	   // this would result in a latch in the 2-process FSMD.
	   if (go == 1'b1) next_state <= COMPUTE;	       
	end
	
	COMPUTE : begin	

	   // NOTE: the commented line causes an infinite simulation loop.
	   // The reason for the loop is that an always_comb block adds
	   // any signal on the RHS of a statement to the sensitivity list.
	   // Later on, next_diff is used on the RHS, so it becomes both
	   // an input and output from this block.
	   //next_diff = data_r[0] == 1'b1 ? diff_r + 1 : diff_r - 1;

	   // To avoid the simulation loop, we simply use a temporary
	   // variable declared inside the always block.
	   diff_temp = data_r[0] == 1'b1 ? diff_r + 1'b1 : diff_r - 1'b1;
	   next_diff = diff_temp;	   
	   next_data = data_r >> 1;
	   next_count = count_r + 1'b1;

	   // Here, we could compare with next_count also and get rid of the
	   // -1. However, that would be non-ideal for two reasons. First,
	   // The addition for the count becomes an input to the comparator
	   // without a register in between, which could increase the the
	   // length of the critical path and slow down the clock. Second,
	   // the count variable would need an extra bit for the new condition
	   // to ever be true, which would increase the size of the adder, the
	   // comparator, and the register. 
	   if (count_r == WIDTH-1) begin
	      next_state = RESTART;

	      // For us to be able to assert done in the next cycle, we need
	      // to send it to the result register this cycle. Also, we need
	      // to use the next version of diff since the register won't be
	      // updated yet.
	      //
	      // Note that we are using diff_temp here instead of next_diff
	      // to avoid the infinite simulation loop.
	      next_result = diff_temp;
	   end
	end

	// The restart state is now identical to the start state with the
	// exception of the done signal, which is now asserted. Basically, the
	// logic for done has been moved from a separate register into logic
	// based on the state register.
	RESTART : begin	  
	   done <= 1'b1;	   	   
	   next_diff <= '0;
	   next_count <= '0;
	   next_data <= data;

	   // Since done is now combinational logic, we don't want to clear it
	   // here otherwise it will be cleared in the same cycle that go
	   // is asserted. If that is desired behavior, it is fine to do so,
	   // but the specification for this module requires done to be cleared
	   // one cycle after the assertion of go.
	   //
	   // One reason to avoid clearing done within the same cycle as go is
	   // that if the logic for go outside this module depends on done,
	   // it creates a combinational loop. The 1-cycle delay avoids that
	   // problem.
	   if (go == 1'b1) next_state = COMPUTE;
	end
      endcase	  
   end      
endmodule


////////////////////////////////////////////////////////////////////////////
// FSM+D implementations


// Misc modules needed for a structural datapath

module register
  #(
    parameter WIDTH
    )
   (
    input logic 	     clk,
    input logic 	     rst,
    input logic 	     en,
    input logic [WIDTH-1:0]  in,
    output logic [WIDTH-1:0] out
    );

   always_ff @(posedge clk or posedge rst) begin      
      if (rst)
	out <= '0;
      else if (en)
	out <= in;
   end
endmodule

module mux2x1
  #(
    parameter WIDTH
    )
   (
    input logic [WIDTH-1:0]  in0,
    input logic [WIDTH-1:0]  in1,
    input logic 	     sel,
    output logic [WIDTH-1:0] out
    );

   assign out = sel == 1'b1 ? in1 : in0;

endmodule

module add
  #(
    parameter WIDTH
    )
   (
    input logic [WIDTH-1:0]  in0, in1,
    output logic [WIDTH-1:0] sum
    );

   assign sum = in0 + in1;
   
endmodule

module shift_right
  #(
    parameter WIDTH,
    parameter SHIFT_AMOUNT
    )
   (
    input logic [WIDTH-1:0]  in,
    output logic [WIDTH-1:0] out
    );

   assign out = in >> SHIFT_AMOUNT;
   
endmodule

module eq
  #(
    parameter WIDTH   
    )
   (
    input logic [WIDTH-1:0] in0, in1,
    output logic 	    out
    );

   assign out = in0 == in1 ? 1'b1 : 1'b0;
   
endmodule


// Module: datapath1
// Description: This module creates the illustrated datapath structurally.
//
// See bit_diff.pdf for a graphical illustration of this datapath.

//`default_nettype none
module datapath1
  #(
    parameter WIDTH
    )
   (
    input 				 var logic clk,
    input 				 var logic rst,
    input 				 var logic [WIDTH-1:0] data, 
    input 				 var logic data_sel,
    input 				 var logic data_en,
    input 				 var logic diff_sel,
    input 				 var logic diff_en,
    input 				 var logic count_sel,
    input 				 var logic count_en,
    input 				 var logic result_en,
    output logic 			 count_done,
    output logic [$clog2(WIDTH*2+1)-1:0] result
    );

   localparam int 			 DIFF_WIDTH = $clog2(WIDTH*2 + 1);
   
   logic [WIDTH-1:0] 			 data_mux, data_r, data_shift;
   logic [DIFF_WIDTH-1:0] 		 diff_r, add_in1_mux, diff_add, diff_mux;
   
   // Mux that defines provides input to the data register.
   mux2x1 #(.WIDTH(WIDTH)) DATA_MUX (.in0(data_shift), 
				     .in1(data), 
				     .sel(data_sel),
				     .out(data_mux));

   // The data register.
   register #(.WIDTH(WIDTH)) DATA_REG (.en(data_en), 
				       .in(data_mux), 
				       .out(data_r), 
				       .*);
   // Shifter for the data register.
   shift_right #(.WIDTH(WIDTH), 
		 .SHIFT_AMOUNT(1)) DATA_SHIFT (.in(data_r), 
					       .out(data_shift));         

   // Selects between a 1 or -1 input to the adder.
   mux2x1 #(.WIDTH(DIFF_WIDTH)) ADD_MUX(.in0(DIFF_WIDTH'(-1)), 
					.in1(DIFF_WIDTH'(1)), 
					.sel(data_r[0]),
					.out(add_in1_mux));
   
   // Adds the current difference with the output of the add_in1_mux (1 or -1).
   add #(.WIDTH(DIFF_WIDTH)) DIFF_ADD (.in0(diff_r),
				       .in1(add_in1_mux),
				       .sum(diff_add));
   
   // Selects between 0 or the diff adder.
   mux2x1 #(.WIDTH(DIFF_WIDTH)) DIFF_MUX (.in0(diff_add), 
					  .in1(DIFF_WIDTH'(0)), 
					  .sel(diff_sel),
					  .out(diff_mux));

   // The diff register.
   register #(.WIDTH(DIFF_WIDTH)) DIFF_REG (.en(diff_en), 
					    .in(diff_mux), 
					    .out(diff_r), 
					    .*);
   
   // The result register.
   register #(.WIDTH(DIFF_WIDTH)) RESULT_REG (.en(result_en), 
					      .in(diff_mux), 
					      .out(result), 
					      .*);
   
   /*********************************************************************/
   // Counter logic

   logic [WIDTH-1:0] 			 count_mux, count_add, count_r;
   
   // Selects between 0 and the count adder.
   mux2x1 #(.WIDTH(WIDTH)) COUNT_MUX (.in0(count_add), 
				      .in1(WIDTH'(0)), 
				      .sel(count_sel),
				      .out(count_mux));

   // Register for the count.
   register #(.WIDTH(WIDTH)) COUNT_REG (.en(count_en), 
					.in(count_mux), 
					.out(count_r), 
					.*);

   // Increments the count.
   add #(.WIDTH(WIDTH)) COUNT_ADD (.in0(WIDTH'(1)),
				   .in1(count_r),
				   .sum(count_add));
   
   // Comparator to check when the count is complete. Equivalent to
   // count_r == WIDTH-1 from the FSMD.
   eq #(.WIDTH(WIDTH)) EQ (.in0(count_r),
			   .in1(WIDTH'(WIDTH-1)),
			   .out(count_done));   
   
endmodule
//`default_nettype wire   


// Module: datapath2
// Description: This module implements the same datapath but much more concisely
// using behavioral logic. This is the preferred style for a simple module,
// as long as the designer understands how behavior gets synthesized (see
// sequential logic section of tutorial).
//
// See bit_diff.pdf for a graphical illustration of this datapath.

module datapath2
  #(
    parameter WIDTH
    )
   (
    input logic 			 clk,
    input logic 			 rst,
    input logic [WIDTH-1:0] 		 data, 
    input logic 			 data_sel,
    input logic 			 data_en,
    input logic 			 diff_sel,
    input logic 			 diff_en,
    input logic 			 count_sel,
    input logic 			 count_en,
    input logic 			 result_en,
    output logic 			 count_done,
    output logic [$clog2(WIDTH*2+1)-1:0] result
    );

   localparam int 			 DIFF_WIDTH = $clog2(WIDTH*2 + 1);
   
   logic [WIDTH-1:0] 			 data_mux, data_r, data_shift;
   logic [DIFF_WIDTH-1:0] 		 diff_r, add_in1_mux, diff_add, diff_mux, result_r;
   logic [WIDTH-1:0] 			 count_mux, count_add, count_r;

   // Data mux and shift
   assign data_mux = data_sel ? data : data_shift;
   assign data_shift = data_r >> 1;

   // Add mux, diff adder, and diff mux
   assign add_in1_mux = data_r[0] ? DIFF_WIDTH'(1) : DIFF_WIDTH'(-1);
   assign diff_add = diff_r + add_in1_mux;
   assign diff_mux = diff_sel ? DIFF_WIDTH'(0) : diff_add;  

   // Count mux, add, and done
   assign count_mux = count_sel ? WIDTH'(0) : count_add;
   assign count_add = count_r + 1'b1;
   assign count_done = count_r == WIDTH'(WIDTH-1);

   // Not necessary, but complies with my _r naming convention for registers
   // created in an always block.
   assign result = result_r;

   // Create the registers behaviorally.
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
	 data_r <= '0;
	 diff_r <= '0;
	 result_r <= '0;
	 count_r <= '0;	 
      end
      else begin
	 if (data_en) data_r <= data_mux;
	 if (diff_en) diff_r <= diff_mux;
	 if (result_en) result_r <= diff_mux;
	 if (count_en) count_r <= count_mux;		 
      end      
   end
   
endmodule


// Module: fsm1
// Description: Finite-state machine controller for datapaths 1 and 2 to
// implement the same algorithm as the FSMD versions. In this controller,
// we simply replace the previous datapath operations from the FSMD with
// explicit control signals that configure the datapath to do the same thing.

module fsm1
  (
   input logic 	clk,
   input logic 	rst,
   input logic 	go,
   input logic 	count_done,
   output logic done,
   output logic data_sel,
   output logic data_en,
   output logic diff_sel,
   output logic diff_en,
   output logic count_sel,
   output logic count_en,
   output logic result_en
   );
   
   typedef enum {START, COMPUTE, RESTART} state_t;
   state_t state_r, next_state;

   always_ff @(posedge clk or posedge rst) begin
      if (rst) state_r <= START;
      else state_r <= next_state;      
   end

   always_comb begin

      done = 1'b0;

      result_en = 1'b0;
      diff_en = 1'b0;
      count_en = 1'b0;
      data_en = 1'b0;

      diff_sel = 1'b0;
      count_sel = 1'b0;
      data_sel = 1'b0;

      next_state = state_r;
            
      case (state_r)
	START : begin
	   
	   // Replaces diff_r <= '0;
	   diff_en = 1'b1;
	   diff_sel = 1'b1;
	   
	   // Replaces count_r <= '0;
	   count_en = 1'b1;
	   count_sel = 1'b1;
	   
	   // Replaces data_r <= data;
	   data_en = 1'b1;
	   data_sel = 1'b1;	  
	   
	   if (go) next_state = COMPUTE;
	end

	COMPUTE : begin
	   
	   // Selects are 1'b0 by default and don't have to be respecified here.
	   
	   // Replaces diff_r <= data_r[0] == 1'b1 ? diff_r + 1 : diff_r - 1;
	   diff_en = 1'b1;

	   // Replaces data_r <= data_r >> 1;
	   data_en = 1'b1;

	   // Replaces count_r <= count_r + 1;
	   count_en = 1'b1;

	   // Replaces count_r == WIDTH-1
	   if (count_done) begin
	      // Enable the result register one cycle early to make sure it
	      // aligns with the assertion of done.
	      result_en = 1'b1;	      
	      next_state = RESTART;
	   end
	end

	RESTART : begin
	   // Assert done in this state.
	   done = 1'b1;

	   // Replaces diff_r <= '0;
	   diff_en = 1'b1;
	   diff_sel = 1'b1;
	   
	   // Replaces count_r <= '0;
	   count_en = 1'b1;
	   count_sel = 1'b1;
	   
	   // Replaces data_r <= data
	   data_en = 1'b1;
	   data_sel = 1'b1;	  

	   if (go) next_state = COMPUTE;	   
	end	
      endcase            
   end 
endmodule


// Module: bit_diff_fsm_plus_d1
// Description: FSM+D implementation 1, which simply connects datapath 1 and
// fsm1.

module bit_diff_fsm_plus_d1
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   logic 					count_done;   
   logic 					data_sel;
   logic 					data_en;
   logic 					diff_sel;
   logic 					diff_en;
   logic 					count_sel;
   logic 					count_en;
   logic 					result_en;
   
   
   fsm1 CONTROLLER (.*);
   datapath1 #(.WIDTH(WIDTH)) DATAPATH (.*);
   
endmodule // bit_diff_fsm_plus_d1


// Module: bit_diff_fsm_plus_d2
// Description: FSM+D implementation 2, which simply connects datapath 2 and
// fsm1.

module bit_diff_fsm_plus_d2
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   logic 					count_done;   
   logic 					data_sel;
   logic 					data_en;
   logic 					diff_sel;
   logic 					diff_en;
   logic 					count_sel;
   logic 					count_en;
   logic 					result_en;
   
   
   fsm1 CONTROLLER (.*);
   datapath2 #(.WIDTH(WIDTH)) DATAPATH (.*);
   
endmodule // bit_diff_fsm_plus_d2


// Module: datapath3
// Description: An alternate datapath that eliminates the diff mux and count
// mux by replacing the selects with a reset.
//
// See bit_diff.pdf for a graphical illustration of this datapath.

module datapath3
  #(
    parameter WIDTH
    )
   (
    input 				 var logic clk,
    input 				 var logic rst,
    input 				 var logic [WIDTH-1:0] data, 
    input 				 var logic data_sel,
    input 				 var logic data_en,
    input 				 var logic diff_rst,
    input 				 var logic diff_en,
    input 				 var logic count_rst,
    input 				 var logic count_en,
    input 				 var logic result_en,
    output logic 			 count_done,
    output logic [$clog2(WIDTH*2+1)-1:0] result
    );

   localparam int 			 DIFF_WIDTH = $clog2(WIDTH*2 + 1);
   
   logic [WIDTH-1:0] 			 data_mux, data_r, data_shift;
   logic [DIFF_WIDTH-1:0] 		 diff_r, add_in1_mux, diff_add, result_r;
   logic [WIDTH-1:0] 			 count_add, count_r;
   
   assign data_mux = data_sel ? data : data_shift;
   assign data_shift = data_r >> 1;
   
   assign add_in1_mux = data_r[0] ? DIFF_WIDTH'(1) : DIFF_WIDTH'(-1);
   assign diff_add = diff_r + add_in1_mux;

   assign count_add = count_r + 1'b1;
   assign count_done = count_r == WIDTH'(WIDTH-1);

   assign result = result_r;

   // Registers tied to the global reset.
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
	 data_r <= '0;
	 result_r <= '0;
      end
      else begin
	 if (data_en) data_r <= data_mux;
	 if (result_en) result_r <= diff_add;
      end      
   end

   // Register for counter, which has its own reset.
   // This eliminates the need for the count_mux.
   always_ff @(posedge clk or posedge count_rst) begin
      if (count_rst) count_r <= '0;	 
      else if (count_en) count_r <= count_add;      
   end

   // Register for diff, which has its own reset.
   // This eliminates the need for the diff_mux.
   always_ff @(posedge clk or posedge diff_rst) begin
      if (diff_rst) diff_r <= '0;	 
      else if (count_en) diff_r <= diff_add;      
   end
   
endmodule


// Module: fsm2
// Description: Updated FSM to work with datapath3, which uses separate resets
// for the diff and count registers to eliminate the previous muxes.

module fsm2
  (
   input logic 	clk,
   input logic 	rst,
   input logic 	go,
   input logic 	count_done,
   output logic done,
   output logic data_sel,
   output logic data_en,
   output logic diff_rst,
   output logic diff_en,
   output logic count_rst,
   output logic count_en,
   output logic result_en
   );
   
   typedef enum {START, COMPUTE, RESTART} state_t;
   state_t state_r, next_state;

   always_ff @(posedge clk or posedge rst) begin
      if (rst) state_r <= START;
      else state_r <= next_state;      
   end

   always_comb begin

      done = 1'b0;

      result_en = 1'b0;
      diff_en = 1'b0;
      count_en = 1'b0;
      data_en = 1'b0;

      data_sel = 1'b0;

      // Use resets now instead of selects.
      diff_rst = 1'b0;
      count_rst = 1'b0;

      next_state = state_r;
      
      case (state_r)
	START : begin

	   // Replaces diff_r <= '0;
	   diff_rst = 1'b1;
	   
	   // Replaces count_r <= '0;
	   count_rst = 1'b1;
	   
	   // Replaces data_r <= data
	   data_en = 1'b1;
	   data_sel = 1'b1;	  
	   
	   if (go) next_state = COMPUTE;
	end

	COMPUTE : begin
	   
	   // Replaces diff_r <= data_r[0] == 1'b1 ? diff_r + 1 : diff_r - 1;  
	   diff_en = 1'b1;

	   // Replaces data_r <= data_r >> 1;
	   data_en = 1'b1;

	   // Replaces count_r <= count_r + 1;
	   count_en = 1'b1;

	   // Replaces count_r == WIDTH-1
	   if (count_done) begin
	      result_en = 1'b1;	      
	      next_state = RESTART;
	   end
	end

	RESTART : begin
	   done = 1'b1;

	   // Replaces diff_r <= '0;
	   diff_rst = 1'b1;
	   
	   // Replaces count_r <= '0;
	   count_rst = 1'b1;
	   
	   // Replaces data_r <= data
	   data_en = 1'b1;
	   data_sel = 1'b1;	  

	   if (go) next_state = COMPUTE;	   
	end	
      endcase            
   end 
endmodule


// Module: bit_diff_fsm_plus_d3
// Description: Combines datapath3 and fsm2 to create an FSM+D.
//
// NOTE: This module might not always be safe. The controller is using
// combinational logic to control asynchronous resets within the datapath.
// If there are ever glitches on the combinational logic, it could potentially
// cause problems.
//
// One potential fix would be to change the datapath to use synchronous resets,
// but for most FPGAs, that would just add back in the original muxes we wanted
// to remove.

module bit_diff_fsm_plus_d3
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   logic 					count_done;   
   logic 					data_sel;
   logic 					data_en;
   logic 					diff_rst;
   logic 					diff_en;
   logic 					count_rst;
   logic 					count_en;
   logic 					result_en;
   
   fsm2 CONTROLLER (.*);
   datapath3 #(.WIDTH(WIDTH)) DATAPATH (.*);
   
endmodule // bit_diff_fsm_plus_d3


// Module: fsm3
// Descrition: This FSM modifies fsm2 by registering the diff and count reset
// signals. These registers unfortunately require an extra INIT state to delay
// the start of the computation by a cycle. However, it does provide a safer
// reset strategy.

module fsm3
  (
   input logic 	clk,
   input logic 	rst,
   input logic 	go,
   input logic 	count_done,
   output logic done,
   output logic data_sel,
   output logic data_en,
   output logic diff_rst,
   output logic diff_en,
   output logic count_rst,
   output logic count_en,
   output logic result_en
   );
   
   typedef enum {START, INIT, COMPUTE, RESTART} state_t;
   state_t state_r, next_state;

   logic 	count_rst_r, next_count_rst;
   logic 	diff_rst_r, next_diff_rst;

   // Register the controlled asynchronous resets to be safer.
   assign count_rst = count_rst_r;
   assign diff_rst = diff_rst_r;
   
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
	 state_r <= START;
	 count_rst_r <= 1'b1;
	 diff_rst_r <= 1'b1;	 
      end
      else begin
	 state_r <= next_state;
	 count_rst_r <= next_count_rst;
	 diff_rst_r <= next_diff_rst;	 
      end
   end

   always_comb begin

      done = 1'b0;

      result_en = 1'b0;
      diff_en = 1'b0;
      count_en = 1'b0;
      data_en = 1'b0;

      data_sel = 1'b0;

      next_diff_rst = 1'b0;
      next_count_rst = 1'b0;

      next_state = state_r;
      
      case (state_r)
	START : begin

	   next_diff_rst = 1'b1;	 
	   next_count_rst = 1'b1;
	   data_en = 1'b1;
	   data_sel = 1'b1;	  
	   
	   if (go) next_state = INIT;
	end

	// We need this extra state to allow time for the registered resets
	// to update.
	INIT: begin
	   next_state = COMPUTE;	   
	end

	COMPUTE : begin	
	   diff_en = 1'b1;
	   data_en = 1'b1;
	   count_en = 1'b1;

	   if (count_done) begin
	      result_en = 1'b1;	      
	      next_state = RESTART;
	   end
	end

	RESTART : begin
	   done = 1'b1;
	   next_diff_rst = 1'b1;
	   next_count_rst = 1'b1;
	   data_en = 1'b1;
	   data_sel = 1'b1;	  

	   if (go) next_state = INIT;	   
	end	
      endcase            
   end 
endmodule


// Module: bit_diff_fsm_plus_d4
// Description: Combines fsm3 and datapath3 to reduce the area of earlier
// versions with a safer reset strategy.

module bit_diff_fsm_plus_d4
  #(
    parameter WIDTH
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   logic 					count_done;   
   logic 					data_sel;
   logic 					data_en;
   logic 					diff_rst;
   logic 					diff_en;
   logic 					count_rst;
   logic 					count_en;
   logic 					result_en;
   
   fsm3 CONTROLLER (.*);
   datapath3 #(.WIDTH(WIDTH)) DATAPATH (.*);
   
endmodule // bit_diff_fsm_plus_d4


// Module: bit_diff
// Description: a top-level module for testing synthesis of the different
// bit diff implementations.

module bit_diff
  #(
    parameter WIDTH=16
    )
   (
    input logic 				clk,
    input logic 				rst,
    input logic 				go,
    input logic [WIDTH-1:0] 			data,
    output logic signed [$clog2(2*WIDTH+1)-1:0] result,
    output logic 				done    
    );

   //bit_diff_fsmd_1p #(.WIDTH(WIDTH)) TOP (.*);
   //bit_diff_fsmd_2p #(.WIDTH(WIDTH)) TOP (.*);
   //bit_diff_fsm_plus_d1 #(.WIDTH(WIDTH)) TOP (.*);
   //bit_diff_fsm_plus_d2 #(.WIDTH(WIDTH)) TOP (.*);
   bit_diff_fsm_plus_d3 #(.WIDTH(WIDTH)) TOP (.*);
      
endmodule