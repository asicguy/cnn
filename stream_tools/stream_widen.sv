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
//  Module for widening stream widths to multiple parallel features
//

module stream_widen
  #
  (
   parameter STREAM_WIDTH          = 8,
   parameter STREAM_OUT_MULTIPLIER = 3,
   parameter STREAM_OUT_WIDTH      = STREAM_WIDTH * STREAM_OUT_MULTIPLIER
   )
  (
   input logic                         clk,
   input logic                         rst,
   input logic [STREAM_WIDTH-1:0]      stream_in,
   input logic                         stream_in_valid,
   input logic                         stream_in_first,
   input logic                         stream_in_last,
   output logic [STREAM_OUT_WIDTH-1:0] stream_out,
   output logic                        stream_out_valid,
   output logic                        stream_out_first,
   output logic                        stream_out_last
   );

  logic [STREAM_OUT_WIDTH-1:0]         stream_out_sr;
  logic [STREAM_OUT_MULTIPLIER-1:0]    stream_out_valid_sr;
  logic [STREAM_OUT_MULTIPLIER-1:0]    stream_out_first_sr;
  logic [STREAM_OUT_MULTIPLIER-1:0]    stream_out_last_sr;
  logic                                stream_in_valid_r1;

  always_ff @(posedge clk) begin
    if (stream_in_valid) begin
      stream_out_sr <= {stream_in, stream_out_sr[STREAM_OUT_WIDTH-1:STREAM_WIDTH]};
      if (stream_in_first) begin
        stream_out_valid_sr                          <= '0;
        stream_out_valid_sr[STREAM_OUT_MULTIPLIER-1] <= '1;
      end else begin
        stream_out_valid_sr <= {stream_out_valid_sr[0], stream_out_valid_sr[STREAM_OUT_MULTIPLIER-1:1]};
      end
      stream_out_first_sr <= {stream_in_first, stream_out_first_sr[STREAM_OUT_MULTIPLIER-1:1]};
      stream_out_last_sr  <= {stream_in_last,  stream_out_last_sr[STREAM_OUT_MULTIPLIER-1:1]};
    end

    stream_in_valid_r1 <= stream_in_valid;

    if (stream_in_valid_r1) begin
      stream_out_valid <= stream_out_valid_sr[0];
      stream_out       <= stream_out_sr;
      stream_out_first <= stream_out_first_sr[0];
      stream_out_last  <= stream_out_last_sr[STREAM_OUT_MULTIPLIER-1];
    end else begin
      stream_out_valid <= '0;
    end

    if (rst) begin
      stream_out_valid_sr    <= '0;
      stream_out_valid_sr[0] <= '1;
    end
  end // always_ff @ (posedge clk)
endmodule // stream_widen
