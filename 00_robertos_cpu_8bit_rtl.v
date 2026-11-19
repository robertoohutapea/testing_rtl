`timescale 1ns/1ps

module tt_um_robertoohutapea_cpu8 (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,

    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,

    input wire ena,
    input wire clk,
    input wire rst_n
);

    wire cpu_halted;
    wire [7:0] cpu_pc;
    wire cpu_reset;

    assign cpu_reset = ~rst_n;

    cpu_8bit cpu_inst (
        .clk(clk),
        .reset(cpu_reset),
        .halted(cpu_halted),
        .pc(cpu_pc)
    );

    assign uo_out = cpu_pc;

    assign uio_out = {
        7'b0000000,
        cpu_halted
    };

    assign uio_oe = 8'b00000001;

endmodule

module cpu_8bit (
    input wire clk,
    input wire reset,

    output reg halted,
    output wire [7:0] pc
);

    // Instruction signals
    wire [15:0] instruction;
    wire [3:0] opcode;
    wire [1:0] rd;
    wire [1:0] ra;
    wire [1:0] rb;
    wire [7:0] immediate;

    // Control signals
    wire reg_write;
    wire alu_src_imm;
    wire mem_read;
    wire mem_write;
    wire mem_to_reg;
    wire imm_to_reg;
    wire pc_jump;
    wire halt_instruction;
    wire [2:0] alu_control;

    // Register File signals
    wire [7:0] read_data_a;
    wire [7:0] read_data_b;
    wire [1:0] register_read_addr_b;
    wire [7:0] writeback_data;

    // ALU signals
    wire [7:0] alu_b;
    wire [7:0] alu_result;
    wire alu_zero;

    // Data Memory signals
    wire [7:0] memory_read_data;

    // Program Counter controls
    wire pc_enable;
    wire pc_load;

    // --------------------------------
    // PROGRAM COUNTER
    // --------------------------------

    assign pc_enable = !halted && !halt_instruction;
    assign pc_load = pc_jump && !halted;

    program_counter pc_inst (
        .clk(clk),
        .reset(reset),
        .enable(pc_enable),
        .load(pc_load),
        .load_addr(immediate),
        .pc(pc)
    );

    // --------------------------------
    // INSTRUCTION MEMORY
    // --------------------------------

    instruction_memory instruction_memory_inst (
        .address(pc),
        .instruction(instruction)
    );

    // --------------------------------
    // INSTRUCTION DECODER
    // --------------------------------

    instruction_decoder decoder_inst (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .ra(ra),
        .rb(rb),
        .immediate(immediate)
    );

    // --------------------------------
    // CONTROL UNIT
    // --------------------------------

    control_unit control_inst (
        .opcode(opcode),
        .reg_write(reg_write),
        .alu_src_imm(alu_src_imm),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .imm_to_reg(imm_to_reg),
        .pc_jump(pc_jump),
        .halt(halt_instruction),
        .alu_control(alu_control)
    );

    // --------------------------------
    // REGISTER FILE
    // --------------------------------

    // STORE uses RD as its source register.
    assign register_read_addr_b =
        (opcode == 4'hA) ? rd : rb;

    register_file regfile_inst (
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write && !halted),
        .write_addr(rd),
        .write_data(writeback_data),
        .read_addr_a(ra),
        .read_addr_b(register_read_addr_b),
        .read_data_a(read_data_a),
        .read_data_b(read_data_b)
    );

    // --------------------------------
    // ALU
    // --------------------------------

    assign alu_b = alu_src_imm ? immediate : read_data_b;

    alu_8bit alu_inst (
        .A(read_data_a),
        .B(alu_b),
        .opcode(alu_control),
        .result(alu_result),
        .zero(alu_zero)
    );

    // --------------------------------
    // DATA MEMORY
    // --------------------------------

    data_memory data_memory_inst (
        .clk(clk),
        .reset(reset),
        .write_enable(mem_write && !halted),
        .address(immediate),
        .write_data(read_data_b),
        .read_data(memory_read_data)
    );

    // --------------------------------
    // WRITE BACK MUX
    // --------------------------------

    assign writeback_data =
        imm_to_reg ? immediate :
        mem_to_reg ? memory_read_data :
        alu_result;

    // --------------------------------
    // HALT CONTROL
    // --------------------------------

    always @(posedge clk) begin
        if (reset) begin
            halted <= 1'b0;
        end
        else if (halt_instruction) begin
            halted <= 1'b1;
        end
    end

endmodule

module control_unit (
    input wire [3:0] opcode,

    output reg reg_write,
    output reg alu_src_imm,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg imm_to_reg,
    output reg pc_jump,
    output reg halt,

    output reg [2:0] alu_control
);

    always @(*) begin

        // Default control signals
        reg_write   = 1'b0;
        alu_src_imm = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        imm_to_reg  = 1'b0;
        pc_jump     = 1'b0;
        halt        = 1'b0;
        alu_control = 3'b000;

        case (opcode)

            // ADD
            4'h1: begin
                reg_write = 1'b1;
                alu_control = 3'b000;
            end

            // SUB
            4'h2: begin
                reg_write = 1'b1;
                alu_control = 3'b001;
            end

            // AND
            4'h3: begin
                reg_write = 1'b1;
                alu_control = 3'b010;
            end

            // OR
            4'h4: begin
                reg_write = 1'b1;
                alu_control = 3'b011;
            end

            // XOR
            4'h5: begin
                reg_write = 1'b1;
                alu_control = 3'b100;
            end

            // NOT
            4'h6: begin
                reg_write = 1'b1;
                alu_control = 3'b101;
            end

            // ADDI
            4'h7: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_control = 3'b000;
            end

            // LDI
            4'h8: begin
                reg_write = 1'b1;
                imm_to_reg = 1'b1;
            end

            // LOAD
            4'h9: begin
                reg_write = 1'b1;
                mem_read = 1'b1;
                mem_to_reg = 1'b1;
            end

            // STORE
            4'hA: begin
                mem_write = 1'b1;
            end

            // JMP
            4'hB: begin
                pc_jump = 1'b1;
            end

            // HALT
            4'hF: begin
                halt = 1'b1;
            end

            // NOP / Undefined
            default: begin
                // Keep default control signals
            end

        endcase
    end

endmodule

module alu_8bit (
    input wire [7:0] A,
    input wire [7:0] B,
    input wire [2:0] opcode,
    output reg [7:0] result,
    output wire zero
);

    always @(*) begin
        case (opcode)
            3'b000: result = A + B;
            3'b001: result = A - B;
            3'b010: result = A & B;
            3'b011: result = A | B;
            3'b100: result = A ^ B;
            3'b101: result = ~A;

            default: result = 8'd0;
        endcase
    end

    assign zero = (result == 8'd0);

endmodule

module register_file (
    input wire clk,
    input wire reset,

    input wire write_enable,
    input wire [1:0] write_addr,
    input wire [7:0] write_data,

    input wire [1:0] read_addr_a,
    input wire [1:0] read_addr_b,

    output wire [7:0] read_data_a,
    output wire [7:0] read_data_b
);

    reg [7:0] R0;
    reg [7:0] R1;
    reg [7:0] R2;
    reg [7:0] R3;

    // Synchronous reset and write
    always @(posedge clk) begin
        if (reset) begin
            R0 <= 8'd0;
            R1 <= 8'd0;
            R2 <= 8'd0;
            R3 <= 8'd0;
        end
        else if (write_enable) begin
            case (write_addr)
                2'b00: R0 <= write_data;
                2'b01: R1 <= write_data;
                2'b10: R2 <= write_data;
                2'b11: R3 <= write_data;
            endcase
        end
    end

    // Asynchronous read port A
    assign read_data_a =
        (read_addr_a == 2'b00) ? R0 :
        (read_addr_a == 2'b01) ? R1 :
        (read_addr_a == 2'b10) ? R2 : R3;

    // Asynchronous read port B
    assign read_data_b =
        (read_addr_b == 2'b00) ? R0 :
        (read_addr_b == 2'b01) ? R1 :
        (read_addr_b == 2'b10) ? R2 : R3;

endmodule

module program_counter (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire load,
    input wire [7:0] load_addr,
    output reg [7:0] pc
);

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'd0;
        end
        else if (load) begin
            pc <= load_addr;
        end
        else if (enable) begin
            pc <= pc + 8'd1;
        end
    end

endmodule

module instruction_memory (
    input wire [7:0] address,
    output reg [15:0] instruction
);

    always @(*) begin
        case (address)

            // Demo program
            8'd0: instruction = 16'h800A; // LDI R0, 10
            8'd1: instruction = 16'h8405; // LDI R1, 5
            8'd2: instruction = 16'h1840; // ADD R2, R0, R1
            8'd3: instruction = 16'hA810; // STORE R2, 0x10
            8'd4: instruction = 16'h9C10; // LOAD R3, 0x10
            8'd5: instruction = 16'hF000; // HALT

            // Default NOP
            default: instruction = 16'h0000;

        endcase
    end

endmodule

module instruction_decoder (
    input wire [15:0] instruction,

    output wire [3:0] opcode,
    output wire [1:0] rd,
    output wire [1:0] ra,
    output wire [1:0] rb,
    output wire [7:0] immediate
);

    assign opcode    = instruction[15:12];
    assign rd        = instruction[11:10];
    assign ra        = instruction[9:8];
    assign rb        = instruction[7:6];
    assign immediate = instruction[7:0];

endmodule

module data_memory (
    input wire clk,
    input wire reset,

    input wire write_enable,
    input wire [7:0] address,
    input wire [7:0] write_data,

    output wire [7:0] read_data
);

    reg [7:0] memory [0:255];
    integer i;

    // Synchronous reset and write
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 256; i = i + 1) begin
                memory[i] <= 8'd0;
            end
        end
        else if (write_enable) begin
            memory[address] <= write_data;
        end
    end

    // Asynchronous read
    assign read_data = memory[address];

endmodule
