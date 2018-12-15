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
//  FIFO buffer for narrowing stream widths to single feature
//
module stream_narrow
  #
  (
   parameter STREAM_WIDTH         = 8,
   parameter STREAM_IN_MULTIPLIER = 3,
   parameter BUFFER_DEPTH         = 9,
   parameter BUFFER_ACCEPT_SPACE  = 64,
   parameter BURST_LEVEL          = 1,
   // local parameters
   parameter STREAM_IN_WIDTH      = STREAM_WIDTH*STREAM_IN_MULTIPLIER
   )
  (
   input logic                        clk,
   input logic                        rst,
   input logic [STREAM_IN_WIDTH-1:0]  stream_in,
   input logic                        stream_in_valid,
   input logic                        stream_in_first,
   input logic                        stream_in_last,
   output logic                       stream_in_ready,
   output logic [STREAM_WIDTH-1:0]    stream_out,
   output logic                       stream_out_valid,
   output logic                       stream_out_first,
   output logic                       stream_out_last
   );

  localparam BUFFER_SIZE = 2**BUFFER_DEPTH;

  logic [STREAM_IN_WIDTH-1:0]         mem[0:BUFFER_SIZE-1];
  logic [BUFFER_SIZE-1:0]             first_mem;
  logic [BUFFER_SIZE-1:0]             last_mem;

  logic [BUFFER_DEPTH-1:0]            space_free;
  logic [BUFFER_DEPTH-1:0]            fifo_level;
  logic [BUFFER_DEPTH-1:0]            rd_addr;
  logic [BUFFER_DEPTH-1:0]            wr_addr;

  logic                               fifo_empty;

  logic [STREAM_IN_MULTIPLIER-1:0]    stream_out_select_valid;
  logic [STREAM_IN_WIDTH-1:0]         fifo_out;

  logic                               fifo_first_out;
  logic                               fifo_last_out;

  logic                               radv,radv_r1,radv_q;

  logic [STREAM_IN_WIDTH-1:0]         fifo_sr;
  logic [STREAM_IN_MULTIPLIER-1:0]    fifo_first_sr;
  logic [STREAM_IN_MULTIPLIER-1:0]    fifo_last_sr;
  logic [STREAM_IN_MULTIPLIER-1:0]    fifo_valid_sr;
  logic [STREAM_IN_MULTIPLIER-1:0]    radv_req_state;

  initial begin
    fifo_empty  = '1;
  end

  always @(posedge clk) begin

    stream_in_ready <= (space_free > BUFFER_ACCEPT_SPACE);

    if (stream_in_valid) begin
      wr_addr            <= wr_addr + 1'b1;
      mem[wr_addr]       <= stream_in;
      first_mem[wr_addr] <= stream_in_first;
      last_mem[wr_addr]  <= stream_in_last;
    end

    if (stream_in_valid && ~radv) begin
      space_free <= space_free - 1'b1;
      fifo_level <= fifo_level + 1'b1;
      fifo_empty <= '0;
    end else if (~stream_in_valid && radv) begin
      space_free <= space_free + 1'b1;
      fifo_level <= fifo_level - 1'b1;
      if (fifo_level == 1) begin
        fifo_empty <= '1;
      end
    end

    fifo_out       <= mem[rd_addr];
    fifo_first_out <= first_mem[rd_addr];
    fifo_last_out  <= last_mem[rd_addr];
    if (radv) begin
      rd_addr <= rd_addr + 1'b1;
    end

    radv_q  <= ~((fifo_first_out || fifo_last_out) && (fifo_level < BURST_LEVEL));
    radv_r1 <= radv;

    if (radv || ~radv_req_state[0]) begin
      radv_req_state <= {radv_req_state[STREAM_IN_MULTIPLIER-2:0],
                         radv_req_state[STREAM_IN_MULTIPLIER-1]};
    end

    if (radv_r1) begin
      fifo_sr                              <= fifo_out;
      fifo_first_sr                        <= '0;
      fifo_first_sr[0]                     <= fifo_first_out;
      fifo_last_sr                         <= '0;
      fifo_last_sr[STREAM_IN_MULTIPLIER-1] <= fifo_last_out;
      fifo_valid_sr                        <= '1;
    end else begin
      fifo_sr[STREAM_WIDTH*(STREAM_IN_MULTIPLIER-1)-1:0] <= fifo_sr[STREAM_IN_WIDTH-1:STREAM_WIDTH];
      fifo_valid_sr <= fifo_valid_sr >> 1;
      fifo_first_sr <= fifo_first_sr >> 1;
      fifo_last_sr  <= fifo_last_sr  >> 1;
    end

    stream_out       <= fifo_sr[STREAM_WIDTH-1:0];
    stream_out_valid <= fifo_valid_sr[0];
    stream_out_first <= fifo_first_sr[0];
    stream_out_last  <= fifo_last_sr[0];

    if (rst) begin
      space_free        <= '1;
      fifo_level        <= '0;
      rd_addr           <= '0;
      wr_addr           <= '0;
      radv_req_state    <= '0;
      radv_req_state[0] <= '1;
      fifo_valid_sr     <= '0;
      radv_r1           <= '0;
      fifo_empty        <= '1;
    end
  end // always_ff @ (posedge clk)

  assign radv = ~fifo_empty & radv_req_state[0] & radv_q;


 // debug_log0: process(clk) is
 //     variable l : line;
 //     variable count : integer := 0;
 //  begin
 //    if rising_edge(clk) then
 //      write (l,count);
 //      count := count+1;
 //      write (l, string'(": "));
 //      write (l,to_integer(unsigned(fifo_valid_sr)));
 //      write (l, string'(" "));
 //      write (l,to_integer(unsigned(fifo_first_sr)));
 //      write (l, string'(" "));
 //      write (l,to_integer(unsigned(fifo_last_sr)));
 //      write (l, string'(" "));
 //      write (l,to_integer(unsigned(wr_addr)));
 //      write (l, string'(" "));
 //      write (l,to_integer(unsigned(rd_addr)));
 //      write (l, string'(" "));
 //       write (l,to_integer(unsigned(space_free)));
 //      write (l, string'(" "));
 //       write (l,to_integer(unsigned(fifo_level)));
 //      write (l, string'(" "));
 //      // for i in 0 to buffer_size-1 loop
 //      //   if (last_mem(i) = '1') then
 //      //     write (l, string'(" L"));
 //      //     write (l, i);
 //      //   end if;
 //      // end loop;

 //      writeline(output,l);


 //    end if;
 //  end process;
endmodule // stream_narrow
