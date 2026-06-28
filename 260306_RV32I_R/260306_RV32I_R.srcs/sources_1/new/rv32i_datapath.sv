`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst,
    input         rf_we,
    input         jal,
    input         jalr,
    input         branch,
    input         alu_src,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    input  [ 2:0] rfwd_src,
    output [31:0] instr_addr,
    output [31:0] daddr,
    output [31:0] dwdata

);
    logic [31:0] rd1, rd2, alu_result, imm_data, alusr2_data;
    logic [31:0] rfwb_data, auipc, j_type;
    logic btaken;
    assign daddr  = alu_result;
    assign dwdata = rd2;

    program_counter U_PC (
        .clk            (clk),
        .rst            (rst),
        .btaken         (btaken),
        .branch         (branch),      //from control unit for b type
        .jal            (jal),
        .jalr           (jalr),
        .imm_data       (imm_data),
        .rs1            (rd1),
        .program_counter(instr_addr),
        .pc_4_out       (j_type),
        .pc_imm_out     (auipc)

    );
    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .RA1(instr_data[19:15]),
        .RA2(instr_data[24:20]),
        .WA(instr_data[11:7]),
        .wdata(rfwb_data),
        .rf_we(rf_we),
        .RD1(rd1),
        .RD2(rd2)
    );
    imm_extender U_IMM_EXTEND (
        .instr_data(instr_data),
        .imm_data  (imm_data)

    );



    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0(rd2),
        .in1(imm_data),
        .mux_sel(alu_src),
        .out_mux(alusr2_data)
    );


    alu U_ALU (
        .rd1(rd1),
        .rd2(alusr2_data),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .btaken(btaken)
    );

    //to register file
    mux_5x1 U_WB_MUX (
        .in0(alu_result),  //alu_result
        .in1(drdata),
        .in2(imm_data),
        .in3(auipc),  //from pc+imm extend, for AUIPC
        .in4(j_type),  //from pc+4
        .mux_sel(rfwd_src),
        .out_mux(rfwb_data)
    );
endmodule

module mux_5x1 (
    input [31:0] in0,
    input [31:0] in1,
    input [31:0] in2,
    input [31:0] in3,
    input [31:0] in4,
    input [2:0] mux_sel,
    output logic [31:0] out_mux
);


    always_comb begin
        case (mux_sel)
            3'b000:  out_mux = in0;
            3'b001:  out_mux = in1;
            3'b010:  out_mux = in2;
            3'b011:  out_mux = in3;
            3'b100:  out_mux = in4;
            default: out_mux = 32'hxxxxxxxx;
        endcase
    end
endmodule

module mux_2x1 (
    input [31:0] in0,
    input [31:0] in1,
    input mux_sel,
    output logic [31:0] out_mux
);
    assign out_mux = (mux_sel) ? in1 : in0;
endmodule

module imm_extender (
    input [31:0] instr_data,
    output logic [31:0] imm_data

);
    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])  //opcode
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE, `JL_TYPE: begin  //load
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}},
                    instr_data[7],  //imm bit 11
                    instr_data[30:25],  //imm bit 10:5
                    instr_data[11:8],  //imm bit 4:1
                    1'b0
                };
            end
            `UA_TYPE, `UL_TYPE: begin
                imm_data = {instr_data[31:12], {12{1'b0}}};
            end
            `J_TYPE: begin
                imm_data = {
                    {12{instr_data[31]}},  //20     :12bit extended
                    instr_data[19:12],  //19:12     :8bit
                    instr_data[20],  //11          :1bit
                    instr_data[30:21],  //10:1      :10bit
                    1'b0
                };
            end

        endcase
    end
endmodule

module register_file (
    input         clk,
    input         rst,
    input  [ 4:0] RA1,    //Instruction Code RS1
    input  [ 4:0] RA2,    //Instruction Code RS2
    input  [ 4:0] WA,     //Instruction Code RD
    input  [31:0] wdata,  //Instruction RD write data
    input         rf_we,  //Instruction RD write enable
    output [31:0] RD1,    //Register File RS1 output
    output [31:0] RD2     //Register File RS2 output
);
    logic [31:0] register_file[1:31];  //x0 must have zero value
`ifdef SIMULATION
    initial begin
        for (int i = 1; i < 32; i++) begin
            register_file[i] = i;
        end

    end
`endif

    always_ff @(posedge clk) begin  //because of if endif, modified

        if (!rst && rf_we) begin
            if (WA != 5'd0) begin
                register_file[WA] <= wdata;
            end
        end
    end

    // output CL
    assign RD1 = (RA1!=0)?register_file[RA1]:0;   //because of if endif, modified
    assign RD2 = (RA2 != 0) ? register_file[RA2] : 0;
endmodule

module alu (
    input        [31:0] rd1,          //RS1
    input        [31:0] rd2,          //RS2
    input        [ 3:0] alu_control,  //funct7[6], funct3
    output logic [31:0] alu_result,
    output logic        btaken        //for b type, comparator out
);
    always_comb begin
        alu_result = 32'b0;

        case (alu_control)
            `ADD: alu_result = rd1 + rd2;
            `SUB: alu_result = rd1 - rd2;  //sub rd=rs1-rs2
            `SLL: alu_result = rd1 << rd2[4:0];  //sll rd
            `SLT: alu_result = ($signed(rd1) < $signed(rd2)) ? 1 : 0;  //slt rd
            `SLTU: alu_result = (rd1 < rd2) ? 1 : 0;  //sltu rd
            `XOR: alu_result = rd1 ^ rd2;  //xor rd=rs1^rs2
            `SRL: alu_result = rd1 >> rd2[4:0];  //SRL rd=rs1>>rs2
            `SRA:
            alu_result = $signed(rd1) >>> rd2[4:0]
                ;  //SRL rd=rs1>>rs2, msb extension, arithmetic right shift
            `OR: alu_result = rd1 | rd2;  //or RD=RS1|RS2
            `AND: alu_result = rd1 & rd2;  //or RD=RS1&RS2




        endcase
    end

    // B-type comparator
    always_comb begin
        btaken = 0;
        case (alu_control)
            `BEQ: begin
                if (rd1 == rd2) btaken = 1;  //true: pc=pc+imm
                else btaken = 0;  //false:pc=pc+4
            end
            `BNE: begin
                if (rd1 != rd2) btaken = 1;  //true: pc=pc+imm
                else btaken = 0;  //false:pc=pc+4
            end

            `BLT: begin
                if ($signed(rd1) < $signed(rd2)) btaken = 1;
                else btaken = 0;
            end
            `BGE: begin
                if ($signed(rd1) >= $signed(rd2)) btaken = 1;
                else btaken = 0;
            end
            `BLTU: begin
                if (rd1 < rd2) btaken = 1;
                else btaken = 0;
            end
            `BGEU: begin
                if (rd1 >= rd2) btaken = 1;
                else btaken = 0;
            end

        endcase

    end
endmodule

module program_counter (
    input         clk,
    input         rst,
    input         branch,
    input         btaken,           //from alu for btype
    input         jal,
    input         jalr,
    input  [31:0] imm_data,
    input  [31:0] rs1,
    output [31:0] program_counter,
    output [31:0] pc_4_out,         //for J type, PC+4
    output [31:0] pc_imm_out        //for UA type, PC+imm

);
    logic [31:0] pc_next, pc_jtype, pc_imm_calc;
    //assign pc_imm = pc_imm_out;  //for UA type, PC+IMM

    // LSB Masking for JALR: force LSB to 0 if jalr is active
    //assign pc_imm_out = jalr ? {pc_imm_calc[31:1], 1'b0} : pc_imm_calc;

    //jalr mux
    mux_2x1 PC_JTYPE_MUX (
        .in0(program_counter),  //sel0
        .in1(rs1),  //sel1
        .mux_sel(jalr),
        .out_mux(pc_jtype)
    );
    pc_alu U_PC_IMM (
        .a(imm_data),
        .b(pc_jtype),
        .pc_alu_out(pc_imm_calc)
    );
    pc_alu U_PC_4 (
        .a(32'd4),
        .b(program_counter),
        .pc_alu_out(pc_4_out)
    );
    mux_2x1 PC_NEXT_MUX (
        .in0(pc_4_out),  //sel0
        .in1(pc_imm_out),  //sel1
        .mux_sel(jal | (btaken & branch)),
        .out_mux(pc_next)
    );
    mux_2x1 PC_JALR_0_MUX (
        .in0(pc_imm_calc),  //sel0
        .in1({pc_imm_calc[31:1], 1'b0}),  //sel1
        .mux_sel(jalr),
        .out_mux(pc_imm_out)
    );

    register U_PC_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_next),
        .data_out(program_counter)
    );
endmodule


module pc_alu (
    input [31:0] a,
    input [31:0] b,
    output logic [31:0] pc_alu_out
);
    assign pc_alu_out = a + b;
endmodule
module register (
    input         clk,
    input         rst,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end
    assign data_out = register;
endmodule


