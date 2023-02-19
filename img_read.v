`include "parameter.v"
module image_read 
 #(
    parameter WIDTH = 956, // Image width
    parameter HEIGHT = 635, // Image height
    parameter INFILE = "sample.hex", // Image file                       
    parameter START_UP_DELAY = 100, // Delay during start up time
    parameter HSYNC_DELAY = 160, // Delay between HSYN pulses
    parameter VALUE = 50, // Value for Brightness operation
    parameter THRESHOLD = 90, // Threshold value for Threshold operation
    parameter SIGN = 1, // Sign value for brightness operation 
    parameter SizeOfWidth = 8, // Data width
    parameter SizeOfLengthReal = 1821180 // Image data: 956*635*3 (3 -> Pixel value: R, G, B)
)     
                                                                 
(
    input HCLK, // clock
    input HRESETn, // Reset (Active Low)

    output VSYNC, // Vertical Synchronous Pulse    
    output ctrl_done, // Done Flag

    output reg [7:0] DATA_R0, // 8 - bit Red Data (even)
    output reg [7:0] DATA_G0, // 8 - bit Green Data (even)
    output reg [7:0] DATA_B0, // 8 - bit Blue Data (even)
    output reg [7:0] DATA_R1, // 8 - bit Red Data (odd)
    output reg [7:0] DATA_G1, // 8 - bit Green Data (odd)
    output reg [7:0] DATA_B1, // 8 - bit Blue Data (odd)   
    output reg HSYNC // Horizontal Synchronous Pulse 
);



    // Parameters for FSM
    localparam ST_IDLE = 2'b00; // Idle Stae
    localparam ST_VSYNC = 2'b01; // State for creating VSYNC
    localparam ST_HSYNC = 2'b10; // State for creating HSYNC     
    localparam ST_DATA = 2'b11; // State for data processing

    reg [1:0] cstate; // Current state
    reg [1:0] nstate; // Next state
    reg start; // Trigger FSM beginning to operate
    reg HRESETn_d; // Delayed reset signal: used to create 'start' signal
    reg ctrl_vsync_run; // counter for vsync
    reg [8:0] ctrl_vsync_cnt; // counter for vsync counter
    reg ctrl_hsync_run; // counter for hsync 
    reg [8:0] ctrl_hsync_cnt; // counter for hsync counter
    reg ctrl_data_run; // Control signal data processing
    reg [31:0] in_memory [0:SizeOfLengthReal/4]; // Memory to store 32 - bit data image 
    reg [7:0] total_memory [0:SizeOfLengthReal/4]; // Memory to store 8 - bit data image
    reg [9:0] row; // Row index of the image
    reg [10:0] col; // Column index of the image
    reg [18:0] data_count; // Data counting for entire pixels of the image

    // Temperoary memory to save image data
    integer temp_JPG [0:WIDTH*HEIGHT*3 - 1];

    integer org_R [0:WIDTH*HEIGHT - 1]; // Temperoray storage for R component
    integer org_G [0:WIDTH*HEIGHT - 1]; // Temperoray storage for G component
    integer org_B [0:WIDTH*HEIGHT - 1]; // Temperoray storage for B component

    // Counting variaables
    integer i, j;

    // Temperorary variables in contrast and brightness operation
    integer tempR0, tempR1, tempG0, tempG1, tempB0, tempB1;

    // Temperorary variables in invert and threshold operation
    integer value, value1, value2, value3;

    // ------ Reading data from input file ------ //                                  
    initial
    begin
        $readmemh(INFILE, total_memory, 0, SizeOfLengthReal - 1);
    end

    // Using 3 intermediate signals RGB to save image data
    always @ (start)
    begin
        if(start == 1'b1)
        begin
            for(i = 0; i < WIDTH*HEIGHT*3; i = i + 1)
                begin
                    temp_JPG[i] = total_memory[i + 0][7:0];
                end

            for(i = 0; i < HEIGHT; i = i + 1)
                begin
                    for(j = 0; j < HEIGHT; j = j + 1)
                        begin
                            org_R[WIDTH*i + j] = temp_JPG[WIDTH*3*(HEIGHT - i - 1) + 3*j + 0]; // Save red component
                            org_G[WIDTH*i + j] = temp_JPG[WIDTH*3*(HEIGHT - i - 1) + 3*j + 1]; // Save green component
                            org_B[WIDTH*i + j] = temp_JPG[WIDTH*3*(HEIGHT - i - 1) + 3*j + 2]; // Save blue component
                        end
                end
        end
    end

    // ------ Creating a starting pulse (start) ------ //  
    always @ (posedge HCLK, negedge HRESETn)
    begin
        if(!HRESETn)
            begin
                start <= 0;
                HRESETn_d <= 0;
            end

        else
            begin
                HRESETn_d <= HRESETn;

                if(HRESETn == 1'b1 && HRESETn_d == 1'b0)
                    start <= 1'b1;
                else
                    start <= 1'b0;
            end
    end

    // ------ FSM for reading RGB data memory and creating hsync, vsync pulses ------ //   
    always @ (posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn)
            begin
                cstate <= ST_IDLE;
            end

        else
            begin
                cstate <= nstate; // Update nest state
            end
    end

    // ------ State Transitions ------ //   
    // IDLE. VSYNC. HSYNC. DATA
    // Referencce: State Diagram
    always @ (*)
    begin
        case(cstate)
            ST_IDLE: begin
                if(start)
                    nstate = ST_VSYNC;
                else
                    nstate = ST_IDLE;
            end

            ST_VSYNC: begin
                if(ctrl_vsync_cnt == START_UP_DELAY)
                    nstate = ST_HSYNC;
                else
                    nstate = ST_VSYNC;
            end

            ST_HSYNC: begin
                if(ctrl_hsync_cnt == HSYNC_DELAY)
                    nstate = ST_DATA;
                else
                    nstate = ST_HSYNC;
            end

            ST_DATA: begin
                if(ctrl_done)
                    nstate = ST_DATA;
                else
                    begin
                        if(col == WIDTH - 2)
                            nstate = ST_HSYNC;
                    end
            end

        endcase
    end

    // ------ Counting for time period of vsync, hsync, data processing ------ //            
    always @ (*)
    begin
        ctrl_vsync_run = 0;
        ctrl_hsync_run = 0;
        ctrl_data_run = 0;

        case(cstate)
            ST_VSYNC: begin
                ctrl_vsync_run = 1; // Trigger counting for vsync 
            end

            ST_HSYNC: begin
                ctrl_hsync_run = 1; // Trigger counting for hsync  
            end

            ST_DATA: begin
                ctrl_data_run = 1; // Trigger counting for data processing 
            end
        endcase
    end

    // Counters for vsync, hsync
    always @ (posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn)
            begin
                ctrl_vsync_cnt <= 0;
                ctrl_hsync_cnt <= 0;
            end

        else
            begin
                if(ctrl_vsync_run)
                    ctrl_vsync_cnt <= ctrl_vsync_cnt + 1; // counting for vsync
                else
                    ctrl_vsync_cnt <= 0;

                if(ctrl_hsync_run)
                    ctrl_hsync_cnt <= ctrl_hsync_cnt + 1; // counting for hsync
                else
                    ctrl_hsync_cnt <= 0;
            end
    end

    // Counting column and row index for reading memory
    always @ (posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn)
            begin
                row <= 0;
                col <= 0;
            end

        else
            begin
                if(ctrl_data_run)
                begin
                    if(col == WIDTH - 2)
                    begin
                        row <= row + 1;
                    end

                    if(col == WIDTH - 2)
                        col <= 0;
                    else
                        col <= col + 2; // Reading 2 pixels in parallel
                end
            end
    end

    // ------ Data counting ------ //
    always @ (posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn)
            begin
                data_count <= 0;
            end

        else
            begin
                if(ctrl_data_run)
                    data_count <= data_count + 1;
            end
    end

    assign VSYNC = ctrl_vsync_run;
    assign ctrl_done = (data_count == 196607) ? 1'b1:1'b0; // Done flag

    // ------ Image Processing ------ //
    always @ (*)
    begin
        HSYNC = 1'b0;
        DATA_R0 = 0;
        DATA_G0 = 0;
        DATA_B0 = 0;
        DATA_R1 = 0;
        DATA_G1 = 0;
        DATA_B1 = 0;

        if(ctrl_data_run)
        begin
            HSYNC = 1'b1;
                `ifdef BRIGHTNESS_OPERATION  
                                              
                 if(SIGN == 1)
                    begin
                        // ***** BRIGHTNESS ADDITION OPEARATION ***** //
                        // R0
                        tempR0 = org_R[WIDTH*row + col] + VALUE;
                        if(tempR0 > 255)
                            DATA_R0 = 255;
                        else
                            DATA_R0 = org_R[WIDTH*row + col] + VALUE;   
                            
                        // R1
                        tempR1 = org_R[WIDTH*row + col + 1] + VALUE;
                        if(tempR1 > 255)
                            DATA_R1 = 255;
                        else
                            DATA_R1 = org_R[WIDTH*row + col + 1] + VALUE;  
                        
                        // G0
                        tempG0 = org_G[WIDTH*row + col] + VALUE;
                        if(tempG0 > 255)
                            DATA_G0 = 255;
                        else
                            DATA_G0 = org_G[WIDTH*row + col] + VALUE;   
                            
                        // G1
                        tempR1 = org_G[WIDTH*row + col + 1] + VALUE;
                        if(tempG1 > 255)
                            DATA_G1 = 255;
                        else
                            DATA_G1 = org_G[WIDTH*row + col + 1] + VALUE;   
                            
                        // B0
                        tempB0 = org_B[WIDTH*row + col] + VALUE;
                        if(tempB0 > 255)
                            DATA_B0 = 255;
                        else
                            DATA_B0 = org_B[WIDTH*row + col] + VALUE;   
                            
                        // B1
                        tempB1 = org_B[WIDTH*row + col + 1] + VALUE;
                        if(tempB1 > 255)
                            DATA_B1 = 255;
                        else
                            DATA_B1 = org_B[WIDTH*row + col + 1] + VALUE;        
                    end  
                    
                else   
                    begin
                        // ***** BRIGHTNESS SUBTRACTION OPEARATION ***** //
                        // R0
                        tempR0 = org_R[WIDTH*row + col] - VALUE;
                        if(tempR0 < 0)
                            DATA_R0 = 255;
                        else
                            DATA_R0 = org_R[WIDTH*row + col] - VALUE;   
                            
                        // R1
                        tempR1 = org_R[WIDTH*row + col + 1] - VALUE;
                        if(tempR1 < 0)
                            DATA_R1 = 0;
                        else
                            DATA_R1 = org_R[WIDTH*row + col + 1] - VALUE;  
                        
                        // G0
                        tempG0 = org_G[WIDTH*row + col] - VALUE;
                        if(tempG0 < 0)
                            DATA_G0 = 0;
                        else
                            DATA_G0 = org_G[WIDTH*row + col] - VALUE;   
                            
                        // G1
                        tempR1 = org_G[WIDTH*row + col + 1] - VALUE;
                        if(tempG1 < 0)
                            DATA_G1 = 0;
                        else
                            DATA_G1 = org_G[WIDTH*row + col + 1] - VALUE;   
                            
                        // B0
                        tempB0 = org_B[WIDTH*row + col] - VALUE;
                        if(tempB0 < 0)
                            DATA_B0 = 0;
                        else
                            DATA_B0 = org_B[WIDTH*row + col] - VALUE;   
                            
                        // B1
                        tempB1 = org_B[WIDTH*row + col + 1] - VALUE;
                        if(tempB1 < 0)
                            DATA_B1 = 0;
                        else
                            DATA_B1 = org_B[WIDTH*row + col + 1] - VALUE;        
                    end  
                `endif      
                
                `ifdef INVERT_OPERATION   
                
                 // ***** INVERT OPEARATION ***** //     
                    DATA_R0 = 255 - org_R[WIDTH*row + col];
                    DATA_G0 = 255 - org_G[WIDTH*row + col];
                    DATA_B0 = 255 - org_B[WIDTH*row + col];
                    DATA_R1 = 255 - org_R[WIDTH*row + col + 1];
                    DATA_G1 = 255 - org_G[WIDTH*row + col + 1];
                    DATA_B1 = 255 - org_B[WIDTH*row + col + 1];
                `endif
                
                `ifdef BLACKandWHITE_OPEARATION
                
                // ***** BLACK AND WHITE OPEARATION ***** //
                    value2 = (org_R[WIDTH*row + col] + org_G[WIDTH*row + col] + org_B[WIDTH*row + col])/3;
                    DATA_R0 = value2;
                    DATA_G0 = value2;
                    DATA_B0 = value2;
                
                    value3 = (org_R[WIDTH*row + col + 1] + org_G[WIDTH*row + col + 1] + org_B[WIDTH*row + col + 1])/3;
                    DATA_R1 = value3;
                    DATA_G1 = value3;
                    DATA_B1 = value3;
                `endif 
                
                `ifdef THRESHOLD_OPEARATION
                
                // ***** BLACK AND WHITE OPEARATION ***** //  
                    value = (org_R[WIDTH*row + col] + org_G[WIDTH*row + col] + org_B[WIDTH*row + col])/3;                       
                    if(value > THRESHOLD)
                        begin
                            DATA_R0 = 255;
                            DATA_G0 = 255;
                            DATA_B0 = 255;
                        end
                        
                    else
                        begin
                            DATA_R0 = 0;
                            DATA_G0 = 0;
                            DATA_B0 = 0;   
                        end
                        
                    value1 = (org_R[WIDTH*row + col + 1] + org_G[WIDTH*row + col + 1] + org_B[WIDTH*row + col + 1])/3;       
                    if(value > THRESHOLD)
                        begin
                            DATA_R1 = 255;
                            DATA_G1 = 255;
                            DATA_B1 = 255;
                        end
                        
                    else
                        begin
                            DATA_R1 = 0;
                            DATA_G1 = 0;
                            DATA_B1 = 0;   
                        end
                `endif
            end
    end
endmodule