//---------------------------------------------------------------------------
// DUT - 564/464 Project
//---------------------------------------------------------------------------
`include "common.vh"

module MyDesign(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output reg dut_ready                   ,

//---------------------------------------------------------------------------
//input SRAM interface
  output reg                           dut__tb__sram_input_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface
  output reg                           dut__tb__sram_weight_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface
  output reg                           dut__tb__sram_result_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data     ,    

//scratchpad SRAM interface
  output reg                           dut__tb__sram_scratchpad_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_scratchpad_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_scratchpad_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_scratchpad_read_data  

);

// *----- Finite State Machine parameters -----* //
parameter IDLE          = 3'b000,  // 0
          INITIALIZE    = 3'b001,  // 1
          COMPUTE_Q     = 3'b010,  // 2
          COMPUTE_K     = 3'b011,  // 3
          COMPUTE_V     = 3'b100,  // 4
          COMPUTE_S     = 3'b101,  // 5
          COMPUTE_Z     = 3'b110;  // 6

// *----- Datapath Signals -----* //
reg [2:0]                 Current_State, Next_State;
reg signed [31:0]         accum_result;
wire signed [31:0]         mac_result_z;

// SRAM connections
reg [`SRAM_ADDR_RANGE]    input_read_addr_connection;
reg [`SRAM_DATA_RANGE]    input_read_data_connection;
reg [`SRAM_ADDR_RANGE]    input_write_addr_connection;
reg [`SRAM_DATA_RANGE]    input_write_data_connection;
reg [`SRAM_ADDR_RANGE]    weight_read_addr_connection;
reg [`SRAM_DATA_RANGE]    weight_read_data_connection;
reg [`SRAM_ADDR_RANGE]    weight_write_addr_connection;
reg [`SRAM_DATA_RANGE]    weight_write_data_connection;
reg [`SRAM_ADDR_RANGE]    result_write_addr_connection;
reg [`SRAM_DATA_RANGE]    result_write_data_connection;
reg [`SRAM_ADDR_RANGE]    result_read_addr_connection;
reg [`SRAM_DATA_RANGE]    result_read_data_connection;
reg [`SRAM_ADDR_RANGE]    scratchpad_read_addr_connection;
reg [`SRAM_DATA_RANGE]    scratchpad_read_data_connection;
reg [`SRAM_ADDR_RANGE]    scratchpad_write_addr_connection;
reg [`SRAM_DATA_RANGE]    scratchpad_write_data_connection;
reg                       input_write_enable_connection;
reg                       weight_write_enable_connection;
reg                       result_write_enable_connection;
reg                       scratchpad_write_enable_connection;
reg                       scratchpad_enable_flag;
reg                       scratchpad_read_enable_flag;
reg                       transpose_flag;
reg                       capture_metadata;

// *----- Control Signals -----* //
reg [7:0]            matrix_A_cols_B_rows;
reg [13:0]           matrix_A_rows, matrix_B_cols;
reg [13:0]          input_offset, weight_offset, result_offset, score_offset;
reg [15:0]          updated_weight_offset, updated_result_offset, updated_input_offset, updated_scratchpad_offset;
reg                 all_elements_computed;
reg                 ready;
reg                 complete;
wire                dut_ready_connection;




// *----- State Machine -----* //
always_comb begin : state_machine
  case (Current_State)
    IDLE: begin    // State 0  
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data    = 32'b0;
      dut__tb__sram_scratchpad_write_enable  = 1'b0;
      dut__tb__sram_scratchpad_read_address  = 16'b0;
      dut__tb__sram_scratchpad_write_address = 16'b0;

      // Result
      dut__tb__sram_result_read_address      = 16'b0;
      dut__tb__sram_result_write_enable      = 1'b0;
      dut__tb__sram_result_write_data        = 32'b0;
      dut__tb__sram_result_write_address     = 16'b0;

      // Input
      dut__tb__sram_input_read_address       = 16'b0;
      dut__tb__sram_input_write_enable       = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address      = 16'b0;
      dut__tb__sram_weight_write_enable      = 1'b0;

      // Read Data Connections
      input_read_data_connection             = 32'b0;
      weight_read_data_connection            = 32'b0;
      result_read_data_connection            = 32'b0;

      // Flags
      ready                                  = 1'b0;
      dut_ready                           = 1'b1;  
      scratchpad_enable_flag              = 1'b0;
      scratchpad_read_enable_flag         = 1'b0;
      transpose_flag                      = 1'b0;
      capture_metadata                    = 1'b1;

      if (dut_valid) begin
        Next_State                          = INITIALIZE;
      end else begin
        Next_State                          = IDLE;
      end
    end
    INITIALIZE: begin    // State 1
      // Initalize SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data    = 32'b0;
      dut__tb__sram_scratchpad_write_enable  = 1'b0;
      dut__tb__sram_scratchpad_read_address  = 16'b0;
      dut__tb__sram_scratchpad_write_address = 16'b0;

      // Result
      dut__tb__sram_result_read_address     = 16'b0;
      dut__tb__sram_result_write_enable     = 1'b0;
      dut__tb__sram_result_write_data       = 32'b0;
      dut__tb__sram_result_write_address    = 16'b0;

      // Input
      dut__tb__sram_input_read_address      = 16'b0;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = 16'b0;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = 32'b0;
      weight_read_data_connection           = 32'b0;
      result_read_data_connection           = 32'b0;

      // Flags
      dut_ready                             = 1'b0;
      scratchpad_enable_flag                = 1'b0;
      scratchpad_read_enable_flag           = 1'b0;
      transpose_flag                        = 1'b0;
      ready                                 = 1'b0;
      capture_metadata                      = 1'b1;

      Next_State             = COMPUTE_Q;
    end
    COMPUTE_Q: begin    // State 2
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data   = 32'b0;
      dut__tb__sram_scratchpad_write_enable = 1'b0;
      dut__tb__sram_scratchpad_read_address = 16'b0;
      dut__tb__sram_scratchpad_write_address = 16'b0;

      // Result
      dut__tb__sram_result_read_address     = 16'b0;
      dut__tb__sram_result_write_enable     = result_write_enable_connection;
      dut__tb__sram_result_write_data       = result_write_data_connection;
      dut__tb__sram_result_write_address    = result_write_addr_connection;

      // Input
      dut__tb__sram_input_read_address      = input_read_addr_connection;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = weight_read_addr_connection;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = tb__dut__sram_input_read_data;
      weight_read_data_connection           = tb__dut__sram_weight_read_data;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                                = 1'b1;
      dut_ready                            = 1'b0;
      scratchpad_enable_flag               = 1'b0;
      scratchpad_read_enable_flag          = 1'b0;
      transpose_flag                       = 1'b0;
      capture_metadata                    = 1'b0;

      Next_State           = (complete) ? COMPUTE_K : COMPUTE_Q;
    end
    COMPUTE_K: begin    // State 4
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data   = result_write_data_connection;
      dut__tb__sram_scratchpad_write_enable = scratchpad_write_enable_connection;
      dut__tb__sram_scratchpad_read_address = 16'b0;
      dut__tb__sram_scratchpad_write_address = scratchpad_write_addr_connection;

      // Result
      dut__tb__sram_result_read_address     = 16'b0;
      dut__tb__sram_result_write_enable     = result_write_enable_connection;
      dut__tb__sram_result_write_data       = result_write_data_connection;
      dut__tb__sram_result_write_address    = result_write_addr_connection;

      // Input
      dut__tb__sram_input_read_address      = input_read_addr_connection;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = weight_read_addr_connection;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = tb__dut__sram_input_read_data;
      weight_read_data_connection           = tb__dut__sram_weight_read_data;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                                = 1'b1;
      dut_ready                            = 1'b0;
      scratchpad_enable_flag               = 1'b1;
      scratchpad_read_enable_flag          = 1'b0;
      transpose_flag                       = 1'b0;
      capture_metadata                     = 1'b0;


      Next_State           = (complete) ? COMPUTE_V : COMPUTE_K;
    end
    COMPUTE_V: begin    // State 8
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data   = result_write_data_connection;
      dut__tb__sram_scratchpad_write_enable = scratchpad_write_enable_connection;
      dut__tb__sram_scratchpad_read_address = 16'b0;
      dut__tb__sram_scratchpad_write_address = scratchpad_write_addr_connection;

      // Result
      dut__tb__sram_result_read_address     = 16'b0;
      dut__tb__sram_result_write_enable     = result_write_enable_connection;
      dut__tb__sram_result_write_data       = result_write_data_connection;
      dut__tb__sram_result_write_address    = result_write_addr_connection;

      // Input
      dut__tb__sram_input_read_address      = input_read_addr_connection;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = weight_read_addr_connection;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = tb__dut__sram_input_read_data;
      weight_read_data_connection           = tb__dut__sram_weight_read_data;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                               = 1'b1;
      dut_ready                           = 1'b0;
      scratchpad_enable_flag              = 1'b1;
      scratchpad_read_enable_flag         = 1'b0;
      transpose_flag                      = 1'b0;
      capture_metadata                    = 1'b0;

      Next_State           = (complete) ? COMPUTE_S : COMPUTE_V;
    end
    COMPUTE_S: begin    // State 16
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data   = scratchpad_write_data_connection;
      dut__tb__sram_scratchpad_write_enable = scratchpad_write_enable_connection;
      dut__tb__sram_scratchpad_read_address = scratchpad_read_addr_connection;
      dut__tb__sram_scratchpad_write_address = scratchpad_write_addr_connection;

      // Result
      dut__tb__sram_result_read_address     = result_read_addr_connection;
      dut__tb__sram_result_write_enable     = result_write_enable_connection;
      dut__tb__sram_result_write_data       = result_write_data_connection;
      dut__tb__sram_result_write_address    = result_write_addr_connection;

      // Input
      dut__tb__sram_input_read_address      = 16'b0;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = 16'b0;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = tb__dut__sram_result_read_data;
      weight_read_data_connection           = tb__dut__sram_scratchpad_read_data;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                                 = 1'b1;
      dut_ready                             = 1'b0;
      scratchpad_enable_flag                = 1'b1;
      scratchpad_read_enable_flag           = 1'b1;
      capture_metadata                      = 1'b0;
      transpose_flag                        = (complete) ? 1'b1 : 1'b0;

      Next_State           = (complete) ? COMPUTE_Z : COMPUTE_S;
    end
    COMPUTE_Z: begin    // State 32
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data    = 32'b0;
      dut__tb__sram_scratchpad_write_enable  = 1'b0;
      dut__tb__sram_scratchpad_read_address  = scratchpad_read_addr_connection;
      dut__tb__sram_scratchpad_write_address = 16'b0;

      // Result
      dut__tb__sram_result_read_address     = result_read_addr_connection;
      dut__tb__sram_result_write_enable     = result_write_enable_connection;
      dut__tb__sram_result_write_data       = result_write_data_connection;
      dut__tb__sram_result_write_address    = result_write_addr_connection;

      // Input
      dut__tb__sram_input_read_address      = 16'b0;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = 16'b0;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = tb__dut__sram_result_read_data;
      weight_read_data_connection           = tb__dut__sram_scratchpad_read_data;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                                = 1'b1;
      dut_ready                            = 1'b0;
      scratchpad_enable_flag               = 1'b0;
      scratchpad_read_enable_flag          = 1'b1;
      transpose_flag                       = 1'b1;
      capture_metadata                     = 1'b0;

      Next_State                           = (complete) ? IDLE : COMPUTE_Z;
    end
    default: begin
      // SRAM connections
      // Scratchpad
      dut__tb__sram_scratchpad_write_data   = 32'b0;
      dut__tb__sram_scratchpad_write_enable = 1'b0;
      dut__tb__sram_scratchpad_read_address = 16'b0;
      dut__tb__sram_scratchpad_write_address = 16'b0;

      // Result
      dut__tb__sram_result_read_address     = 16'b0;
      dut__tb__sram_result_write_enable     = 1'b0;
      dut__tb__sram_result_write_data       = 32'b0;
      dut__tb__sram_result_write_address    = 16'b0;

      // Input
      dut__tb__sram_input_read_address      = 16'b0;
      dut__tb__sram_input_write_enable      = 1'b0;

      // Weight
      dut__tb__sram_weight_read_address     = 16'b0;
      dut__tb__sram_weight_write_enable     = 1'b0;

      // Read Data Connections
      input_read_data_connection            = 32'b0;
      weight_read_data_connection           = 32'b0;
      result_read_data_connection           = 32'b0;

      // Flags
      ready                               = 1'b0;
      dut_ready                           = 1'b1;  
      scratchpad_enable_flag              = 1'b0;
      scratchpad_read_enable_flag         = 1'b0;
      transpose_flag                      = 1'b0;
      capture_metadata                    = 1'b0;
      Next_State                          = IDLE;
    end
  endcase
end : state_machine


// *----- Procedural Blocks -----* //
always_ff @( posedge clk ) begin : next_state
  if (!reset_n) begin
    Current_State <= IDLE;

  end else begin
    Current_State <= Next_State;
  end
end : next_state

// Capture Metadata
always_ff @(posedge clk) begin : save_metadata
  if (!reset_n) begin
    // Reset metadata
    matrix_A_rows         <= 14'b0;
    matrix_A_cols_B_rows  <= 8'b0;
    matrix_B_cols         <= 14'b0;

    // Reset offsets
    input_offset        <= 14'b0;
    weight_offset       <= 14'b0;
    result_offset       <= 14'b0;
    score_offset        <= 14'b0;

  end else if (capture_metadata) begin
    // Capture matrix metadata
    matrix_A_rows        <= tb__dut__sram_input_read_data[31:16];
    matrix_A_cols_B_rows <= tb__dut__sram_input_read_data[15:0];
    matrix_B_cols        <= tb__dut__sram_weight_read_data[15:0];

    // Calculate offsets
    input_offset        <= tb__dut__sram_input_read_data[31:16] * tb__dut__sram_input_read_data[15:0];
    weight_offset       <= tb__dut__sram_weight_read_data[31:16] * tb__dut__sram_weight_read_data[15:0];
    result_offset       <= tb__dut__sram_input_read_data[31:16] * tb__dut__sram_weight_read_data[15:0];
    score_offset        <= tb__dut__sram_input_read_data[31:16] * tb__dut__sram_input_read_data[31:16];
  end else begin
    // Hold metadata
    matrix_A_rows        <= matrix_A_rows;
    matrix_A_cols_B_rows <= matrix_A_cols_B_rows;
    matrix_B_cols        <= matrix_B_cols;

    // Hold offsets
    input_offset        <= input_offset;
    weight_offset       <= weight_offset;
    result_offset       <= result_offset;
    score_offset        <= score_offset;
  end
end : save_metadata

// Update offsets
always_ff @( posedge clk ) begin : update_offsets
  if (!reset_n) begin
    updated_weight_offset           <= 16'b0;
    updated_result_offset           <= 16'b0;
    updated_scratchpad_offset       <= 16'b0;
    updated_input_offset            <= 16'b0;
  end else if (Current_State == INITIALIZE) begin
    updated_weight_offset           <= 16'b0;
    updated_result_offset           <= 16'b0;
    updated_scratchpad_offset       <= 16'b0;
    updated_input_offset            <= 16'b0;
  end else if (Current_State == COMPUTE_Q) begin
    updated_weight_offset <= (complete) ? weight_offset : updated_weight_offset;
    updated_result_offset <= (complete) ? result_offset : updated_result_offset;
  end else if (Current_State == COMPUTE_K) begin
    updated_weight_offset <= (complete) ? updated_weight_offset + weight_offset : updated_weight_offset;
    updated_result_offset <= (complete) ? updated_result_offset + result_offset : updated_result_offset;
    updated_scratchpad_offset <= (complete) ? updated_result_offset : updated_scratchpad_offset;
  end else if (Current_State == COMPUTE_V) begin
    updated_weight_offset <= (complete) ? 16'b0 : updated_weight_offset;
    updated_result_offset <= (complete) ? updated_result_offset + result_offset : updated_result_offset;
    updated_scratchpad_offset <= (complete) ? updated_result_offset : updated_scratchpad_offset;
  end else if (Current_State == COMPUTE_S) begin
    updated_input_offset <= (complete) ? updated_result_offset : updated_input_offset;  // Read S from result (input)
    updated_weight_offset <= (complete) ? result_offset : updated_weight_offset;  // Read V from scratchpad (weight)
    updated_result_offset <= (complete) ? updated_result_offset + score_offset : updated_result_offset; // Write Z to result
  end
end : update_offsets

always_comb begin : connections
  dut__tb__sram_input_write_address   = input_write_addr_connection;
  dut__tb__sram_input_write_data      = input_write_data_connection;
  dut__tb__sram_weight_write_address  = weight_write_addr_connection;
  dut__tb__sram_weight_write_data     = weight_write_data_connection;
end


// Instantiate HW6 module
HW6 HW6_inst(
  // Inputs 
  .reset_n                            (reset_n),
  .clk                                (clk),
  .dut_valid                          (dut_valid),
  .tb__dut__sram_input_read_data      (input_read_data_connection),
  .tb__dut__sram_weight_read_data     (weight_read_data_connection),
  .tb__dut__sram_result_read_data     (result_read_data_connection),

  // Outputs
  .dut_ready                          (dut_ready_connection),
  .dut__tb__sram_input_write_enable   (input_write_enable_connection),
  .dut__tb__sram_input_write_address  (input_write_addr_connection),
  .dut__tb__sram_input_write_data     (input_write_data_connection),
  .dut__tb__sram_input_read_address   (input_read_addr_connection),
  .dut__tb__sram_weight_write_enable  (weight_write_enable_connection),
  .dut__tb__sram_weight_write_address (weight_write_addr_connection),
  .dut__tb__sram_weight_write_data    (weight_write_data_connection),
  .dut__tb__sram_weight_read_address  (weight_read_addr_connection),
  .dut__tb__sram_result_write_enable  (result_write_enable_connection),
  .dut__tb__sram_result_write_address (result_write_addr_connection),
  .dut__tb__sram_result_write_data    (result_write_data_connection),
  .dut__tb__sram_result_read_address  (result_read_addr_connection),

  // Control Signals
  .ready                              (ready),
  .complete                           (complete),
  .weight_offset                      (updated_weight_offset),
  .result_offset                      (updated_result_offset),
  .matrix_A_rows_input                (matrix_A_rows),
  .matrix_B_cols_input                (matrix_B_cols),
  .matrix_A_cols_B_rows_input         (matrix_A_cols_B_rows),
  .write_scratchpad                   (scratchpad_enable_flag),
  .scratchpad_write_enable            (scratchpad_write_enable_connection),
  .scratchpad_write_address           (scratchpad_write_addr_connection),
  .scratchpad_write_data              (scratchpad_write_data_connection),
  .scratchpad_read_address            (scratchpad_read_addr_connection),
  .current_dut_state                  (Current_State),
  .scratchpad_read_enable             (scratchpad_read_enable_flag),
  .scratchpad_offset                  (updated_scratchpad_offset),
  .input_offset                       (updated_input_offset),
  .transpose_flag                     (transpose_flag)
);


endmodule

module HW6(
//---------------------------------------------------------------------------
//System signals
  input wire reset_n                      ,  
  input wire clk                          ,

//---------------------------------------------------------------------------
//Control signals
  input wire dut_valid                    , 
  output wire dut_ready                   ,

//---------------------------------------------------------------------------
//input SRAM interface (SRAM A)
  output reg                           dut__tb__sram_input_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_input_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_input_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_input_read_data     ,     

//weight SRAM interface (SRAM B)
  output reg                           dut__tb__sram_weight_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_weight_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_weight_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_weight_read_data     ,     

//result SRAM interface (SRAM C)
  output reg                           dut__tb__sram_result_write_enable  ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_write_address ,
  output reg [`SRAM_DATA_RANGE     ]   dut__tb__sram_result_write_data    ,
  output reg [`SRAM_ADDR_RANGE     ]   dut__tb__sram_result_read_address  , 
  input  reg [`SRAM_DATA_RANGE     ]   tb__dut__sram_result_read_data,


