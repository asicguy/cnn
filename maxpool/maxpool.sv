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
//  maxpool.sv
//  Max Pool operation
//

module maxpool
  #
  (
   parameter FEATURE_WIDTH         = 8,
   parameter NO_FEATURE_PLANES_PAR = 3,
   parameter NO_FEATURE_PLANES_SER = 3,
   parameter POOL_SIZE             = 4,
   // Calculated parameters
   parameter STREAM_WIDTH          = FEATURE_WIDTH * NO_FEATURE_PLANES_PAR
   )
  (
   input logic                     clk,
   input logic                     rst,
   input logic [STREAM_WIDTH-1:0]  feature_stream,
   input logic                     feature_valid,
   input logic                     feature_first,
   input logic                     feature_last,
   output logic [STREAM_WIDTH-1:0] max_feature_stream,
   output logic                    max_feature_valid
   );

  parameter POOL_BITS        = $clog2(POOL_SIZE);
  parameter SER_FEATURE_BITS = $clog2(NO_FEATURE_PLANES_SER);

  logic [0:NO_FEATURE_PLANES_SER-1][0:NO_FEATURE_PLANES_PAR-1][FEATURE_WIDTH-1:0] max_memory;

  logic [POOL_BITS:0]                                 pool_count;
  logic [SER_FEATURE_BITS-1:0]                        ser_feature_count;
  logic                                               feature_first_q;
  logic                                               feature_last_q;
  logic [NO_FEATURE_PLANES_SER-1:0]                   ser_feature_onehot;
  logic [NO_FEATURE_PLANES_SER-1:0]                   ser_feature_onehot_r1;

  logic [0:NO_FEATURE_PLANES_SER-1][0:NO_FEATURE_PLANES_PAR-1][FEATURE_WIDTH-1:0] max_feature_stream_i;
  logic                                                                           max_feature_valid_i;

  always_ff @(posedge clk) begin
    ser_feature_onehot_r1 <= ser_feature_onehot;
    for (int i = 0; i < NO_FEATURE_PLANES_PAR; i++) begin
      for (int j = 0; j < NO_FEATURE_PLANES_PAR; j++) begin
        if (ser_feature_onehot_r1[j]) begin
          max_feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH] <= max_feature_stream_i[j][i];
        end
      end
    end

    max_feature_valid   <= max_feature_valid_i;
    max_feature_valid_i <= feature_valid & feature_last_q;

    if (feature_valid) begin
      if (feature_first) begin
        feature_first_q <= '1;
      end
      if (feature_first || feature_first_q) begin
        for (int i = 0; i < NO_FEATURE_PLANES_PAR; i++) begin
          for (int j = 0; j < NO_FEATURE_PLANES_SER; j++) begin
            if (ser_feature_onehot[j]) begin
              max_memory[j][i] <= feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH];
            end
          end
        end
      end else if (feature_last_q) begin
        for (int i = 0; i < NO_FEATURE_PLANES_PAR; i++) begin
          for (int j = 0; j < NO_FEATURE_PLANES_SER; j++) begin
            if (ser_feature_onehot[j]) begin
              if (max_memory[j][i] > feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH]) begin
                max_feature_stream_i[j][i] <= max_memory[j][i];

              end else begin
                max_feature_stream_i[j][i] <= feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH];
              end
            end
          end
        end
      end else begin
        for (int i = 0; i < NO_FEATURE_PLANES_PAR; i++) begin
          for (int j = 0; j < NO_FEATURE_PLANES_SER; j++) begin
            if (ser_feature_onehot[j]) begin
              if (max_memory[j][i] < feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH]) begin
                max_memory[j][i] <= feature_stream[FEATURE_WIDTH*i+:FEATURE_WIDTH];
              end
            end
          end
        end
      end

      if (ser_feature_count == NO_FEATURE_PLANES_SER-1) begin
        ser_feature_count <= '0;
        if (feature_first_q) feature_first_q <= '0;
        if (pool_count == POOL_SIZE-1) begin
          pool_count     <= '0;
          feature_last_q <= '0;
        end else begin
          pool_count <= pool_count + 1'b1;
        end
        if (pool_count == POOL_SIZE-2) begin
          feature_last_q <= '1;
        end
      end else begin
        ser_feature_count <=  ser_feature_count + 1'b1;
      end

      ser_feature_onehot <= {ser_feature_onehot[NO_FEATURE_PLANES_SER-2:0],
                             ser_feature_onehot[NO_FEATURE_PLANES_SER-1]};

    end // if (feature_valid)

    if (rst) begin
      ser_feature_count     <= '0;
      ser_feature_onehot    <= '0;
      ser_feature_onehot[0] <= '1;
      feature_first_q       <= '0;
      feature_last_q        <= '0;
      pool_count            <= '0;
    end

    // write (l, to_integer(pool_count));
    // write (l, string'(" "));
    // write (l, to_integer(ser_feature_count));
    // write (l, string'(" "));
    // if feature_valid = '1' then
    //   write (l, string'("V"));
    // end if;
    // if feature_first_q = '1'  or feature_first = '1' then
    //   write (l, string'("F"));
    // end if;
    // if feature_last_q = '1' then
    //   write (l, string'("L"));
    // end if;
    // writeline (output, l);
  end // always_ff @ (posedge clk)

endmodule // maxpool
