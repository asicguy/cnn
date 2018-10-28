// Copyright (c) 2017, Alpha Data Parallel Systems Ltd.
// SystemVerilog port Copyright (c) 2018, Francis Bruno
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//    * Neither the name of the Alpha Data Parallel Systems Ltd. nor the
//      names of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL Alpha Data Parallel Systems Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


//
// conv_neuron.sv
//

module conv_neuron_shmu
  #
  (
   parameter FEATURE_WIDTH    = 8,
   parameter WEIGHT_WIDTH     = 8,
   parameter WEIGHT_MEM_ORDER = 5,
   parameter OUTPUT_WIDTH     = 8,
   parameter OUTPUT_SHIFT     = 0,
   parameter BIAS_SHIFT       = 0,
   parameter P_WIDTH          = FEATURE_WIDTH + WEIGHT_WIDTH,
   parameter ReLU             = "TRUE"
   )
  (
   input logic                     clk,
   input logic [FEATURE_WIDTH-1:0] feature_stream,
   input logic                     feature_first,
   input logic                     feature_last,
   input logic [WEIGHT_WIDTH-1:0]  weight_stream,
   input logic                     weight_first,
   input logic                     weight_last,
   output logic [OUTPUT_WIDTH-1:0] output_stream,
   output logic                    output_valid,
   output logic [FEATURE_WIDTH:0]  a,
   output logic [WEIGHT_WIDTH-1:0] b,
   input logic [P_WIDTH:0]         p
   );

  localparam WEIGHT_MEM_SIZE = 2**WEIGHT_MEM_ORDER;
  localparam ACC_SIZE        = FEATURE_WIDTH + WEIGHT_WIDTH + WEIGHT_MEM_ORDER;
  localparam P_SIZE          = FEATURE_WIDTH + WEIGHT_WIDTH + 1;

  logic [WEIGHT_MEM_SIZE-1:0][WEIGHT_WIDTH-1:0] wmem;
  logic [WEIGHT_MEM_ORDER-1:0]                  wmem_waddr;
  logic [WEIGHT_MEM_ORDER-1:0]                  wmem_raddr;

  logic [WEIGHT_WIDTH-1:0]                      bias;
  logic                                         wmem_writing;

  logic signed [P_SIZE-1:0]                     p_reg;
  logic [3:0][FEATURE_WIDTH-1:0]                feature_stream_reg;
  logic [2:0][WEIGHT_WIDTH-1:0]                 weight_reg;

  logic signed [ACC_SIZE-1:0]                   acc;

  logic [4:0]                                   feature_first_reg;
  logic [6:0]                                   feature_last_reg;

  logic signed [ACC_SIZE-1:0]                   acc_slv;

  initial begin
    wmem_waddr = '0;
    wmem_raddr = '0;
  end

  always @(posedge clk) begin
    if (weight_first) begin
      wmem_writing <= '1;
      wmem_waddr   <= '0;
      bias         <= weight_stream;
    end

    if (wmem_writing) begin
      if (weight_last) wmem_writing <= '0;
      wmem[wmem_waddr] <= weight_stream;
      wmem_waddr       <= wmem_waddr + 1'b1;
    end

    for (int i = 0; i < 3; i++) begin
      if (i == 0) weight_reg[i] <= wmem[wmem_raddr];
      else        weight_reg[i] <= weight_reg[i-1];
    end

    if (feature_first)
      wmem_raddr <= '0;
    else
      wmem_raddr <= wmem_raddr + 1'b1;

    for (int i = 0; i < 4; i++) begin
      if (i == 0) feature_stream_reg[i] <= feature_stream;
      else        feature_stream_reg[i] <= feature_stream_reg[i-1];
    end

    for (int i = 0; i < 5; i++) begin
      if (i == 0) feature_first_reg[i] <= feature_first;
      else        feature_first_reg[i] <= feature_first_reg[i-1];
    end

    for (int i = 0; i < 7; i++) begin
      if (i == 0) feature_last_reg[i] <= feature_last;
      else        feature_last_reg[i] <= feature_last_reg[i-1];
    end

    p_reg <= $signed(p);

    if (feature_first_reg[4])
      acc <= ($signed(bias) << BIAS_SHIFT) + p_reg;
    else
      acc <= acc + p_reg;

    // SLV type cast of acc available in same clock cycle.
    acc_slv <= acc;

    if (feature_last_reg[6]) begin
      if (ReLU == "TRUE") begin
        if (acc_slv[ACC_SIZE-1]) begin
          // If negative output 0
          output_stream <= '0;
        end else begin
          if (ACC_SIZE == OUTPUT_WIDTH+OUTPUT_SHIFT) begin
            // Maximum shift, cannot overflow
            output_stream <= acc_slv[ACC_SIZE-1:OUTPUT_SHIFT];
          end else begin
            if (|acc_slv[ACC_SIZE-1:OUTPUT_WIDTH+OUTPUT_SHIFT-1]) begin
              // Saturate if overflow
              output_stream[OUTPUT_WIDTH-1] <= '0;
              output_stream[OUTPUT_WIDTH-2:0] <= '1;
            end else begin
              // Select bits of interest
              output_stream <= acc_slv[OUTPUT_WIDTH+OUTPUT_SHIFT-1:OUTPUT_SHIFT];
            end
          end
        end
      end else begin
        output_stream <= acc_slv[OUTPUT_WIDTH+OUTPUT_SHIFT-1:OUTPUT_SHIFT];
      end // if (ReLU == "TRUE")

      output_valid <= '1;
    end else begin
      output_valid <= '0;
    end // else: !if(feature_last_reg[6])
  end // always @ (posedge clk)

  assign a = {1'b0, feature_stream_reg[3]};
  assign b = weight_reg[2];
endmodule // conv_neuron_shmu