// Control Signals
  input reg ready, write_scratchpad, scratchpad_read_enable, transpose_flag,
  input reg [15:0]  weight_offset, result_offset, scratchpad_offset, input_offset,
  input reg [7:0]   matrix_A_cols_B_rows_input, 
  input reg [13:0]  matrix_B_cols_input, matrix_A_rows_input,
  input reg [2:0]   current_dut_state,
  output reg [15:0] scratchpad_read_address,
  output reg [15:0] scratchpad_write_address,
  output reg [31:0] scratchpad_write_data,
  // input reg [31:0] scratchpad_read_data,
  output reg scratchpad_write_enable,
  output reg complete
);

// --- Parameters --- //
parameter S0_C = 3'b000,   // IDLE (0)
          S1_C = 3'b001,   // INITIALIZE (1)
          S2_C = 3'b010,   // PROCESS ROW (2)
          S3_C = 3'b011,   // WRITE RESULT (3)
          S4_C = 3'b100;   // END (4)

// DUT State parameters
parameter S0_DUT = 3'b000,   // 0
          S1_DUT = 3'b001,   // 1
          S2_DUT = 3'b010,   // 2
          S3_DUT = 3'b011,   // 3
          S4_DUT = 3'b100,   // 4
          S5_DUT = 3'b101,   // 5
          S6_DUT = 3'b110;   // 6

