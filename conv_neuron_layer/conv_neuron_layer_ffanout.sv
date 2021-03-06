// Copyright (c) 2017, Alpha Data Parallel Systems Ltd.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the Alpha Data Parallel Systems Ltd. nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
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
//  conv_neuron_layer.vhd
//  Flat fanout, doubles output rate, allowing larget layer size
//  Potentially lowers max clock frequency
//

module conv_neuron_layer_ffanout
  #
  (
   parameter LAYER_SIZE       = 10,
   parameter LAYER_SIZE_ORDER = 4,
   parameter FEATURE_WIDTH    = 8,
   parameter WEIGHT_WIDTH     = 8,
   parameter WEIGHT_MEM_ORDER = 5,
   parameter OUTPUT_WIDTH     = 8,
   parameter OUTPUT_SHIFT     = 0,
   parameter BIAS_SHIFT       = 0,
   parameter ReLU             = "TRUE"
   )
  (
   input logic                         clk,
   input logic [FEATURE_WIDTH-1:0]     feature_stream,
   input logic                         feature_first,
   input logic                         feature_last,
   input logic [WEIGHT_WIDTH-1:0]      weight_stream,
   input logic [LAYER_SIZE_ORDER-1:0]  weight_id,
   input logic                         weight_first,
   input logic                         weight_last,
   output logic [OUTPUT_WIDTH-1:0]     output_stream,
   output logic [LAYER_SIZE_ORDER-1:0] output_id,
   output logic                        output_valid
   );

  //  Create types for shift register chains to fanout and fanin data - at high
  //  clock frequency
  logic [0:LAYER_SIZE][FEATURE_WIDTH-1:0]    feature_fanout_sr;
  logic [0:LAYER_SIZE][WEIGHT_WIDTH-1:0]     weight_fanout_sr;
  logic [0:LAYER_SIZE][LAYER_SIZE_ORDER-1:0] weight_id_fanout_sr;
  logic [0:LAYER_SIZE][LAYER_SIZE_ORDER-1:0] output_id_fanin_sr;
  logic [0:LAYER_SIZE][OUTPUT_WIDTH-1:0]     output_fanin_sr;
  logic [0:LAYER_SIZE][OUTPUT_WIDTH-1:0]     output_sig;

  logic [LAYER_SIZE:0]                       feature_first_sr;
  logic [LAYER_SIZE:0]                       feature_last_sr;
  logic [LAYER_SIZE:0]                       weight_first_sr;
  logic [LAYER_SIZE:0]                       weight_last_sr;
  logic [LAYER_SIZE:0]                       output_valid_sr;
  logic [LAYER_SIZE:0]                       weight_first_valid;
  logic [LAYER_SIZE:0]                       weight_last_valid;
  logic [LAYER_SIZE:0]                       output_valid_sig;


  //assert (LAYER_SIZE_ORDER < WEIGHT_MEM_ORDER)
  //  else $error("Number of neurons must not exceed number of weights");

  //  Shift register to fanout all streams to all neurons in layer
  always_ff @(posedge clk) begin
    feature_fanout_sr[0]   <= feature_stream;
    feature_first_sr[0]    <= feature_first;
    feature_last_sr[0]     <= feature_last;

    weight_fanout_sr[0]    <= weight_stream;
    weight_id_fanout_sr[0] <= weight_id;
    weight_first_sr[0]     <= weight_first;
    weight_last_sr[0]      <= weight_last;

    for (int i=1; i <= LAYER_SIZE; i++) begin
      // Flat Fanout, one layer of registers between all inputs and neurons
      feature_fanout_sr[i]   <= feature_fanout_sr[0];
      feature_first_sr[i]    <= feature_first_sr[0];
      feature_last_sr[i]     <= feature_last_sr[0];
      weight_fanout_sr[i]    <= weight_fanout_sr[i-1];
      weight_first_sr[i]     <= weight_first_sr[i-1];
      weight_last_sr[i]      <= weight_last_sr[i-1];
      weight_id_fanout_sr[i] <= weight_id_fanout_sr[i-1];

      if (weight_id_fanout_sr[i-1] == i) begin
        weight_first_valid[i] <= weight_first_sr[i-1];
        weight_last_valid[i]  <= weight_last_sr[i-1];
      end else begin
        weight_first_valid[i] <= '0;
        weight_last_valid[i]  <= '0;
      end

      if (output_valid_sig[i]) begin
        output_valid_sr[i-1]    <= '1;
        output_fanin_sr[i-1]    <= output_sig[i];
        output_id_fanin_sr[i-1] <= i;
      end else begin
        output_valid_sr[i-1]    <= output_valid_sr[i];
        output_fanin_sr[i-1]    <= output_fanin_sr[i];
        output_id_fanin_sr[i-1] <= output_id_fanin_sr[i];
      end
    end // for (i=1; i <= LAYER_SIZE; i++)
  end // always_ff @ (posedge clk)

  assign output_valid  = output_valid_sr[0];
  assign output_id     = output_id_fanin_sr[0];
  assign output_stream = output_fanin_sr[0];

  generate
    for (genvar i_g = 1; i_g <= LAYER_SIZE; i_g++) begin : g_NEURONS
      conv_neuron
        #
        (
         .FEATURE_WIDTH    (FEATURE_WIDTH),
         .WEIGHT_WIDTH     (WEIGHT_WIDTH),
         .WEIGHT_MEM_ORDER (WEIGHT_MEM_ORDER),
         .OUTPUT_WIDTH     (OUTPUT_WIDTH),
         .OUTPUT_SHIFT     (OUTPUT_SHIFT),
         .BIAS_SHIFT       (BIAS_SHIFT),
         .ReLU             (ReLU)
         )
      u_conv_neuron
        (
         .clk              (clk),
         .feature_stream   (feature_fanout_sr[i_g]),
         .feature_first    (feature_first_sr[i_g]),
         .feature_last     (feature_last_sr[i_g]),
         .weight_stream    (weight_fanout_sr[i_g]),
         .weight_first     (weight_first_valid[i_g]),
         .weight_last      (weight_last_valid[i_g]),
         .output_stream    (output_sig[i_g]),
         .output_valid     (output_valid_sig[i_g])
         );
    end // block: g_NEURONS
  endgenerate
endmodule // conv_neuron_layer_ffanout
