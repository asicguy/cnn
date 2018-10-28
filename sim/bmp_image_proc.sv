// Refered C source is found per following URL
// http://www.fit.ac.jp/elec/7_online/lu/sample/bmp_image_proc.cpp"
// Original Verilog from: http://blog.naver.com/PostView.nhn?blogId=beahey&logNo=220544522247

`define Y_SIZE 2048    // maximum size of y dots
`define X_SIZE 2048    // maximum size of x dots
`define HIGH   255     // maxinum Strength
`define LOW    0       // minimum Strengh
`define LEVEL  256     //

module bmp_test;
  parameter read_filename   = "input.bmp";      // input file name
  parameter write_filename1 = "after_abc1.bmp"; // output file just after read
  parameter write_filename2 = "after_abc2.bmp"; // ouput file, Black and White with strength
  parameter write_filename3 = "after_abc3.bmp"; // output file Black and White with binary
  parameter [7:0] INTENSITY = 100;              // 0-255

  logic [31:0] biCompression;
  logic [31:0] biSizeImage;
  logic [31:0] biXPelsPerMeter;
  logic [31:0] biYPelsPerMeter;
  logic [31:0] biClrUsed;
  logic [31:0] biClrImportant;
  logic [15:0] bfType;
  logic [31:0] bfSize;
  logic [15:0] bfReserved1, bfReserved2;
  logic [31:0] bfOffBits;
  logic [31:0] biSize, biWidth, biHeight;
  logic [15:0] biPlanes, biBitCount;

  logic [7:0]  image_in [0:`Y_SIZE][0:`X_SIZE][0:2];  // input color matrix
  logic [7:0]  image_out [0:`Y_SIZE][0:`X_SIZE][0:2]; // output color matrix
  logic [7:0]  image_bw [0:`Y_SIZE][0:`X_SIZE];       //shades matrix

  //********************************************
  // Read 24Bit bitmap file
  //********************************************
  task readBMP(input [128*8:1] read_filename);
    integer fp;
    reg [7:0] byte8;
    begin
      // Open File
      fp = $fopen(read_filename, "rb"); //must be binary read mode
      if (!fp) begin
        $display("readBmp: Open error!\n");
        $finish;
      end

      $display("input file : %s\n", read_filename);
      // Read Header Informations
      $fread(bfType, fp);
      $fread(bfSize, fp);
      $fread(bfReserved1, fp);
      $fread(bfReserved2, fp);
      $fread(bfOffBits, fp);
      $fread(biSize, fp);
      $fread(biWidth, fp);
      if (swap_bytes(biWidth,32)%4) begin
        $display("Sorry, biWidth modulo 4 must be zero in this program. Found =%d",biWidth);
        $finish;
      end
      $fread(biHeight, fp);
      $fread(biPlanes, fp);
      $fread(biBitCount, fp);
      if (swap_bytes(biBitCount,16) !=24) begin
        $display("Sorry, biBitCount must be 24 in this program. Found=%d",biBitCount);
        $finish;
      end
      $fread(biCompression,   fp);
      $fread(biSizeImage,     fp);
      $fread(biXPelsPerMeter, fp);
      $fread(biYPelsPerMeter, fp);
      $fread(biClrUsed,       fp);
      $fread(biClrImportant,  fp);
      // Read RGB Data
      for (int i = 0; i < swap_bytes(biHeight, 32); i++) begin
        for (int j = 0; j < swap_bytes(biWidth, 32); j++) begin
          for (int k = 0; k < 3; k++) begin
            $fread(byte8,fp);
            image_in[swap_bytes(biHeight)-i][j][2-k] = byte8;
          end
        end
      end
      $display("Current POS=%d",$ftell(fp));
      $fclose(fp);
    end
  endtask

  //******************************************************
  // Output 24bits to bitmap file
  //******************************************************
  task writeBMP(input [128*8:1] write_filename,input O);
    integer fp;
    begin
      // Open File
      fp = $fopen(write_filename, "wb");//must be binary read mode
      if (!fp) begin
        $display("writeBmp: Open error!\n");
        $finish;
      end
      $display("output file : %s\n", write_filename);
      // Write Header Informations
      $fwrite(fp,"%c%c",                                         bfType[15:8],      bfType[7:0]);
      $fwrite(fp,"%c%c%c%c", bfSize[31:24],    bfSize[23:16],    bfSize[15:8],      bfSize[7:0]);
      $fwrite(fp,"%c%c",                                         bfReserved1[15:8], bfReserved1[7:0]);
      $fwrite(fp,"%c%c",                                         bfReserved2[15:8], bfReserved2[7:0]);
      $fwrite(fp,"%c%c%c%c", bfOffBits[31:24], bfOffBits[23:16], bfOffBits[15:8],   bfOffBits[7:0]);
      $fwrite(fp,"%c%c%c%c", biSize[31:24],    biSize[23:16],    biSize[15:8],      biSize[7:0]);
      $fwrite(fp,"%c%c%c%c", biWidth[31:24],   biWidth[23:16],   biWidth[15:8],     biWidth[7:0]);
      $fwrite(fp,"%c%c%c%c", biHeight[31:24],  biHeight[23:16],  biHeight[15:8],    biHeight[7:0]);
      $fwrite(fp,"%c%c",                                         biPlanes[15:8],    biPlanes[7:0]);
      $fwrite(fp,"%c%c",                                         biBitCount[15:8],  biBitCount[7:0]);
      $fwrite(fp,"%c%c%c%c", biCompression[31:24],   biCompression[23:16],   biCompression[15:8],   biCompression[7:0]);
      $fwrite(fp,"%c%c%c%c", biSizeImage[31:24],     biSizeImage[23:16],     biSizeImage[15:8],     biSizeImage[7:0]);
      $fwrite(fp,"%c%c%c%c", biXPelsPerMeter[31:24], biXPelsPerMeter[23:16], biXPelsPerMeter[15:8], biXPelsPerMeter[7:0]);
      $fwrite(fp,"%c%c%c%c", biYPelsPerMeter[31:24], biYPelsPerMeter[23:16], biYPelsPerMeter[15:8], biYPelsPerMeter[7:0]);
      $fwrite(fp,"%c%c%c%c", biClrUsed[31:24],       biClrUsed[23:16],       biClrUsed[15:8],       biClrUsed[7:0]);
      $fwrite(fp,"%c%c%c%c", biClrImportant[31:24],  biClrImportant[23:16],  biClrImportant[15:8],  biClrImportant[7:0]);
      // Write Bitmap Data
        for (int i=0; i < swap_bytes(biHeight); i++) begin
          for (int j=0; j < swap_bytes(biWidth); j++) begin
            for (int k=0; k < 3; k++)  begin
              if (O) $fwrite(fp,"%c",image_out[swap_bytes(biHeight)-i][j][2-k]);
              else   $fwrite(fp,"%c",image_in[swap_bytes(biHeight)-i][j][2-k]);
            end
          end
        end
      $display("Current WPOS=%d",$ftell(fp));
      $fclose(fp);
    end
  endtask
  //**********************************************
  // Convert RGB to 256 levels of Black & White *
  //**********************************************
  task BMPto256BW;
    integer a;
    begin
      for (int y=0; y < swap_bytes(biHeight); y++) begin
        for (int x=0; x < swap_bytes(biWidth); x++) begin
          a =$rtoi(0.3*image_in[y][x][0] + 0.59*image_in[y][x][1] + 0.11*image_in[y][x][2]);
          if (a<`LOW) a = `LOW;
          if (a>`HIGH) a = `HIGH;
          image_bw[y][x] = a;
        end
      end
    end
  endtask
  //****************************************
  // Convert Black & White to 24bit bitmap *
  //****************************************
  task BWto24BMP;
    integer  a;
    begin
      for (int y=0; y < swap_bytes(biHeight); y++) begin
        for (int x=0; x < swap_bytes(biWidth); x++) begin
          a = image_bw[y][x];
          image_out[y][x][0] = a;
          image_out[y][x][1] = a;
          image_out[y][x][2] = a;
        end
      end
    end
  endtask
  //****************************************
  // Make binary                     *
  //****************************************
  task toBinary( input [7:0] intensity);
    begin
      for (int y = 0; y < swap_bytes(biHeight); y++)begin
        for (int x = 0; x < swap_bytes(biWidth); x++) begin
          if(image_bw[y][x] >= intensity) image_bw[y][x] = `HIGH;
          else image_bw[y][x] = `LOW;
        end
      end
    end
  endtask // toBinary

  initial begin
    //Operation1
    readBMP(read_filename);   // Read ,
    writeBMP(write_filename1,0);//and just write without any conversion

    //Operation2
    BMPto256BW; //Convert RGB to Black & White
    BWto24BMP; //
    writeBMP(write_filename2,1);//Output

    //Operation3
    toBinary(INTENSITY);
    BWto24BMP;
    writeBMP(write_filename3,1);//Output
  end

  function [31:0] swap_bytes
    (
     input [31:0]  data_in,
     input integer bits = 32
     );
    logic [31:0]  data_shift;
    data_shift = data_in << 32-bits;
    for (int i = 0; i < bits/8; i++) begin
      swap_bytes[i*8+:8] = data_shift[(3-i)*8+:8];
    end
  endfunction // swap_bytes

endmodule
