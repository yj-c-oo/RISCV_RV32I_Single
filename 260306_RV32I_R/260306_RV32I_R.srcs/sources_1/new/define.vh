//`define SIMULATION 1

//OP Code
`define R_TYPE 7'b011_0011
`define S_TYPE 7'b010_0011
`define I_TYPE 7'b001_0011
`define IL_TYPE 7'b000_0011
`define UL_TYPE 7'b011_0111
`define UA_TYPE 7'b001_0111
`define B_TYPE 7'b110_0011
`define J_TYPE 7'b110_1111  //JAL
`define JL_TYPE 7'b110_0111 //JALR



//R-type Instruction

`define ADD 4'b0_000
`define SUB 4'b1_000
`define SLL 4'b0_001
`define SLT 4'b0_010
`define SLTU 4'b0_011
`define XOR 4'b0_100
`define SRL 4'b0_101
`define SRA 4'b1_101        
`define OR 4'b0_110
`define AND 4'b0_111

//S-type Instruction
`define SW 3'b010
`define SH 3'b001
`define SB 3'b000

//IL-type Instruction
`define LB 3'b000
`define LH 3'b001
`define LW 3'b010
`define LBU 3'b100
`define LHU 3'b101


//B-type Instruction
`define BEQ 4'b0_000
`define BNE 4'b0_001
`define BLT 4'b0_100
`define BGE 4'b0_101
`define BLTU 4'b0_110
`define BGEU 4'b0_111