// --- Datapath Signals --- //
reg [31:0] accum_result;
wire [31:0] mac_result_z;


// --- SRAM interface --- //
reg[15:0] SRAM_A_read_addr, SRAM_B_read_addr, SRAM_C_write_addr, scratchpad_write_addr;
reg[15:0] SRAM_Read_transpose_addr;



// --- Control Signals --- //
reg[1:0]  A_row_sel, B_row_sel;   // 01 = increment, 10 = hold, 00 = reset
reg       row_complete;
reg       all_elements_computed;
reg       set_dut_ready;
reg       get_matrix_size;
reg       write_enable_sel;
reg       initialize_counters;
reg       dut_ready_reg;
reg       finished_computation;
reg       set_write_enable; 
reg       reset_accumulator_buffer;
reg       reset_accumulator_reg;
reg       write_enable_scratchpad_reg;

// --- Counters --- //
reg[7:0]             Current_C_count;
reg[7:0]             Current_col_count_A, Max_col_count_A;
reg[11:0]            Current_col_count_B, B_num_of_vals;
reg[7:0]             A_Offset;
reg[7:0]             A_Offset_counter;
reg[7:0]             Total_C_count;
reg[7:0]             row_counter;
reg[7:0]             metadata_A_cols_B_rows, metadata_B_cols;
reg[7:0]             transpose_offset, transpose_complete_offset;
reg[7:0]             transpose_row_counter;

