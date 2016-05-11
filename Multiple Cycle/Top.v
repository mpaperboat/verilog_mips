`timescale 1ns / 1ps
module Top(
		input clock,
		input reset
	);
	//temp regs
	reg[31:0]PC;
	reg[31:0]IFID_PC_PLUS_4;
	reg[31:0]IFID_INST;
	
	reg[31:0]IDEX_PC_PLUS_4;
	reg[31:0]IDEX_READ_DATA_1;
	reg[31:0]IDEX_READ_DATA_2;
	reg[31:0]IDEX_INST_15_0;
	reg[4:0]IDEX_INST_20_16;
	reg[4:0]IDEX_INST_15_11;
	reg[25:0]IDEX_INST_25_0;
	reg IDEX_REG_DST;
	reg IDEX_ALU_SRC;
	reg IDEX_MEM_TO_REG;
	reg IDEX_REG_WRITE;
	reg IDEX_MEM_READ;
	reg IDEX_MEM_WRITE;
	reg IDEX_BRANCH;
	reg[1:0]IDEX_ALU_OP;
	reg IDEX_JUMP;
	
	reg[31:0]EXMEM_NEW_PC;
	reg EXMEM_ZERO;
	reg[31:0]EXMEM_ALU_RESULT;
	reg[31:0]EXMEM_READ_DATA_2;
	reg[4:0]EXMEM_WRITE_REG;
	reg[25:0]EXMEM_INST_25_0;
	reg EXMEM_MEM_TO_REG;
	reg EXMEM_REG_WRITE;
	reg EXMEM_MEM_READ;
	reg EXMEM_MEM_WRITE;
	reg EXMEM_BRANCH;
	reg EXMEM_JUMP;
	
	reg MEMWB_MEM_TO_REG;
	reg MEMWB_REG_WRITE;
	reg[31:0]MEMWB_READ_DATA;
	reg[31:0]MEMWB_ALU_RESULT;
	reg[4:0]MEMWB_WRITE_REG;
	
	wire[4:0]EX_MUX2;
	assign EX_MUX2=IDEX_REG_DST?IDEX_INST_15_11:IDEX_INST_20_16;
	wire[31:0]ALU_OUT;
	//begin
	wire[31:0]PCIF_ADD_OUT;
	wire PC_SRC;
	//PC
	Add PCIFAdd(
		.in0(4),
		.in1(PC),
		.out(PCIF_ADD_OUT)
	);
	wire[31:0]INST_MEM_OUT;
	InstMem instMem(
		.address(PC),
		.readData(INST_MEM_OUT)
	);
	//IF/ID
	wire[31:0]REGMEM_OUT1;
	wire[31:0]REGMEM_OUT2;
	wire[31:0]REG_WRITE_DATA;
	wire[31:0]DATAMEM_OUT;
	wire regok;
	RegMem regMem(
		.clock(clock),
		.reset(reset),
		.readReg1(IFID_INST[25:21]),
		.readReg2(IFID_INST[20:16]),
		.writeReg(MEMWB_WRITE_REG),
		.writeData(REG_WRITE_DATA),
		.regWrite(MEMWB_REG_WRITE),
		.readData1(REGMEM_OUT1),
		.readData2(REGMEM_OUT2),
		.IDEX_REG_WRITE(IDEX_REG_WRITE),
		.IDEX_REG_DES(EX_MUX2),
		.IDEX_MEM_TO_REG(IDEX_MEM_TO_REG),
		.EXMEM_REG_WRITE(EXMEM_REG_WRITE),
		.EXMEM_REG_DES(EXMEM_WRITE_REG),
		.EXMEM_DATA(EXMEM_MEM_TO_REG?DATAMEM_OUT:EXMEM_ALU_RESULT),
		.IDEX_DATA(ALU_OUT),
		.regok(regok)
	);
	wire[31:0]SIGNEXT_OUT;
	SignExt signExt(
		.in(IFID_INST[15:0]),
		.out(SIGNEXT_OUT));
	wire REG_DST;
	wire ALU_SRC;
	wire MEM_TO_REG;
	wire REG_WRITE;
	wire MEM_READ;
	wire MEM_WRITE;
	wire BRANCH;
	wire[1:0]ALU_OP;
	wire JUMP;
	Ctr ctr(
		.opCode(IFID_INST[31:26]),
		.regDst(REG_DST),
		.aluSrc(ALU_SRC),
		.memToReg(MEM_TO_REG),
		.regWrite(REG_WRITE),
		.memRead(MEM_READ),
		.memWrite(MEM_WRITE),
		.branch(BRANCH),
		.aluOp(ALU_OP),
		.jump(JUMP));
	//ID/EX
	wire[31:0]EXADD_OUT;
	Add EXAdd(
		.in0(IDEX_PC_PLUS_4),
		.in1(IDEX_INST_15_0<<2),
		.out(EXADD_OUT)
	);
	wire[31:0]EX_MUX1;
	assign EX_MUX1=IDEX_ALU_SRC?IDEX_INST_15_0:IDEX_READ_DATA_2;
	wire[3:0]ALUCTR_OUT;
	AluCtr aluCtr(
		.aluOp(IDEX_ALU_OP),
		.funct(IDEX_INST_15_0[5:0]),
		.aluCtr(ALUCTR_OUT));
	wire ALU_ZERO;
	Alu alu(
		.input1(IDEX_READ_DATA_1),
		.input2(EX_MUX1),
		.aluCtr(ALUCTR_OUT),
		.aluRes(ALU_OUT),
		.zero(ALU_ZERO));
	//EXMEM
	assign PC_SRC=(EXMEM_BRANCH&EXMEM_ZERO)|EXMEM_JUMP;
	DataMem dataMem(
		.clock(clock),
		.memRead(EXMEM_MEM_READ),
		.memWrite(EXMEM_MEM_WRITE),
		.writeData(EXMEM_READ_DATA_2),
		.readData(DATAMEM_OUT),
		.address(EXMEM_ALU_RESULT));
	//MEM/WB
	assign REG_WRITE_DATA=MEMWB_MEM_TO_REG?MEMWB_READ_DATA:MEMWB_ALU_RESULT;
	
	reg[31:0]PC_TEMP;
	reg[31:0]D1_T;
	reg[31:0]D2_T;
	reg okt;
	always@(posedge clock)
	begin
		D1_T=REGMEM_OUT1;
		D2_T=REGMEM_OUT2;
		okt=regok;
		MEMWB_MEM_TO_REG=EXMEM_MEM_TO_REG;
		MEMWB_REG_WRITE=EXMEM_REG_WRITE;
		MEMWB_READ_DATA=DATAMEM_OUT;
		MEMWB_ALU_RESULT=EXMEM_ALU_RESULT;
		MEMWB_WRITE_REG=EXMEM_WRITE_REG;
		if(PC_SRC==0)
			PC_TEMP=PCIF_ADD_OUT;
		else if(EXMEM_BRANCH)
			PC_TEMP=EXMEM_NEW_PC;
		else
			PC_TEMP={6'b000000,EXMEM_INST_25_0};
			
		if(PC_SRC==0)
		begin
			EXMEM_NEW_PC=EXADD_OUT;
			EXMEM_ZERO=ALU_ZERO;
			EXMEM_ALU_RESULT=ALU_OUT;
			EXMEM_READ_DATA_2=IDEX_READ_DATA_2;
			EXMEM_WRITE_REG=EX_MUX2;
			EXMEM_MEM_TO_REG=IDEX_MEM_TO_REG;
			EXMEM_REG_WRITE=IDEX_REG_WRITE;
			EXMEM_INST_25_0=IDEX_INST_25_0;
			EXMEM_MEM_READ=IDEX_MEM_READ;
			EXMEM_MEM_WRITE=IDEX_MEM_WRITE;
			EXMEM_BRANCH=IDEX_BRANCH;
			EXMEM_JUMP=IDEX_JUMP;
			if(okt)
			begin
				IDEX_READ_DATA_1=D1_T;
				IDEX_READ_DATA_2=D2_T;
				IDEX_INST_15_0=SIGNEXT_OUT;
				IDEX_INST_20_16=IFID_INST[20:16];
				IDEX_INST_15_11=IFID_INST[15:11];
				IDEX_INST_25_0=IFID_INST[25:0];
				IDEX_REG_DST=REG_DST;
				IDEX_ALU_SRC=ALU_SRC;
				IDEX_MEM_TO_REG=MEM_TO_REG;
				IDEX_REG_WRITE=REG_WRITE;
				IDEX_MEM_READ=MEM_READ;
				IDEX_MEM_WRITE=MEM_WRITE;
				IDEX_BRANCH=BRANCH;
				IDEX_ALU_OP=ALU_OP;
				IDEX_JUMP=JUMP;
				IDEX_PC_PLUS_4=IFID_PC_PLUS_4;
				IFID_PC_PLUS_4=PCIF_ADD_OUT;
				IFID_INST=INST_MEM_OUT;
				PC=PC_TEMP;
			end
			else
			begin
				IDEX_PC_PLUS_4=0;
				IDEX_READ_DATA_1=0;
				IDEX_READ_DATA_2=0;
				IDEX_INST_15_0=0;
				IDEX_INST_20_16=0;
				IDEX_INST_15_11=0;
				IDEX_INST_25_0=0;
				IDEX_REG_DST=0;
				IDEX_ALU_SRC=0;
				IDEX_MEM_TO_REG=0;
				IDEX_REG_WRITE=0;
				IDEX_MEM_READ=0;
				IDEX_MEM_WRITE=0;
				IDEX_BRANCH=0;
				IDEX_ALU_OP=0;
				IDEX_JUMP=0;
			end
		end
		else
		begin
			PC=PC_TEMP;
			IFID_PC_PLUS_4=0;
			IFID_INST=0;
			IDEX_PC_PLUS_4=0;
			IDEX_READ_DATA_1=0;
			IDEX_READ_DATA_2=0;
			IDEX_INST_15_0=0;
			IDEX_INST_20_16=0;
			IDEX_INST_15_11=0;
			IDEX_INST_25_0=0;
			IDEX_REG_DST=0;
			IDEX_ALU_SRC=0;
			IDEX_MEM_TO_REG=0;
			IDEX_REG_WRITE=0;
			IDEX_MEM_READ=0;
			IDEX_MEM_WRITE=0;
			IDEX_BRANCH=0;
			IDEX_ALU_OP=0;
			IDEX_JUMP=0;
			EXMEM_NEW_PC=0;
			EXMEM_ZERO=0;
			EXMEM_ALU_RESULT=0;
			EXMEM_READ_DATA_2=0;
			EXMEM_WRITE_REG=0;
			EXMEM_MEM_TO_REG=0;
			EXMEM_INST_25_0=0;
			EXMEM_REG_WRITE=0;
			EXMEM_MEM_READ=0;
			EXMEM_MEM_WRITE=0;
			EXMEM_BRANCH=0;
			EXMEM_JUMP=0;
		end
		if(reset)
		begin
			PC=0;
			IFID_PC_PLUS_4=0;
			IFID_INST=0;
			
			IDEX_PC_PLUS_4=0;
			IDEX_READ_DATA_1=0;
			IDEX_READ_DATA_2=0;
			IDEX_INST_15_0=0;
			IDEX_INST_20_16=0;
			IDEX_INST_15_11=0;
			IDEX_INST_25_0=0;
			IDEX_REG_DST=0;
			IDEX_ALU_SRC=0;
			IDEX_MEM_TO_REG=0;
			IDEX_REG_WRITE=0;
			IDEX_MEM_READ=0;
			IDEX_MEM_WRITE=0;
			IDEX_BRANCH=0;
			IDEX_ALU_OP=0;
			IDEX_JUMP=0;
			
			EXMEM_NEW_PC=0;
			EXMEM_ZERO=0;
			EXMEM_ALU_RESULT=0;
			EXMEM_READ_DATA_2=0;
			EXMEM_WRITE_REG=0;
			EXMEM_MEM_TO_REG=0;
			EXMEM_REG_WRITE=0;
			EXMEM_MEM_READ=0;
			EXMEM_MEM_WRITE=0;
			EXMEM_INST_25_0=0;
			EXMEM_BRANCH=0;
			EXMEM_JUMP=0;
			
			MEMWB_MEM_TO_REG=0;
			MEMWB_REG_WRITE=0;
			MEMWB_READ_DATA=0;
			MEMWB_ALU_RESULT=0;
			MEMWB_WRITE_REG=0;
		end
	end
endmodule
