LIBRARY ieee;
LIBRARY work;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE STD.textio.all;
USE work.all;
USE work.regbank_package.all;

ENTITY processor IS
END processor;

ARCHITECTURE behaviour OF processor IS

	Constant Bits_per_word: integer := 32;
	Constant Memory_Size: integer := 1024;
	Constant File_Instructions: string := "program.dat";
	Constant clk_period : time := 1000 ns;

	signal clk : std_logic := '0';

	-- Init FSM
	type state_type is (init1, init2, run);
	signal state : state_type := init1;
	
	-- Runtime FSM
	type run_state_type is (state_standby, state_run, state_stall, state_prop, state_wait_IF, state_trans_MEM, state_FU, state_prop_IF, state_wait_ID, state_prop_ID, state_wait_EXE, state_prop_EXE);
	signal run_state : run_state_type := state_standby;

	-- SIGNALS FOR MEMORY
	-- Outputs
	signal mm_address : integer := 0;
	signal mm_we : std_logic := '0';
	signal mm_re : std_logic := '0';
	signal mm_data : std_logic_vector(Bits_per_word-1 downto 0) := (others => 'Z');
	signal mm_initialize : std_logic := '0';
	signal mm_dump : std_logic := '0';
	signal mm_Word_Byte : std_logic := '1';
	-- Inputs
	signal mm_wr_done : std_logic := 'Z';
	signal mm_rd_ready : std_logic := 'Z';
	-- Casting
	signal mm_address_std : std_logic_vector(31 downto 0) := (others => 'Z');

	-- REGISTER BANK
	signal REG_I_array : I_type;
	signal REG_load_array : load_type;
	signal REG_clear_array : clear_type;
	signal REG_Q_array : Q_type;
	signal clear_r31 : std_logic := '1';

	-- STAGES FLOW CONTROL
	-- Outputs
	signal start_IF : std_logic := '0';
	signal start_ID : std_logic := '0';
	signal start_EXE : std_logic := '0';
	signal start_MEM : std_logic := '0';
	signal start_WB : std_logic := '0';
	signal start_FU : std_logic := '0';
	-- Inputs
 	signal done_IF : std_logic := '0';
 	signal done_ID : std_logic := '0';
 	signal done_EXE : std_logic := '0';
 	signal done_MEM : std_logic := '0';
 	signal done_WB : std_logic := '0';
 	signal done_FU : std_logic := '0';

 	-- PROCGRAM COUNTER REGISTER
 	signal load_PC : std_logic := '0';
 	signal clear_PC : std_logic := '1';

 	-- IF STAGE SIGNALS
 	-- Outputs
 	signal IF_pc_in : std_logic_vector(31 downto 0) := (others => '0');
 	-- Inputs
 	signal IF_npc_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal IF_instr_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal IF_we : std_logic := '0';
 	signal IF_re : std_logic := 'Z';
 	signal IF_rd_ready : std_logic := '0';
 	signal IF_address_std : std_logic_vector(31 downto 0) := (others => '0');
 	signal IF_data : std_logic_vector(31 downto 0) := (others => '0');
 	signal IF_Word_Byte : std_logic := '1';
 	signal IF_ID_load_reg : std_logic := '0';

 	-- ID STAGE SIGNALS
 	-- Outputs
 	signal ID_instr_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_npc_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_Q_array : Q_type;
 	-- Inputs
 	signal ID_opctrl_out : std_logic := '0';
 	signal ID_stall : std_logic := 'Z';
 	signal ID_reg_s_dep : std_logic_vector(1 downto 0) :=(others => 'Z');
 	signal ID_reg_t_dep : std_logic_vector(1 downto 0) :=(others => 'Z');
 	signal ID_dep_on_MEM : std_logic :='0';
 	signal ID_opfun_out : std_logic_vector(5 downto 0) := (others => '0');
 	signal ID_reg_s : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_reg_t_cont : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_reg_t_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_reg_d_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_shamt : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_imm_16 : std_logic_vector(15 downto 0) := (others => 'Z');
 	signal ID_imm_32 : std_logic_vector(31 downto 0) := (others => 'Z');
 	signal ID_npc_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_load_r31 : std_logic := '0';
 	signal ID_I_r31 : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_EX_load_reg : std_logic := '0';

 	-- FWD UNIT STAGE SIGNALS
 	signal FU_reg_s_cont_out : std_logic_vector(31 downto 0) := (others => 'Z');
 	signal FU_reg_t_cont_out : std_logic_vector(31 downto 0) := (others => 'Z');


 	-- EXE STAGE SIGNALS
 	-- Outputs
 	signal EXE_opfun_in : std_logic_vector(5 downto 0) := (others => '0');
 	signal EXE_opctrl_in : std_logic := '0';
 	signal EXE_reg_s_cont : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_reg_t_addr_in : std_logic_vector(4 downto 0) := (others => '0');
 	signal EXE_reg_t_cont_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_reg_d_addr_in : std_logic_vector(4 downto 0) := (others => '0');
 	signal EXE_shamt : std_logic_vector(4 downto 0) := (others => '0');
 	signal EXE_imm_16 : std_logic_vector(15 downto 0) := (others => '0');
 	signal EXE_imm_32 : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_npc_in : std_logic_vector(31 downto 0) := (others => '0');
 	-- Inputs
 	signal EXE_opfun_out : std_logic_vector(5 downto 0) := (others => '0');
 	signal EXE_opctrl_out : std_logic := '0';
 	signal EXE_reg_t_addr_out : std_logic_vector(4 downto 0) := (others => '0');
 	signal EXE_reg_t_cont_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_reg_d_addr_out : std_logic_vector(4 downto 0) := (others => '0');
 	signal EXE_npc_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_branch_cond : std_logic := '0';
 	signal EXE_alu_output : std_logic_vector(31 downto 0) := (others => '0');
 	signal EXE_MEM_load_reg : std_logic := '0';

 	-- MEM STAGE SIGNALS
 	-- Outputs
 	signal MEM_opfun_in : std_logic_vector(5 downto 0) := (others => '0');
 	signal MEM_opctrl_in : std_logic := '0';
 	signal MEM_reg_t_addr_in : std_logic_vector(4 downto 0) := (others => '0');
 	signal MEM_reg_t_cont_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_reg_d_addr_in : std_logic_vector(4 downto 0) := (others => '0');
 	signal MEM_npc_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_branch_cond : std_logic := '0';
 	signal MEM_alu_in : std_logic_vector(31 downto 0) := (others => '0');
 	-- Inputs
 	signal MEM_opfun_out : std_logic_vector(5 downto 0) := (others => '0');
 	signal MEM_opctrl_out : std_logic := '0';
 	signal MEM_reg_t_addr_out : std_logic_vector(4 downto 0) := (others => '0');
 	signal MEM_reg_d_addr_out : std_logic_vector(4 downto 0) := (others => '0');
 	signal MEM_alu_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_npc_out : std_logic_vector(31 downto 0) := (others => 'Z');
 	signal MEM_mem_output : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_we : std_logic := '0';
 	signal MEM_re : std_logic := '0';
 	signal MEM_wr_done : std_logic := 'Z';
 	signal MEM_branch_condition : std_logic := '0';
 	signal MEM_rd_ready : std_logic := '0';
 	signal MEM_address_std : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_data : std_logic_vector(31 downto 0) := (others => '0');
 	signal MEM_Word_Byte : std_logic := '1';
 	signal MEM_WB_load_reg : std_logic := '0';

 	-- WB STAGE SIGNALS
 	-- Outputs
 	signal WB_alu_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal WB_opctrl_in : std_logic := '0';
 	signal WB_opfun_in : std_logic_vector(5 downto 0) := (others => '0');
 	signal WB_reg_t_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal WB_reg_d_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal WB_mem_output : std_logic_vector(31 downto 0) := (others => '0');

 	-- PIPELINE STAGES SIGNALS
 	signal IFID_clear 	: std_logic := '1';
 	signal IDEXE_clear	: std_logic := '1';
 	signal EXEMEM_clear	: std_logic := '1';
 	signal MEMWB_clear	: std_logic := '1';

 	-- Component Instantiation
 	-- Registers
 	COMPONENT register32
	port(   I:  in std_logic_vector(31 downto 0);
	    clock:  in std_logic;
	    load:   in std_logic;
	    clear:  in std_logic;
	    Q:  out std_logic_vector(31 downto 0)
	);
	end COMPONENT;

 	-- Main Memory
 	COMPONENT Main_Memory
		generic (
				File_Address_Read : string :="Init.dat";
				File_Address_Write : string :="MemCon.dat";
				Mem_Size_in_Word : integer:=256;	
				Num_Bytes_in_Word: integer:=4;
				Num_Bits_in_Byte: integer := 8; 
				Read_Delay: integer:=0; 
				Write_Delay:integer:=0
			 );
		port (
				clk : in std_logic;
				address : in integer;
				Word_Byte: in std_logic; -- when '1' you are interacting with the memory in word otherwise in byte
				we : in std_logic;
				wr_done:out std_logic; --indicates that the write operation has been done.
				re :in std_logic;
				rd_ready: out std_logic; --indicates that the read data is ready at the output.
				data : inout std_logic_vector((Num_Bytes_in_Word*Num_Bits_in_Byte)-1 downto 0);        
				initialize: in std_logic;
				dump: in std_logic
			 );			
	END COMPONENT;

 	-- Instruction Fetch
 	COMPONENT instruction_fetch 
		GENERIC (
				Num_Bytes_in_Word: integer := 4;
				Num_Bits_in_Byte: integer := 8
			);
		PORT	(
				-- Inputs
				clk : 			in std_logic;
				start :			in std_logic;
				pc_in :			in std_logic_vector(31 downto 0);
				mem_branch : 	in std_logic;
				mem_alu : 		in std_logic_vector(31 downto 0);

				-- Outputs
				npc_out :		out std_logic_vector(31 downto 0);
				instr_out :		out std_logic_vector(31 downto 0);
				done : 			out std_logic;

				-- Ports that interface with memory
				address : 		out std_logic_vector(31 downto 0);
				Word_Byte : 	out std_logic; -- when '1' you are interacting with the memory in word otherwise in byte
				we :			out std_logic;
				re :			out std_logic;
				rd_ready :		in std_logic; --indicates that the read data is ready at the output.
				data : 			inout std_logic_vector((Num_Bytes_in_Word * Num_Bits_in_Byte) - 1 downto 0) 
			);
	END COMPONENT;

	-- IF/ID register
	COMPONENT registerIFID
		port(   
			instr_in:  		in std_logic_vector(31 downto 0);
			npc_in:			in std_logic_vector(31 downto 0);

	    	clock:  		in std_logic;
	    	load_pipe_reg:  in std_logic;
	    	clear_pipe_reg: in std_logic;

	    	instr_out:  	out std_logic_vector(31 downto 0);
	    	npc_out:		out std_logic_vector(31 downto 0)
		);
	end COMPONENT;

 	-- Instruction Decode
 	COMPONENT instruction_decode 
		port(
			clk : 			in std_logic;
			start :  		in std_logic;
			instr_in : 		in std_logic_vector(31 downto 0);
			npc_in : 		in std_logic_vector(31 downto 0);
			Q_array:		in Q_type;

			done : 			out std_logic;

			opctrl_out : 	out std_logic;
			stall :			out std_logic;
			reg_s_dep :		out std_logic_vector(1 downto 0);
			reg_t_dep :		out std_logic_vector(1 downto 0);
			dep_on_MEM : 	out std_logic;
			opfun_out :		out std_logic_vector(5 downto 0);
			reg_s :			out std_logic_vector(31 downto 0);
			reg_t_cont :	out std_logic_vector(31 downto 0);
			reg_t_addr :	out std_logic_vector(4 downto 0);
			reg_d_addr :	out std_logic_vector(4 downto 0);
			shamt : 		out std_logic_vector(4 downto 0);
			imm_16:			out std_logic_vector(15 downto 0);
			imm_32:			out std_logic_vector(31 downto 0);
			npc_out:		out std_logic_vector(31 downto 0);
			load_r31 :		out std_logic;
			I_r31 :			out std_logic_vector(31 downto 0)
		);
	END COMPONENT;

	-- ID/EX register
	COMPONENT registerIDEX
		port(
			opctrl_in:		in std_logic; --
			opfun_in:		in std_logic_vector(5 downto 0);
			reg_s_in:		in std_logic_vector(31 downto 0); --
			reg_t_cont_in:	in std_logic_vector(31 downto 0); --
			reg_t_addr_in:	in std_logic_vector(4 downto 0); --
			reg_d_addr_in:	in std_logic_vector(4 downto 0); --
			shamt_in: 		in std_logic_vector(4 downto 0); --
			imm_16_in:		in std_logic_vector(15 downto 0);
			imm_32_in:		in std_logic_vector(31 downto 0); --
			npc_in:			in std_logic_vector(31 downto 0); --

	    	clock:  		in std_logic;
	    	load_pipe_reg:  in std_logic;
	    	clear_pipe_reg: in std_logic;

	    	opctrl_out:		out std_logic;
			opfun_out:		out std_logic_vector(5 downto 0);
			reg_s_out:		out std_logic_vector(31 downto 0); --
			reg_t_cont_out:	out std_logic_vector(31 downto 0); --
			reg_t_addr_out:	out std_logic_vector(4 downto 0);
			reg_d_addr_out:	out std_logic_vector(4 downto 0);
			shamt_out: 		out std_logic_vector(4 downto 0);
			imm_16_out:		out std_logic_vector(15 downto 0);
			imm_32_out:		out std_logic_vector(31 downto 0); --
			npc_out:		out std_logic_vector(31 downto 0) --
		);
	end COMPONENT;

 	-- Execution
 	COMPONENT execution
		PORT    (
				-- Inputs
				clk : 			in std_logic;
				start :			in std_logic;
				opfun_in : 		in std_logic_vector(5 downto 0);
				opctrl_in : 	in std_logic;						-- 0 when opcode, 1 when function
				reg_s_cont :	in std_logic_vector(31 downto 0);
				reg_t_addr_in : in std_logic_vector(4 downto 0);
				reg_t_cont_in :	in std_logic_vector(31 downto 0);
				reg_d_addr_in :	in std_logic_vector(4 downto 0);
				shamt :			in std_logic_vector(4 downto 0);
				imm_16 :		in std_logic_vector(15 downto 0);
				imm_32 :		in std_logic_vector(31 downto 0);
				npc_in :		in std_logic_vector(31 downto 0);
				
				-- Outputs that are passed directly from inputs
				opfun_out :		out std_logic_vector(5 downto 0);
				opctrl_out :	out std_logic;
				reg_t_addr_out : out std_logic_vector(4 downto 0);
				reg_t_cont_out : out std_logic_vector(31 downto 0);
				reg_d_addr_out : out std_logic_vector(4 downto 0);
				npc_out :		out std_logic_vector(31 downto 0);

				-- ALU-generated ouputs
				branch_cond :	out std_logic; 						-- 0 if NPC, 1 if ALU result
				alu_output :	out std_logic_vector(31 downto 0);
				done :			out std_logic 						-- Set to 1 when done computing (outputs are ready)
			);
	END COMPONENT;

	-- EX/ME register
	COMPONENT registerEXME
		port(
			opfun_in: 		in std_logic_vector(5 downto 0);
			opctrl_in: 		in std_logic;
			reg_t_addr_in: 	in std_logic_vector(4 downto 0);
			reg_t_cont_in: 	in std_logic_vector(31 downto 0);
			reg_d_addr_in: 	in std_logic_vector(4 downto 0);
			npc_in: 		in std_logic_vector(31 downto 0);
			branch_cond_in: in std_logic;
			alu_in: 		in std_logic_vector(31 downto 0);

	    	clock:  		in std_logic;
	    	load_pipe_reg:  in std_logic;
	    	clear_pipe_reg: in std_logic;

	    	opfun_out: 			out std_logic_vector(5 downto 0); --
			opctrl_out: 		out std_logic; --
			reg_t_addr_out:  	out std_logic_vector(4 downto 0);
			reg_t_cont_out: 	out std_logic_vector(31 downto 0); --
			reg_d_addr_out: 	out std_logic_vector(4 downto 0);
			npc_out: 			out std_logic_vector(31 downto 0); --
			branch_cond_out:	out std_logic;
			alu_out: 			out std_logic_vector(31 downto 0) --
		);
	end COMPONENT;

 	-- Memory Access
 	COMPONENT memory_access
		GENERIC (
				Num_Bytes_in_Word : integer := 4;
				Num_Bits_in_Byte : integer := 8
			);
		PORT	(
				-- Inputs
				clk :			in std_logic;
				stall:			in std_logic;
				start :			in std_logic;
				opfun_in : 		in std_logic_vector(5 downto 0);
				opctrl_in : 	in std_logic;
				reg_t_addr_in : in std_logic_vector(4 downto 0);
				reg_t_cont_in :	in std_logic_vector(31 downto 0);
				reg_d_addr_in :	in std_logic_vector(4 downto 0);
				npc_in :		in std_logic_vector(31 downto 0);
				branch_cond :	in std_logic; 						-- 0 if NPC, 1 if ALU result
				alu_in :		in std_logic_vector(31 downto 0);

				-- Outputs that are passed directly from inputs
				opfun_out :		out std_logic_vector(5 downto 0);
				opctrl_out :	out std_logic;
				reg_t_addr_out : out std_logic_vector(4 downto 0);
				reg_d_addr_out : out std_logic_vector(4 downto 0);
				alu_out :		out std_logic_vector(31 downto 0);

				-- MEM-generated output
				npc_out :		out std_logic_vector(31 downto 0);
				mem_output :	out std_logic_vector(31 downto 0);
				done :			out std_logic;
				branch_cond_out : out std_logic;

				-- Ports that interface with memory
				address : 		out std_logic_vector(31 downto 0);
				Word_Byte : 	out std_logic; -- when '1' you are interacting with the memory in word otherwise in byte
				we : 			out std_logic;
				wr_done : 		in std_logic; --indicates that the write operation has been done.
				re :			out std_logic;
				rd_ready :		in std_logic; --indicates that the read data is ready at the output.
				data : 			inout std_logic_vector((Num_Bytes_in_Word * Num_Bits_in_Byte) - 1 downto 0) 
			);
	END COMPONENT;

	-- ME/WB register
	COMPONENT registerMEWB
		port(
			alu_in :		in std_logic_vector(31 downto 0);
			opctrl_in :		in std_logic;
			opfun_in :		in std_logic_vector(5 downto 0);
			reg_t_addr_in :	in std_logic_vector(4 downto 0);
			reg_d_addr_in :	in std_logic_vector(4 downto 0);
			mem_output_in :	in std_logic_vector(31 downto 0);

	    	clock:  		in std_logic;
	    	load_pipe_reg:  in std_logic;
	    	clear_pipe_reg: in std_logic;

	    	alu_out :			out std_logic_vector(31 downto 0);
			opctrl_out :		out std_logic;
			opfun_out :			out std_logic_vector(5 downto 0);
			reg_t_addr_out :	out std_logic_vector(4 downto 0);
			reg_d_addr_out :	out std_logic_vector(4 downto 0);
			mem_output_out :	out std_logic_vector(31 downto 0)
		);
	end COMPONENT;

 	-- Write-Back
 	COMPONENT write_back 
		PORT (
			clk : 			in std_logic;
			start : 		in std_logic;
			alu_in :		in std_logic_vector(31 downto 0);
			opctrl_in :		in std_logic;
			opfun_in :		in std_logic_vector(5 downto 0);
			reg_t_addr :	in std_logic_vector(4 downto 0);
			reg_d_addr :	in std_logic_vector(4 downto 0);
			mem_output :	in std_logic_vector(31 downto 0);
			Q_array :		in Q_type;

			done : 			out std_logic;
			load_array :	out load_type;
			clear_array :	out clear_type;
			I_array :		out I_type
		);
	END COMPONENT;

	--Forwarding_unit
	COMPONENT forwarding_unit IS
		PORT(		
		clk :					in std_logic;
		stall :					in std_logic;
		reg_s_dep :				in std_logic_vector(1 downto 0);
		reg_t_dep :				in std_logic_vector(1 downto 0);
		dep_on_MEM :			in std_logic;
		reg_s_cont_in :			in std_logic_vector(31 downto 0);
		reg_t_cont_in :			in std_logic_vector(31 downto 0);
		alu_output :			in std_logic_vector(31 downto 0);
		mem_output :			in std_logic_vector(31 downto 0);
		-- will be sent by the main once the pipeline instance is complete.
		start:					in std_logic;

		fwdDone : 				out std_logic;
		reg_s_cont_out :		out std_logic_vector(31 downto 0);
		reg_t_cont_out :		out std_logic_vector(31 downto 0)
		);
	END COMPONENT;