// --- State Machine --- //
reg[2:0] Current_State, Next_State;



// Create synchronus reset and initialize all internal variables
always @(posedge clk) begin
  if (!reset_n) begin     
    Current_State <= S0_C;    // Reset to IDLE state
  end else begin
    Current_State <= Next_State;
  end
end

// --- State Machine --- //
always_comb begin : state_machine
  case (Current_State)
    S0_C: begin   // Idle
      set_dut_ready           = 1'b1;  
      get_matrix_size         = 1'b1;
      A_row_sel               = 2'b00;   // reset
      B_row_sel               = 2'b00;   // reset
      finished_computation    = 1'b0;
      complete                = 1'b0;
      reset_accumulator_reg   = 1'b1;

      if (ready) begin    // If DUT_valid goes high, set DUT_ready low
        initialize_counters   = 1'b1;
        Next_State            = S1_C;
      end else begin  
        initialize_counters   = 1'b0;
        Next_State            = S0_C;
      end
    end
    S1_C: begin   // Initialize
        // Set control signals
        initialize_counters   = 1'b0;
        set_dut_ready         = 1'b0;   
        get_matrix_size       = 1'b0;
        A_row_sel             = 2'b01;   // Increment
        B_row_sel             = 2'b01;   // Increment
        complete              = 1'b0;
        reset_accumulator_reg = 1'b1;
        
        Next_State            = S2_C;
    end
    S2_C: begin   // Process row
        // Set control signals
        set_dut_ready         = 1'b0;   
        get_matrix_size       = 1'b0;
        A_row_sel             = 2'b01;   // Increment
        B_row_sel             = 2'b01;   // Increment 
        complete              = 1'b0;
        reset_accumulator_reg = 1'b0;
        initialize_counters   = 1'b0;
        Next_State            = (row_complete) ? S3_C : S2_C;
    end
    S3_C: begin // Write result to SRAM C
        // Set control signals
        set_dut_ready         = 1'b0;   
        get_matrix_size       = 1'b0;
        A_row_sel             = 2'b01;   // Increment
        B_row_sel             = 2'b01;   // Increment
        complete              = 1'b0;
        reset_accumulator_reg = 1'b0;
        initialize_counters   = 1'b0;
        Next_State            = (all_elements_computed) ? S4_C : S2_C;
    end
    S4_C: begin // Back to idle
        // Set control signals
        set_dut_ready         = 1'b1;   
        get_matrix_size       = 1'b0;
        A_row_sel             = 2'b00;   // reset 
        B_row_sel             = 2'b00;   // reset
        finished_computation  = 1'b1;
        complete              = 1'b1;
        reset_accumulator_reg = 1'b0;
        initialize_counters   = 1'b0;
        Next_State            = S0_C;
    end
    default: begin
      set_dut_ready           = 1'b1;  
      get_matrix_size         = 1'b1;
      A_row_sel               = 2'b00;   // reset
      B_row_sel               = 2'b00;   // reset
      finished_computation    = 1'b0;
      complete                = 1'b0;
      reset_accumulator_reg   = 1'b1;
      initialize_counters     = 1'b0;

      Next_State = S0_C;
    end
  endcase
