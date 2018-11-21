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
//  FIFO buffer for narrowing stream of 256 bits to 48 bits
//  (32 words to 6 words)
//  Fully enforces flow control
//

module stream_narrow_32ton
  #
  (
   parameter           OUT_WORDS = 6,
   parameter           SB_WIDTH  = 16,
   parameter           RD_WIDTH  = 5,
   // calcuated parameters, don't change
   // could be localparams but problems with some tools
   parameter           OUT_WIDTH = OUT_WORDS*8
   )
  (
   input logic                  clk,
   input logic                  rst,
   input logic [255:0]          stream_in,
   input logic                  stream_in_valid,
   output logic                 stream_in_ready,
   output logic [OUT_WIDTH-1:0] stream_out,
   output logic                 stream_out_valid,
   input logic                  stream_out_ready
   );

  logic [767:0]                       stream_buffer;
  logic [95:0]                        buffer_used;
  logic [1:0]                         wr_addr;
  logic [RD_WIDTH-1:0]                rd_addr;

  logic [0:SB_WIDTH-1][OUT_WIDTH-1:0] sb_var;
  logic [SB_WIDTH-1:0]                bu_var;

  always_ff @(posedge clk) begin
    case (wr_addr)
      0: begin
        if (stream_in_ready && stream_in_valid) begin
          stream_in_ready      <= '0;
          stream_buffer[255:0] <= stream_in;
          buffer_used[31:0]    <= '1;
          wr_addr              <= wr_addr + 1'b1;
        end else begin
          stream_in_ready      <= ~buffer_used[31];
        end
      end
      1: begin
        if (stream_in_ready && stream_in_valid) begin
          stream_in_ready        <= '0;
          stream_buffer[511:256] <= stream_in;
          buffer_used[63:32]     <= '1;
          wr_addr                <= wr_addr + 1'b1;
        end else begin
          stream_in_ready        <= ~buffer_used[63];
        end
      end
      2: begin
        if (stream_in_ready && stream_in_valid) begin
          stream_in_ready        <= '0;
          stream_buffer[767:512] <= stream_in;
          buffer_used[95:64]     <= '1;
          wr_addr                <= '0;
        end else begin
          stream_in_ready        <= ~buffer_used[95];
        end
      end
    endcase // case (wr_addr)

    for (int i = 0; i < SB_WIDTH; i++) begin
      sb_var[i]  = stream_buffer[OUT_WIDTH*i+:OUT_WIDTH];
      if (OUT_WORDS == 3) // Check if we really need this if statement
        bu_var[i]  = buffer_used[OUT_WORDS*i];
      else if (OUT_WORDS == 6)
      bu_var[i]    = buffer_used[OUT_WORDS*i+OUT_WORDS-1];
    end
    stream_out       <= sb_var[rd_addr];
    stream_out_valid <= bu_var[rd_addr];
    if (bu_var[rd_addr] && stream_out_ready) begin
      rd_addr <= rd_addr + 1'b1;
      for (int i = 0; i < SB_WIDTH; i++) begin
        if (rd_addr == i) begin
          buffer_used[OUT_WORDS*i+:OUT_WORDS] <= '0;
        end
      end
    end

    if (rst) begin
      buffer_used     <= '0;
      wr_addr         <= '0;
      rd_addr         <= '0;
      stream_in_ready <= '0;
    end
  end // always_ff @ (posedge clk)
endmodule
