// Copyright (c) 2017, Alpha Data Parallel Systems Ltd.
// SystemVerilog port Copyright (c) 2018, Francis Bruno
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
//  feature_buffer.sv
//  FIFO buffer to extract region of interest from tensor
//
module feature_buffer
  #
  (
   FEATURE_WIDTH         = 8,
   NO_FEATURE_PLANES_PAR = 1,
   NO_FEATURE_PLANES_SER = 3,
   MASK_WIDTH            = 3,
   MASK_HEIGHT           = 3,
   FEATURE_PLANE_WIDTH   = 224,
   FEATURE_PLANE_HEIGHT  = 224,
   STRIDE                = 1,
   // Local parameters -- Do not modify at instantiation
   STREAM_BITS           = FEATURE_WIDTH*NO_FEATURE_PLANES_PAR
   )
  (
   input logic                    clk,
   input logic                    rst,
   input logic [STREAM_BITS-1:0]  feature_stream,
   input logic                    feature_valid,
   output logic                   feature_ready,
   output logic [STREAM_BITS-1:0] mask_feature_stream,
   output logic                   mask_feature_valid,
   input logic                    mask_feature_ready,
   output logic                   mask_feature_first,
   output logic                   mask_feature_last
   );

  localparam FEATURE_PLANE_WIDTH_BITS  = $clog2(FEATURE_PLANE_WIDTH*NO_FEATURE_PLANES_SER);
  localparam FEATURE_PLANE_HEIGHT_BITS = $clog2(FEATURE_PLANE_HEIGHT);
  localparam MEMORY_ROWS               = MASK_HEIGHT+2;
  localparam MEMORY_ROWS_BITS          = $clog2(MEMORY_ROWS);
  localparam MASK_HEIGHT_BITS          = $clog2(MASK_HEIGHT);
  localparam MASK_WIDTH_BITS           = $clog2(MASK_WIDTH*NO_FEATURE_PLANES_SER);

  logic [0:MEMORY_ROWS-1][0:FEATURE_PLANE_WIDTH*NO_FEATURE_PLANES_SER-1][FEATURE_WIDTH*NO_FEATURE_PLANES_PAR-1:0] mem;
  logic [0:MEMORY_ROWS-1][STREAM_BITS-1:0]                                                                        mem_out;
  logic [0:MEMORY_ROWS-1]                                 mem_out_valid;
  logic [FEATURE_PLANE_WIDTH_BITS-1:0]                    write_col_addr;
  logic [FEATURE_PLANE_HEIGHT_BITS-1:0]                   write_row_addr;
  logic [MEMORY_ROWS_BITS-1:0]                            write_row_mem_addr;
  logic [FEATURE_PLANE_WIDTH_BITS-1:0]                    read_col_addr;
  logic [FEATURE_PLANE_HEIGHT_BITS-1:0]                   read_row_addr;
  logic [FEATURE_PLANE_WIDTH_BITS-1:0]                    read_col_start_addr;

  logic [MEMORY_ROWS_BITS-1:0]                            read_row_mem_addr;
  logic [MEMORY_ROWS_BITS-1:0]                            read_row_start_mem_addr;

  logic [MASK_WIDTH_BITS-1:0]                             mask_col;
  logic [MASK_HEIGHT_BITS-1:0]                            mask_row;

  logic [MEMORY_ROWS-1:0]                                 memory_row_used;
  logic                                                   writer_ready;

  logic [MASK_HEIGHT-1:0]                                 reader_rows_required;

  logic                                                   mask_first;
  logic                                                   mask_first_e1;
  logic                                                   mask_last;
  logic                                                   mask_can_start;
  logic                                                   mask_read_running;
  logic                                                   mask_read_running_r1;
  logic                                                   mask_read_running_r2;
  logic                                                   mask_read_running_r3;

  logic [MEMORY_ROWS_BITS-1:0]                            next_write_row_mem_addr;

  //attribute ram_style : string;
  //attribute ram_style of mem : signal is "block";

  assign feature_ready = writer_ready;

  always @(posedge clk) begin
    // variable l : line;
    if (feature_valid && writer_ready) begin
      if (write_col_addr == FEATURE_PLANE_WIDTH*NO_FEATURE_PLANES_SER-1) begin
        write_col_addr <= '0;
        memory_row_used[write_row_mem_addr] <= '1;
        if (write_row_mem_addr == MEMORY_ROWS-1) begin
          next_write_row_mem_addr = '0;
        end else begin
          next_write_row_mem_addr = write_row_mem_addr + 1'b1;
        end

        write_row_mem_addr <= next_write_row_mem_addr;

      end else begin
        next_write_row_mem_addr = write_row_mem_addr;
        write_col_addr <= write_col_addr + 1'b1;
      end
    end else begin
      next_write_row_mem_addr = write_row_mem_addr;
    end

    writer_ready <= ~memory_row_used[next_write_row_mem_addr];

    if (feature_valid && writer_ready) begin
      for (int i=0; i < MEMORY_ROWS; i++) begin
        if (i == write_row_mem_addr) begin // Can we fix this to simply index the mem
          mem[i][write_col_addr] <= feature_stream;
        end
      end
    end

    mem_out_valid <= '0;

    for (int i = 0; i < MEMORY_ROWS; i++) begin
      if (i == read_row_mem_addr) begin
        mem_out[i] <= mem[i][read_col_addr];
        mem_out_valid[i] <= '1;
      end
    end

    for (int i = 0; i < MASK_HEIGHT; i++) begin
      if (read_row_start_mem_addr+i < MEMORY_ROWS) begin
        reader_rows_required[i] <= memory_row_used[read_row_start_mem_addr+i];
      end else begin
        reader_rows_required[i] <= memory_row_used[read_row_start_mem_addr+i-MEMORY_ROWS];
      end
    end

    mask_can_start <= &reader_rows_required && mask_feature_ready;

    mask_first_e1 <= '0;
    mask_first    <= mask_first_e1;
    mask_last     <= '0;

    if (~mask_read_running) begin
      //  allow 2 cycle gap between mask reads
      if (mask_can_start && ~mask_read_running_r3) begin
        read_col_addr     <= read_col_start_addr;
        read_row_mem_addr <= read_row_start_mem_addr;
        mask_col          <= '0;
        mask_row          <= '0;
        mask_first_e1     <= '1;
        mask_read_running <= '1;
      end
    end else begin
      if (mask_row == MASK_HEIGHT-1) begin
        if (mask_col == MASK_WIDTH*NO_FEATURE_PLANES_SER-1) begin
          mask_read_running <= '0;
          mask_last         <= '1;
        end else begin
          mask_col          <= mask_col + 1'b1;
          read_col_addr     <= read_col_addr + 1'b1;
        end
      end else begin
        if (mask_col == MASK_WIDTH*NO_FEATURE_PLANES_SER-1) begin
          mask_row <= mask_row + 1'b1;
          mask_col <= '0;
          if (read_row_mem_addr == MEMORY_ROWS-1) begin
            read_row_mem_addr <= '0;
          end else begin
            read_row_mem_addr <= read_row_mem_addr + 1'b1;
          end
          read_col_addr <= read_col_start_addr;
        end else begin
          mask_col      <= mask_col + 1'b1;
          read_col_addr <= read_col_addr + 1'b1;
        end
      end
    end

    mask_read_running_r1 <= mask_read_running;
    mask_read_running_r2 <= mask_read_running_r1;
    mask_read_running_r3 <= mask_read_running_r2;

    if (mask_last) begin
      if (read_col_start_addr == (FEATURE_PLANE_WIDTH-MASK_WIDTH)*NO_FEATURE_PLANES_SER) begin
        read_col_start_addr <= '0;
        if (read_row_addr == FEATURE_PLANE_HEIGHT-MASK_HEIGHT) begin
          for (int i = 0; i < MASK_HEIGHT; i++) begin
            if (read_row_start_mem_addr+i < MEMORY_ROWS) begin
              memory_row_used[read_row_start_mem_addr+i] <= '0;
            end else begin
              memory_row_used[read_row_start_mem_addr+i-MEMORY_ROWS] <= '0;
            end
          end
          read_row_addr <= '0;

          if (4'(read_row_start_mem_addr+MASK_HEIGHT) > (MEMORY_ROWS - 1)) begin
            read_row_start_mem_addr <= read_row_start_mem_addr + MASK_HEIGHT - MEMORY_ROWS;
          end else begin
            read_row_start_mem_addr <= read_row_start_mem_addr+MASK_HEIGHT;
          end

        end else begin
          for (int i = 0; i < STRIDE; i++) begin
            if ((read_row_start_mem_addr+i) < MEMORY_ROWS) begin
              memory_row_used[read_row_start_mem_addr+i] <= '0;
            end else begin
              memory_row_used[read_row_start_mem_addr+i-MEMORY_ROWS] <= '0;
            end
          end
          read_row_addr <= read_row_addr+STRIDE;

          if ((read_row_start_mem_addr+STRIDE) > (MEMORY_ROWS-1)) begin
            read_row_start_mem_addr <= read_row_start_mem_addr+STRIDE - MEMORY_ROWS;
          end else begin
            read_row_start_mem_addr <= read_row_start_mem_addr+STRIDE;
          end

        end
      end else begin
        read_col_start_addr <= read_col_start_addr+STRIDE*NO_FEATURE_PLANES_SER;
      end // else: !if(read_col_start_addr == (FEATURE_PLANE_WIDTH-MASK_WIDTH)*NO_FEATURE_PLANES_SER)
    end // if (mask_last)

    for (int i = 0; i < MEMORY_ROWS; i++) begin
      if (mem_out_valid[i]) mask_feature_stream <= mem_out[i];
    end

    mask_feature_valid <= mask_read_running_r1;
    mask_feature_first <= mask_first;
    mask_feature_last  <= mask_last;

    //  Synchronous reset, only for signals needing reset
    //  i.e. holding state
    if (rst) begin
      writer_ready            <= '0;
      write_col_addr          <= '0;
      write_row_mem_addr      <= '0;
      memory_row_used         <= '0;
      read_col_start_addr     <= '0;
      read_row_start_mem_addr <= '0;
      read_row_addr           <= '0;
      mask_read_running       <= '0;
    end
  end // always @ (posedge clk)
endmodule // feature_buffer
