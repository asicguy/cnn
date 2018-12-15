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
//  Module for zero padding streams
//

module zero_pad_stream_mp
  #
  (
   parameter STREAM_WIDTH    = 8,
   parameter ZERO_PAD_BOTTOM = 1,
   parameter ZERO_PAD_RIGHT  = 1,
   parameter INPUT_HEIGHT    = 224,
   parameter INPUT_WIDTH     = 224
   )
  (
   input logic                     clk,
   input logic                     rst,
   input logic [STREAM_WIDTH-1:0]  stream_in,
   input logic                     stream_in_valid,
   output logic                    stream_in_ready,
   output logic [STREAM_WIDTH-1:0] stream_out,
   output logic                    stream_out_valid,
   input logic                     stream_out_ready
   );

  localparam OUTPUT_WIDTH  = INPUT_WIDTH  + ZERO_PAD_RIGHT;
  localparam OUTPUT_HEIGHT = INPUT_HEIGHT + ZERO_PAD_BOTTOM;

  localparam ROW_BITS = $clog2(OUTPUT_HEIGHT);
  localparam COL_BITS = $clog2(OUTPUT_WIDTH);

  logic [ROW_BITS-1:0]             row;
  logic [COL_BITS-1:0]             col;
  logic                            op_data;
  logic                            adv;

  assign stream_out_valid = op_data ? stream_in_valid  : '1;
  assign stream_out       = op_data ? stream_in        : '0;

  assign stream_in_ready  = op_data ? stream_out_ready : '0;

  assign adv              = op_data ? stream_out_ready & stream_in_valid : stream_out_ready;

  always_ff @(posedge clk) begin
    if (adv) begin
      if (col == OUTPUT_WIDTH-1) begin
        col <= '0;
        if (row == OUTPUT_HEIGHT-1) begin
          row <= '0;
        end else begin
          row <= row + 1'b1;
        end
      end else begin
        col <= col + 1'b1;
      end
      if ((row < INPUT_HEIGHT-1) || (row == OUTPUT_HEIGHT-1)) begin
        if (col == OUTPUT_WIDTH-1) begin
          op_data <= '1;
        end
      end else if (row < INPUT_HEIGHT) begin
        if (col == INPUT_WIDTH-1) begin
          op_data <= '0;
        end
      end
    end // if (adv)

    if (rst) begin
      op_data <= '1;
      row     <= '0;
      col     <= '0;
    end
  end // always_ff @ (posedge clk)
endmodule // zero_pad_stream_mp
