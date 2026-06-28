`timescale 1ns / 1ps
`include "define.vh"

module data_mem (
    input               clk,
    input               dwe,
    input        [ 2:0] i_funct3,
    input        [31:0] daddr,
    input        [31:0] dwdata,
    output logic [31:0] drdata
);
    logic [3:0] bwe;
    logic [31:0] repeated_data, load_data;
    //assign word_addr = (daddr >> 2);

    data_ram U_DATA_RAM (
        .clk(clk),
        .dwe(dwe),
        .bwe(bwe),
        .daddr(daddr),
        .data_in(repeated_data),
        .data_out(load_data)

    );


    store_data U_STORE_DATA (
        .dwe(dwe),
        .i_funct3(i_funct3),
        .daddr(daddr),
        .dwdata(dwdata),
        .repeated_data(repeated_data),
        .bwe(bwe)  //byte unit we
    );

    load_data U_LOAD_DATA (
        .i_funct3(i_funct3),
        .load_data(load_data),
        .daddr_align(daddr[1:0]),
        .drdata(drdata)
    );
endmodule

//parsing and align logic
module store_data (
    input dwe,
    input [2:0] i_funct3,
    input [31:0] daddr,
    input [31:0] dwdata,
    output [31:0] repeated_data,
    output [3:0] bwe  //byte unit we
);




    data_reapeater U_DATA_REPEAT (
        .dwdata(dwdata),
        .funct3(i_funct3),
        .repeated_data(repeated_data)
    );
    we_gen U_WE_GEN (
        .funct3(i_funct3),
        .dwe(dwe),
        .daddr(daddr),
        .bwe(bwe)
    );
endmodule

module data_reapeater (
    input [31:0] dwdata,
    input [2:0] funct3,
    output logic [31:0] repeated_data
);
    always_comb begin
        repeated_data = 0;
        case (funct3)
            `SW: repeated_data = dwdata;
            `SH: repeated_data = {2{dwdata[15:0]}};
            `SB: repeated_data = {4{dwdata[7:0]}};
        endcase
    end
endmodule


module we_gen (
    input        [ 2:0] funct3,
    input               dwe,
    input        [31:0] daddr,
    output logic [ 3:0] bwe


);
    always_comb begin
        bwe = 4'b0000;
        if (dwe) begin
            case (funct3)
                `SW: bwe = 4'b1111;
                `SH: begin
                    case (daddr[1])
                        1'b0: bwe = 4'b0011;
                        1'b1: bwe = 4'b1100;
                    endcase
                end
                `SB: begin
                    case (daddr[1:0])
                        2'b00: bwe = 4'b0001;
                        2'b01: bwe = 4'b0010;
                        2'b10: bwe = 4'b0100;
                        2'b11: bwe = 4'b1000;
                    endcase
                end
            endcase
        end
    end
endmodule

module load_data (
    input [2:0] i_funct3,
    input [31:0] load_data,
    input [1:0] daddr_align,  // <-- Added offset input
    output logic [31:0] drdata
);
    logic [ 7:0] data_byte;
    logic [15:0] data_half;

    // MUX for selecting the correct byte based on daddr[1:0]
    always_comb begin
        case (daddr_align)
            2'b00: data_byte = load_data[7:0];
            2'b01: data_byte = load_data[15:8];
            2'b10: data_byte = load_data[23:16];
            2'b11: data_byte = load_data[31:24];
        endcase
    end

    // MUX for selecting the correct half-word based on daddr[1]
    always_comb begin
        case (daddr_align[1])
            1'b0: data_half = load_data[15:0];
            1'b1: data_half = load_data[31:16];
        endcase
    end

    // Formatting the final data with sign/zero extension
    always_comb begin
        drdata = 32'b0;
        case (i_funct3)
            `LW: drdata = load_data;
            `LH:
            drdata = {{16{data_half[15]}}, data_half};  // Fixed sign extension
            `LB:
            drdata = {{24{data_byte[7]}}, data_byte};  // Fixed sign extension
            `LBU:
            drdata = {
                24'b0, data_byte
            };  // Fixed bug: 8-bit to 32-bit zero extend
            `LHU: drdata = {16'b0, data_half};  // Zero extend half-word
            default: drdata = 32'b0;
        endcase
    end
endmodule


module data_ram (
    input clk,
    input dwe,
    input [3:0] bwe,
    input [31:0] daddr,
    input [31:0] data_in,
    output logic [31:0] data_out

);
    //word address BRAM
    logic [31:0] dmem[0:1023];  //1024bit
    always_ff @(posedge clk) begin
        if (bwe[0]) dmem[daddr[31:2]][7:0] <= data_in[7:0];
        if (bwe[1]) dmem[daddr[31:2]][15:8] <= data_in[15:8];
        if (bwe[2]) dmem[daddr[31:2]][23:16] <= data_in[23:16];
        if (bwe[3]) dmem[daddr[31:2]][31:24] <= data_in[31:24];
    end

    always_comb begin
        if (!dwe) data_out = dmem[daddr[31:2]][31:0];
        else data_out = 32'hxxxxxxxx;

    end

endmodule



