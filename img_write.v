module image_write
#(
    parameter WIDTH = 956,                 // Image width
    parameter HEIGHT = 635,                // Image height
    parameter INFILE = "output.bmp",       // Image file 
    parameter BMP_HEADER_NUM = 54          // Header for BMP image
)

(
    input HCLK,                   // clock
    input HRESETn,                // Reset (Active Low)
    input hsync,                  // Hsync pulse
    input [7:0] DATA_WRITE_R0,    // Red 8 - bit data (Odd)
    input [7:0] DATA_WRITE_G0,    // Green 8 - bit data (Odd)
    input [7:0] DATA_WRITE_B0,    // Blue 8 - bit data (Odd)
    input [7:0] DATA_WRITE_R1,    // Red 8 - bit data (Even)
    input [7:0] DATA_WRITE_G1,    // Green 8 - bit data (Even)
    input [7:0] DATA_WRITE_B1,    // Blue 8 - bit data (Even)
    
    output reg Write_Done
);

integer BMP_header [0:BMP_HEADER_NUM - 1];   // BMP Header

reg [7:0] out_BMP [0:WIDTH*HEIGHT*3 - 1];   // Temperoary memory for image
reg [18:0] data_count;                      // Counting data

wire done;                                  // Done flag

// Counting variables
integer i, k, l, m, fd;

// ------ Header data for bmp image ------ //
initial
    begin
        BMP_header[0] = 66;
        BMP_header[1] = 77;
        BMP_header[2] = 54;
        BMP_header[3] = 0;
        BMP_header[4] = 18;
        BMP_header[5] = 0;
        BMP_header[6] = 0;
        BMP_header[7] = 0;
        BMP_header[8] = 0;
        BMP_header[9] = 0;
        BMP_header[10] = 54;
        BMP_header[11] = 0;
        BMP_header[12] = 0;
        BMP_header[13] = 0;
        BMP_header[14] = 40;
        BMP_header[15] = 0;
        BMP_header[16] = 0;
        BMP_header[17] = 0;
        BMP_header[18] = 0;
        BMP_header[19] = 3;
        BMP_header[20] = 0;
        BMP_header[21] = 0;
        BMP_header[22] = 0;
        BMP_header[23] = 2;
        BMP_header[24] = 0;
        BMP_header[25] = 0;
        BMP_header[26] = 1;
        BMP_header[27] = 0;
        BMP_header[28] = 24;
        BMP_header[29] = 0;
        BMP_header[30] = 0;
        BMP_header[31] = 0;
        BMP_header[32] = 0;
        BMP_header[33] = 0;
        BMP_header[34] = 0;
        BMP_header[35] = 0;
        BMP_header[36] = 0;
        BMP_header[37] = 0;
        BMP_header[38] = 0;
        BMP_header[39] = 0;
        BMP_header[40] = 0;
        BMP_header[41] = 0;
        BMP_header[42] = 0;
        BMP_header[43] = 0;
        BMP_header[44] = 0;
        BMP_header[45] = 0;
        BMP_header[46] = 0;
        BMP_header[47] = 0;
        BMP_header[48] = 0;
        BMP_header[49] = 0;
        BMP_header[50] = 0;
        BMP_header[51] = 0;
        BMP_header[52] = 0;
        BMP_header[53] = 0;
    end        
    
// Row and column counting for temperoary memory of image
always @ (posedge HCLK, negedge HRESETn)  
    begin
        if(!HRESETn)
            begin
                l <= 0;
                m <= 0;
            end
        
        else
            begin
                if(hsync)
                    begin
                        if(m == WIDTH/2 - 1)
                            begin
                                m <= 0;
                                l <= l + 1;     // Count to obtain row index of the out_BMP temperoary memory to save image data
                            end
                            
                        else
                            begin
                                m <= m + 1;    // Count to obtain column index of the out_BMP temperoary memory to save image data
                            end
                    end
             end
    end

// Writing RGB even and odd data to the temp memory
always @ (posedge HCLK, negedge HRESETn)  
    begin
        if(!HRESETn)
            begin
                for(k = 0; k < WIDTH*HEIGHT*3; k = k + 1)
                    begin
                        out_BMP[k] <= 0;
                    end
            end
       
       else
        begin
            if(hsync)
                begin
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m + 2] <= DATA_WRITE_R0;
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m + 1] <= DATA_WRITE_G0;
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m] <= DATA_WRITE_B0;
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m + 5] <= DATA_WRITE_R1;
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m + 4] <= DATA_WRITE_G1;
                    out_BMP[WIDTH*3*(HEIGHT - 1 - 1) + 6*m + 3] <= DATA_WRITE_B1;
                end
        end
    end

// Data counting    
always @ (posedge HCLK, negedge HRESETn)  
    begin
        if(~HRESETn)
            begin
                data_count <= 0;
            end
            
        else
            begin
                if(hsync)
                    data_count <= data_count + 1;   // Pixels counting for create done flag
            end
    end
    
assign done = (data_count == 196607) ? 1'b1:1'b0;   // Done flag once all pixels were processed

always @ (posedge HCLK, negedge HRESETn)  
    begin
        if(~HRESETn)
            begin
                Write_Done <= 0;
            end
            
        else
            begin
                Write_Done <= done;
            end
    end
    
// ------ Write .bmp file ------ //
initial
    begin
        fd = $fopen(INFILE, "wb+");
    end

always @ (Write_Done)
    begin
        if(Write_Done == 1'b1)
            begin
                for(i = 0; i < BMP_HEADER_NUM; i = i + 1)
                    begin
                        $fwrite(fd, "%c", BMP_header[i][7:0]);  // Write the header
                    end
                    
                for(i = 0; i < WIDTH*HEIGHT*3; i = i + 6)
                // Write R0, B0, G0, R1, G1, B1 (6 bytes)
                    begin
                        $fwrite(fd, "%c", out_BMP[i][7:0]);    
                        $fwrite(fd, "%c", out_BMP[i + 1][7:0]);
                        $fwrite(fd, "%c", out_BMP[i + 2][7:0]);
                        $fwrite(fd, "%c", out_BMP[i + 3][7:0]);
                        $fwrite(fd, "%c", out_BMP[i + 4][7:0]);
                        $fwrite(fd, "%c", out_BMP[i + 5][7:0]);
                    end
            end
    end
endmodule