BEGIN

	-- Program counter register
	pc: register32 
	PORT MAP (
		I => ID_npc_out,
		clock => clk,
		clear => clear_PC,
		load => load_PC,
		Q => IF_pc_in
		);

	-- Instantiate main memory
	memory: Main_Memory
	GENERIC MAP (
		File_Address_Read => File_Instructions,
		File_Address_Write =>"MemCon.dat",
		Mem_Size_in_Word =>Memory_Size,
		Num_Bytes_in_Word=>4,
		Num_Bits_in_Byte=>8,
		Read_Delay=>0,
		Write_Delay=>0
		)
	PORT MAP (
		clk => clk,
		address => mm_address,
		we => mm_we,
		re => mm_re,
		data => mm_data,
		initialize => mm_initialize,
		dump => mm_dump,
		wr_done => mm_wr_done,
		rd_ready => mm_rd_ready,
		Word_Byte => mm_Word_Byte
		);
	
	-- INSTANTIATION OF REGISTER BANK
	regbank : for index in 1 to 30 generate
	regx: register32
	PORT MAP(
		I => REG_I_array(index),
		clock => clk,
		load => REG_load_array(index),
		clear => REG_clear_array(index),
		Q => REG_Q_array(index)
		);
	end generate regbank;

	--INSTANTIATION OF JAL REG (31)
	reg31: register32
	PORT MAP(
		I => ID_I_r31,
		clock => clk,
		load => ID_load_r31,
		clear => clear_r31,
		Q => REG_Q_array(31)
		);

	-- INSTANTIATION OF STAGES
	-- IFETCH
	IFETCH: instruction_fetch
	PORT MAP (
		clk => clk,
		start => start_IF,
		pc_in => IF_pc_in,
		mem_branch => MEM_branch_condition,
		mem_alu => MEM_alu_out,
		npc_out => IF_npc_out,
		instr_out => IF_instr_out,
		done => done_IF,
		address => IF_address_std,
		Word_Byte => IF_Word_Byte,
		we => IF_we,
		re => IF_re,
		rd_ready => IF_rd_ready,
		data => IF_data
		);

	-- IF/ID
	IFID: registerIFID
	PORT MAP (   
			instr_in => IF_instr_out,
			npc_in => IF_npc_out,

	    	clock => clk,
	    	load_pipe_reg => IF_ID_load_reg,
	    	clear_pipe_reg => IFID_clear,

	    	instr_out => ID_instr_in,
	    	npc_out => ID_npc_in
	);

	-- ID	
  ID: instruction_decode
	PORT MAP (
		clk => clk,
		start => start_ID,
		instr_in => ID_instr_in,
		npc_in => ID_npc_in,
		load_r31 => ID_load_r31,

		Q_array => REG_Q_array,
		done => done_ID,
		opctrl_out => ID_opctrl_out,
		stall => ID_stall,
		opfun_out => ID_opfun_out,
		reg_s => ID_reg_s,
		reg_t_cont => ID_reg_t_cont,
		reg_t_addr => ID_reg_t_addr,
		reg_d_addr => ID_reg_d_addr,
		reg_s_dep => ID_reg_s_dep,
		reg_t_dep => ID_reg_t_dep,
		shamt => ID_shamt,
		imm_16 => ID_imm_16,
		imm_32 => ID_imm_32,
		npc_out => ID_npc_out,
		I_r31 => ID_I_r31
		);

	-- ID/EX
	IDEXE: registerIDEX
	PORT MAP(
		opctrl_in => ID_opctrl_out,
		opfun_in => ID_opfun_out,
		reg_s_in => FU_reg_s_cont_out,
		reg_t_cont_in => FU_reg_t_cont_out,
		reg_t_addr_in => ID_reg_t_addr,
		reg_d_addr_in => ID_reg_d_addr,
		shamt_in => ID_shamt,
		imm_16_in => ID_imm_16,
		imm_32_in => ID_imm_32,
		npc_in => ID_npc_out,

    	clock => clk,
    	load_pipe_reg => ID_EX_load_reg,
    	clear_pipe_reg => IDEXE_clear,

    	opctrl_out => EXE_opctrl_in,
		opfun_out => EXE_opfun_in,
		reg_s_out => EXE_reg_s_cont,
		reg_t_cont_out => EXE_reg_t_cont_in,
		reg_t_addr_out => EXE_reg_t_addr_in,
		reg_d_addr_out => EXE_reg_d_addr_in,
		shamt_out => EXE_shamt,
		imm_16_out => EXE_imm_16,
		imm_32_out => EXE_imm_32,
		npc_out =>  EXE_npc_in
	);	

	-- EXE
	EXE: execution
	PORT MAP (
		clk => clk,
		start => start_EXE,
		opfun_in => EXE_opfun_in,
		opctrl_in => EXE_opctrl_in,
		reg_s_cont => EXE_reg_s_cont,
		reg_t_addr_in => EXE_reg_t_addr_in,
		reg_t_cont_in => EXE_reg_t_cont_in,
		reg_d_addr_in => EXE_reg_d_addr_in,
		shamt => EXE_shamt,
		imm_16 => EXE_imm_16,
		imm_32 => EXE_imm_32,
		npc_in => EXE_npc_in,
		opfun_out => EXE_opfun_out,
		opctrl_out => EXE_opctrl_out,
		reg_t_addr_out => EXE_reg_t_addr_out,
		reg_t_cont_out => EXE_reg_t_cont_out,
		reg_d_addr_out => EXE_reg_d_addr_out,
		npc_out => EXE_npc_out,
		branch_cond => EXE_branch_cond,
		alu_output => EXE_alu_output,
		done => done_EXE
		);

	-- EXE/MEM
	EXEMEM: registerEXME
	PORT MAP (
		opfun_in => EXE_opfun_out,
		opctrl_in => EXE_opctrl_out,
		reg_t_addr_in => EXE_reg_t_addr_out,
		reg_t_cont_in => EXE_reg_t_cont_out,
		reg_d_addr_in => EXE_reg_d_addr_out,
		npc_in => EXE_npc_out,
		branch_cond_in => EXE_branch_cond,
		alu_in => EXE_alu_output,

    	clock => clk,
    	load_pipe_reg => EXE_MEM_load_reg,
    	clear_pipe_reg => EXEMEM_clear,

    	opfun_out =>  MEM_opfun_in,
		opctrl_out => MEM_opctrl_in,
		reg_t_addr_out => MEM_reg_t_addr_in,
		reg_t_cont_out => MEM_reg_t_cont_in,
		reg_d_addr_out => MEM_reg_d_addr_in,
		npc_out => MEM_npc_in,
		branch_cond_out => MEM_branch_cond,
		alu_out => MEM_alu_in
	);

	-- MEM
	MEM: memory_access
	PORT MAP (
		clk => clk,
		start => start_MEM,
		stall => ID_stall,
		opfun_in => MEM_opfun_in,
		opctrl_in => MEM_opctrl_in,
		reg_t_addr_in => MEM_reg_t_addr_in,
		reg_t_cont_in => MEM_reg_t_cont_in,
		reg_d_addr_in => MEM_reg_d_addr_in,
		npc_in => MEM_npc_in,
		branch_cond => MEM_branch_cond,
		alu_in => MEM_alu_in,
		opfun_out => MEM_opfun_out,
		opctrl_out => MEM_opctrl_out,
		reg_t_addr_out => MEM_reg_t_addr_out,
		reg_d_addr_out => MEM_reg_d_addr_out,
		alu_out => MEM_alu_out,
		npc_out => MEM_npc_out,
		mem_output => MEM_mem_output,
		done => done_MEM,
		branch_cond_out => MEM_branch_condition,
		address => MEM_address_std,
		Word_Byte => MEM_Word_Byte,
		we => MEM_we,
		wr_done => mm_wr_done,
		re => MEM_re,
		rd_ready => MEM_rd_ready,
		data => MEM_data
		);

	-- MEM/WB
	MEMWB: registerMEWB
	PORT MAP (
		alu_in => MEM_alu_out,
		opctrl_in => MEM_opctrl_out,
		opfun_in => MEM_opfun_out,
		reg_t_addr_in => MEM_reg_t_addr_out,
		reg_d_addr_in => MEM_reg_d_addr_out,
		mem_output_in => MEM_mem_output,

    	clock => clk,
    	load_pipe_reg => MEM_WB_load_reg,
    	clear_pipe_reg => MEMWB_clear,

    	alu_out => WB_alu_in,
		opctrl_out => WB_opctrl_in,
		opfun_out => WB_opfun_in,
		reg_t_addr_out => WB_reg_t_addr,
		reg_d_addr_out => WB_reg_d_addr,
		mem_output_out => WB_mem_output
	);

	-- WB
	WB: write_back
	PORT MAP (
		clk => clk,
		start => start_WB,
		alu_in => WB_alu_in,
		opfun_in => WB_opfun_in,
		opctrl_in => WB_opctrl_in,
		reg_t_addr => WB_reg_t_addr,
		reg_d_addr => WB_reg_d_addr,
		mem_output => WB_mem_output,
		Q_array => REG_Q_array,
		done => done_WB,
		load_array => REG_load_array,
		clear_array => REG_clear_array,
		I_array => REG_I_array
		);

	FWD: forwarding_unit
		PORT MAP (
		clk => clk,					
		stall => ID_stall,						
		reg_s_dep => ID_reg_s_dep,				
		reg_t_dep => ID_reg_t_dep,				
		dep_on_MEM => ID_dep_on_MEM,			
		reg_s_cont_in => ID_reg_s,			
		reg_t_cont_in => ID_reg_t_cont,			
		alu_output => EXE_alu_output,			
		mem_output => MEM_mem_output,			
		
		start => start_FU,					

		fwdDone => done_FU,				
		reg_s_cont_out => FU_reg_s_cont_out,  		
		reg_t_cont_out => FU_reg_t_cont_out		
		);

	-- Clock process
	clk_process: process
	BEGIN
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
	END process;

	-- Memory address accesses
	mm_address <= to_integer(unsigned(mm_address_std));

	-- Main process
	main_process: process (clk)
	BEGIN
		if(clk'event and clk = '0') then
		  mm_data <= (others=>'Z');
			case state is
				when init1 =>
					REG_Q_array(0) <= (others => '0');
					mm_initialize <= '1';
					for index in 1 to 31 loop
						REG_Q_array(index) <= (others => 'Z');
						REG_I_array(index) <= (others => 'Z');
						REG_load_array <= (others => 'Z');
					end loop;
					clear_PC <= '0';
					clear_r31 <= '0';
					mm_dump <= '1';
					mm_dump <= '0';
					state <= init2;
					--clearing intermediate pipeline stages
					IFID_clear <= '0';
					IDEXE_clear <= '0';
					EXEMEM_clear <= '0';
					MEMWB_clear <= '0';
					MEM_branch_condition <= '0';
				when init2 =>
					mm_initialize <= '0';
					clear_PC <= '1';
					clear_r31 <= '1';
					mm_re <= IF_re;
					start_IF <= '1';
					state <= run;
					run_state <= state_run;
					--stopping clearing of intermediate pipeline stages
					IFID_clear <= '1';
					IDEXE_clear <= '1';
					EXEMEM_clear <= '1';
					MEMWB_clear <= '1';
				when run =>
					case run_state is
						when state_run =>

							mm_dump <= '0'; -- THIS MAY DIEEEEEEEEE

							-- set the loads for the pipeline registers
							IF_ID_load_reg <= '0';
							ID_EX_load_reg <= '0';
							EXE_MEM_load_reg <= '0';
							MEM_WB_load_reg <= '0';

							start_MEM <= '1';

							--Only fetch instructions if we're not stalling
							if(ID_stall = '0') then
								start_IF <= '1';
								mm_we <= IF_we;
								mm_re <= IF_re;
								IF_rd_ready <= mm_rd_ready;
								mm_Word_Byte <= IF_Word_Byte;
								mm_address_std <= IF_pc_in;
								IF_data <= mm_data;
							--	start_IF <= '0';
							elsif (ID_stall ='1') then
								run_state <= state_stall;
								
							end if;
					    							
						    start_ID <= '1';

							start_EXE <= '1';
					    	
					    	start_WB <= '1';

					    	start_FU <= '0';

							if (done_IF = '1' and done_ID = '1' and done_EXE = '1' and done_MEM = '1' and done_WB = '1') then
								mm_dump <= '1';
								load_PC <= '0';

								-- load in the next stage to the pipeline registers
								IF_ID_load_reg <= '1';
								ID_EX_load_reg <= '1';
								EXE_MEM_load_reg <= '1';
								MEM_WB_load_reg <= '1';

								start_IF <= '0';
								start_ID <= '0';
								start_EXE <= '0';
								start_MEM <= '0';
								start_WB <= '0';
								run_state <= state_FU;

							end if;
						when state_FU =>
							start_FU <= '1';
							if (done_FU = '1') then 
								start_FU <='0';
								run_state <= state_prop;
							end if;

						when state_prop =>
							load_PC <= '1';
							run_state <= state_run;

						when state_stall =>

							if (done_ID = '1' and done_EXE = '1' and done_MEM = '1' and done_WB = '1' and ID_stall = '0') then
								mm_dump <= '1';

								-- load in the next stage to the pipeline registers
								IF_ID_load_reg <= '1';
								ID_EX_load_reg <= '1';
								EXE_MEM_load_reg <= '1';
								MEM_WB_load_reg <= '1';

								start_IF <= '0';
								start_ID <= '0';
								start_EXE <= '0';
								start_MEM <= '0';
								start_WB <= '0';

								mm_we <= IF_we;
								mm_re <= IF_re;
								mm_Word_Byte <= IF_Word_Byte;
								mm_address_std <= IF_pc_in;
								
								run_state <= state_trans_MEM;

							else

								mm_dump <= '0';
								IF_ID_load_reg <= '0';
								ID_EX_load_reg <= '0';
								EXE_MEM_load_reg <= '0';
								MEM_WB_load_reg <= '0';
								
								mm_we <= MEM_we;
								mm_re <= MEM_re;
								MEM_rd_ready <= mm_rd_ready;
								mm_Word_Byte <= MEM_Word_Byte;
								mm_address_std <= MEM_address_std;
								mm_data <= MEM_data;
								start_IF <= '0';
								load_PC <= '1';	

							end if;
						when state_trans_MEM =>
							IF_data <= mm_data;
							run_state <= state_wait_IF;
						when state_wait_IF =>
								start_IF <= '1';
								start_ID <= '0';
								start_EXE <= '0';
								start_MEM <= '0';
								start_WB <= '0';
								
								if (done_IF ='1') then
									IF_ID_load_reg <= '1';
									start_IF <= '0';
									run_state <= state_prop_IF;
								end if;
						when state_prop_IF =>
							run_state <= state_wait_ID;

						when state_wait_ID =>
							start_IF <= '0';
							start_ID <= '1';
							start_EXE <= '0';
							start_MEM <= '0';
							start_WB <= '0';
							load_PC <= '0';

							if (done_ID ='1') then
								ID_EX_load_reg <= '1';
								start_ID <= '0';
								run_state <= state_prop_ID;
							end if;

						when state_prop_ID =>
							run_state <= state_wait_EXE;

						when state_wait_EXE =>
							start_IF <= '0';
							start_ID <= '0';
							start_EXE <= '1';
							start_MEM <= '0';
							start_WB <= '0';

							if (done_EXE ='1') then
								EXE_MEM_load_reg <= '1';
								start_EXE <= '0';
								run_state <= state_prop_EXE;
							end if;

						when state_prop_EXE =>
							run_state <= state_run;


						when others =>
							run_state <= state_standby;
							state <= init1;
				      
				 end case;
			end case;
		end if;
	END process;
	
END;