end : state_machine

// --- DUT Ready Handshake --- //
always_comb begin : handshake
  if (!reset_n) begin
    dut_ready_reg = 1'b1;
  end else begin
    dut_ready_reg = (set_dut_ready) ? 1'b1 : 1'b0;
  end
end : handshake

assign dut_ready = ready;

// Posedge block to handle Write C address updates
always_ff @(posedge clk) begin : sram_connections 
  if (!reset_n || initialize_counters) begin
    SRAM_C_write_addr       <= 16'b0;
    row_counter             <= 16'b0;
    scratchpad_write_addr   <= 16'b0;
  end else if (write_enable_sel) begin
    row_counter           <= row_counter + 1;
    SRAM_C_write_addr     <= row_counter + result_offset;
    scratchpad_write_addr <= (write_scratchpad) ? row_counter + scratchpad_offset : scratchpad_write_addr;
  end else begin
    SRAM_C_write_addr       <= SRAM_C_write_addr;
    row_counter             <= row_counter;
    scratchpad_write_addr   <= scratchpad_write_addr;
  end
end : sram_connections

// Counter A logic
always_ff @(posedge clk) begin : counter_a_logic
  if (initialize_counters || !reset_n) begin
    // Reset all counters
    Current_C_count <= 8'b0;
    Current_col_count_A <= (scratchpad_read_enable) ? 8'b0 : 8'b1;
    A_Offset <= 8'b0;
    SRAM_A_read_addr <= 16'b0;
    row_complete <= 1'b0;
  end
  // INCREMENT
  else if (A_row_sel == 2'b01) begin
    // Increment SRAM_A_read_addr to next address
    SRAM_A_read_addr <= Current_col_count_A + A_Offset + input_offset; 

    // Check if current row is complete
    if (Current_col_count_A >= Max_col_count_A) begin
      // Set row_complete signal high since current row is complete
      row_complete <= (!all_elements_computed) ? 1'b1 : 1'b0;
      // Reset Current_col_count_A to 0
      Current_col_count_A <= (scratchpad_read_enable) ? 8'b0 : 8'b1;
      // Increment Current_C_count to next C value
      Current_C_count <= Current_C_count + 8'b1;

      // Increment A_Offset_counter
      A_Offset_counter <= (A_Offset_counter + 8'b1 >= metadata_B_cols) ? 8'b0 : A_Offset_counter + 8'b1; 
      A_Offset <= (A_Offset_counter + 8'b1 >= metadata_B_cols) ? A_Offset + metadata_A_cols_B_rows : A_Offset;

    end else begin
      row_complete <= 1'b0;
      // Increment Current_col_count_A to next col
      Current_col_count_A <= Current_col_count_A + 8'b1;
      A_Offset_counter <= A_Offset_counter;

      A_Offset <= A_Offset;
    end 
  end 

  // HOLD
  else if (A_row_sel == 2'b10) begin
    SRAM_A_read_addr <= SRAM_A_read_addr;
    A_Offset_counter <= A_Offset_counter;
    row_complete <= 1'b0;
    A_Offset <= A_Offset;
  end

  // RESET
  else if (A_row_sel == 2'b00) begin
    SRAM_A_read_addr <= 16'b0;
    A_Offset_counter <= 8'b0;
    row_complete <= 1'b0;
    A_Offset <= 8'b0;
  end
end : counter_a_logic

// Set write enable
always_comb begin : write_enable
  write_enable_sel = (row_complete) ? 1'b1 : 1'b0;  
end : write_enable


// Always block to calculate B SRAM read address
always_ff @(posedge clk) begin : counter_b_logic
  if (initialize_counters || !reset_n) begin
    Current_col_count_B <= (scratchpad_read_enable) ? 8'b0 : 8'b1;
    SRAM_B_read_addr <= 16'b0;
  end
  else if(B_row_sel == 2'b01) begin    // Increment
    SRAM_B_read_addr <= Current_col_count_B + weight_offset;
    Current_col_count_B <= Current_col_count_B + 8'b1;

    // Check if current row is complete
    if (Current_col_count_B >= B_num_of_vals) begin
      // Reset Current_col_count_B to 1
      Current_col_count_B <= (scratchpad_read_enable) ? 8'b0 : 8'b1;
    end
  end else if (B_row_sel == 2'b10) begin   // Hold
    SRAM_B_read_addr <= SRAM_B_read_addr;
  end else if (B_row_sel == 2'b00) begin   // Reset
    SRAM_B_read_addr <= 16'b0;
  end
end : counter_b_logic

// Check if all elements have been computed
always_ff @(posedge clk) begin : all_elements_complete
  if (!reset_n || initialize_counters) begin
    all_elements_computed <= 1'b0;
  end else  begin
    all_elements_computed <= (Current_C_count > Total_C_count) ? 1'b1 : 1'b0;
  end
end : all_elements_complete

// Initialize Metadata
always_ff @(posedge clk) begin : initialize_metadata
  if (!reset_n) begin
    Max_col_count_A         <= 8'b0;
    Total_C_count           <= 8'b0;
    B_num_of_vals           <= 12'b0;
    metadata_A_cols_B_rows  <= 8'b0;
    metadata_B_cols         <= 8'b0;

  end else if (initialize_counters) begin
    // If Dut is in state 16 (S4_DUT) then set custom metadata
    if (current_dut_state == S5_DUT ) begin
      Total_C_count           <= (matrix_A_rows_input * matrix_A_rows_input) - 8'b1;
      B_num_of_vals           <= (matrix_A_rows_input * matrix_B_cols_input) - 12'b1;
      Max_col_count_A         <= (matrix_B_cols_input) - 8'b1;

      // Set metadata
      metadata_A_cols_B_rows <= matrix_B_cols_input;
      metadata_B_cols         <= matrix_A_rows_input;

    end else if (current_dut_state == S6_DUT) begin
      Total_C_count           <= (matrix_A_rows_input * matrix_B_cols_input) - 8'b1;
      B_num_of_vals           <= (matrix_A_rows_input * matrix_B_cols_input) - 8'b1;
      Max_col_count_A         <= (matrix_A_rows_input) - 8'b1;

      // Set metadata
      metadata_A_cols_B_rows  <= matrix_A_rows_input;
      metadata_B_cols         <= matrix_B_cols_input;

    end else begin
      Total_C_count           <= (matrix_A_rows_input * matrix_B_cols_input) - 8'b1;
      B_num_of_vals           <= matrix_A_cols_B_rows_input * matrix_B_cols_input;
      Max_col_count_A         <= (get_matrix_size) ? matrix_A_cols_B_rows_input : Max_col_count_A;

      // Set metadata
      metadata_A_cols_B_rows  <= matrix_A_cols_B_rows_input;
      metadata_B_cols         <= matrix_B_cols_input;
    end
  end else begin
    // Hold metadata
    metadata_A_cols_B_rows   <= metadata_A_cols_B_rows;
    metadata_B_cols           <= metadata_B_cols;

    // hold counters
    Total_C_count             <= Total_C_count;
    B_num_of_vals             <= B_num_of_vals;
    Max_col_count_A           <= Max_col_count_A;
  end
end : initialize_metadata

// Transpose SRAM_A_read_addr
always_ff @(posedge clk) begin : transpose_sram_a_read_addr
  if (!reset_n || initialize_counters) begin
    SRAM_Read_transpose_addr <= 16'b0;
    transpose_row_counter <= 8'b0;
    transpose_offset <= 8'b0;
    transpose_complete_offset <= 8'b0;
  end else if (transpose_flag) begin
    SRAM_Read_transpose_addr <= transpose_complete_offset + weight_offset;

    transpose_row_counter <= (transpose_row_counter >= metadata_A_cols_B_rows - 8'b1) ? 8'b0 : transpose_row_counter + 8'b1;

    transpose_offset <= (transpose_row_counter >= metadata_A_cols_B_rows - 8'b1) ? ((transpose_offset + 8'b1 >= metadata_B_cols) ? 8'b0 : transpose_offset + 8'b1) : transpose_offset;

    transpose_complete_offset <= (transpose_row_counter >= metadata_A_cols_B_rows - 8'b1) ? ((transpose_offset + 8'b1 >= metadata_B_cols) ? 8'b0 : transpose_offset + 8'b1) : transpose_complete_offset + metadata_B_cols;

  end else begin
    SRAM_Read_transpose_addr <= SRAM_A_read_addr;
  end
end : transpose_sram_a_read_addr

// Set write enable and write enable scratchpad
always_ff @(posedge clk) begin : update_write_enable
  if(write_enable_sel) begin
    set_write_enable <= 1'b1;
    write_enable_scratchpad_reg <= (write_scratchpad) ? 1'b1 : 1'b0;
  end else begin
    set_write_enable <= 1'b0;
    write_enable_scratchpad_reg <= 1'b0;
  end
end : update_write_enable

// Write back one cycle after write enable select is set high
always_ff @(posedge clk) begin : accumulator
  if (!reset_n || initialize_counters) begin
    accum_result <= 32'b0;
    reset_accumulator_buffer <= 32'b0;
  end else begin
    if (reset_accumulator_reg) begin
      reset_accumulator_buffer <= 32'b1;
    end else if (reset_accumulator_buffer) begin
      accum_result <= 32'b0;
      reset_accumulator_buffer <= 32'b0;
    end else if (set_write_enable) begin
      accum_result <= 32'b0;
    end else begin
      accum_result <= mac_result_z;
    end
  end
end : accumulator

always_comb begin : SRAM_connections
  dut__tb__sram_result_write_data = mac_result_z;
  dut__tb__sram_result_write_enable = set_write_enable;
  dut__tb__sram_result_write_address = SRAM_C_write_addr;

  dut__tb__sram_input_read_address = SRAM_A_read_addr;
  dut__tb__sram_weight_read_address = SRAM_B_read_addr;

  dut__tb__sram_input_write_enable = 1'b0;
  dut__tb__sram_weight_write_enable = 1'b0;

  // Scratchpad write signals
  scratchpad_write_enable = write_enable_scratchpad_reg;
  scratchpad_write_address = scratchpad_write_addr;
  scratchpad_write_data = mac_result_z;

  // Scratchpad read signals
  scratchpad_read_address = (transpose_flag) ? SRAM_Read_transpose_addr : SRAM_B_read_addr;

  // Result read signals
  dut__tb__sram_result_read_address = SRAM_A_read_addr;
end : SRAM_connections


int_accumulate_multiplication INT_MAC ( 
  .inst_a(tb__dut__sram_input_read_data),
  .inst_b(tb__dut__sram_weight_read_data),
  .inst_c(accum_result),
  .z_inst(mac_result_z)
);

endmodule

// Create module to do integer accumulate multiplication
module int_accumulate_multiplication(
  input wire [31:0] inst_a,
  input wire [31:0] inst_b,
  input wire [31:0] inst_c,
  output wire [31:0] z_inst
);

assign z_inst = inst_a * inst_b + inst_c;

endmodule