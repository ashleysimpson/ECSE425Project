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
	Constant File_Instructions: string := "instruction_memory.dat";
	Constant File_Data: string := "data_memory.dat";
	Constant clk_period : time := 1000 ns;

	signal clk : std_logic := '0';

	-- Init FSM
	type state_type is (init1, init2, run);
	signal state : state_type := init1;
	
	-- Runtime FSM
	type run_state_type is (state_standby, state_if, state_id, state_exe, state_mem, state_wb);
	signal run_state : run_state_type := state_standby;

	-- SIGNALS FOR DATA MEMORY
	-- Outputs
	signal dm_address : integer := 0;
	signal dm_we : std_logic := '0';
	signal dm_re : std_logic := '0';
	signal dm_data : std_logic_vector(Bits_per_word-1 downto 0) := (others => 'Z');
	signal dm_initialize : std_logic := '0';
	signal dm_dump : std_logic := '0';
	signal dm_Word_Byte : std_logic := '1';
	-- Inputs
	signal dm_wr_done : std_logic := 'Z';
	signal dm_rd_ready : std_logic := 'Z';
	-- Casting
	signal dm_address_std : std_logic_vector(31 downto 0) := (others => 'Z');

	-- INSTRUCTION MEMORY
	-- Outputs
	signal im_address : integer := 0;
	signal im_we : std_logic := '0';
	signal im_re : std_logic := '0';
	signal im_data : std_logic_vector(Bits_per_word-1 downto 0) := (others => 'Z');
	signal im_initialize : std_logic := '0';
	signal im_dump : std_logic := '0';
	signal im_Word_Byte : std_logic := '1';
	-- Inputs
	signal im_wr_done : std_logic := 'Z';
	signal im_rd_ready : std_logic := 'Z';
	-- Casting
	signal im_address_std : std_logic_vector(31 downto 0) := (others => 'Z');

	-- REGISTER BANK
	signal I_array : I_type;
	signal load_array : load_type;
	signal clear_array : clear_type;
	signal Q_array : Q_type;
	signal reg_initialized : std_logic := '0';

	-- STAGES FLOW CONTROL
	-- Outputs
	signal start_IF : std_logic := '0';
	signal start_ID : std_logic := '0';
	signal start_EXE : std_logic := '0';
	signal start_MEM : std_logic := '0';
	signal start_WB : std_logic := '0';
	-- Inputs
 	signal done_IF : std_logic := '0';
 	signal done_ID : std_logic := '0';
 	signal done_EXE : std_logic := '0';
 	signal done_MEM : std_logic := '0';
 	signal done_WB : std_logic := '0';

 	-- PROCGRAM COUNTER REGISTER
 	-- signal I_PC : std_logic_vector(31 downto 0) := (others => '0');
 	signal load_PC : std_logic := '0';
 	signal clear_PC : std_logic := '1';
 	signal Q_PC : std_logic_vector(31 downto 0) := (others => '0');

 	-- IF STAGE SIGNALS
 	-- Outputs
 	signal IF_pc_in : std_logic_vector(31 downto 0) := (others => '0');
 	-- Inputs
 	signal IF_npc_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal IF_instr_out : std_logic_vector(31 downto 0) := (others => '0');

 	-- ID STAGE SIGNALS
 	-- Outputs
 	signal ID_instr_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_npc_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_Q_array : Q_type;
 	-- Inputs
 	signal ID_opctrl_out : std_logic := '0';
 	signal ID_opfun_out : std_logic_vector(5 downto 0) := (others => '0');
 	signal ID_reg_s : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_reg_t_cont : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_reg_t_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_reg_d_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_shamt : std_logic_vector(4 downto 0) := (others => '0');
 	signal ID_imm_16 : std_logic_vector(15 downto 0) := (others => 'Z');
 	signal ID_imm_32 : std_logic_vector(31 downto 0) := (others => 'Z');
 	signal ID_npc_out : std_logic_vector(31 downto 0) := (others => '0');
 	signal ID_load_array : load_type;
 	signal ID_clear_array : clear_type;
 	signal ID_I_array : I_type;

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

 	-- WB STAGE SIGNALS
 	-- Outputs
 	signal WB_alu_in : std_logic_vector(31 downto 0) := (others => '0');
 	signal WB_opctrl_in : std_logic := '0';
 	signal WB_opfun_in : std_logic_vector(5 downto 0) := (others => '0');
 	signal WB_reg_t_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal WB_reg_d_addr : std_logic_vector(4 downto 0) := (others => '0');
 	signal WB_mem_output : std_logic_vector(31 downto 0) := (others => '0');
 	signal WB_Q_array : Q_type;
 	-- Inputs
 	signal WB_load_array : load_type;
 	signal WB_clear_array : clear_type;
 	signal WB_I_array : I_type;

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
			opfun_out :		out std_logic_vector(5 downto 0);
			reg_s :			out std_logic_vector(31 downto 0);
			reg_t_cont :	out std_logic_vector(31 downto 0);
			reg_t_addr :	out std_logic_vector(4 downto 0);
			reg_d_addr :	out std_logic_vector(4 downto 0);
			shamt : 		out std_logic_vector(4 downto 0);
			imm_16:			out std_logic_vector(15 downto 0);
			imm_32:			out std_logic_vector(31 downto 0);
			npc_out:		out std_logic_vector(31 downto 0);
			load_array: 	out load_type;
			clear_array:	out clear_type;
			I_array:		out I_type
		);
	END COMPONENT;

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

 	-- Memory Access
 	COMPONENT memory_access
		GENERIC (
				Num_Bytes_in_Word : integer := 4;
				Num_Bits_in_Byte : integer := 8
			);
		PORT	(
				-- Inputs
				clk :			in std_logic;
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

 	

BEGIN

	-- Program counter register
	pc: register32 
	PORT MAP (
		I => MEM_npc_out,
		clock => clk,
		clear => clear_PC,
		load => load_PC,
		Q => IF_pc_in
		);

	-- Instantiate data and instruction memory
	data_memory: Main_Memory
	GENERIC MAP (
		File_Address_Read => File_Data,
		File_Address_Write => "DataMemCon.dat",
		Mem_Size_in_Word => Memory_Size,
		Num_Bytes_in_Word => 4,
		Num_Bits_in_Byte => 8,
		Read_Delay => 0,
		Write_Delay => 0
		)
	PORT MAP (
		clk => clk,
		address => dm_address,
		we => dm_we,
		re => dm_re,
		data => dm_data,
		initialize => dm_initialize,
		dump => dm_dump,
		wr_done => dm_wr_done,
		rd_ready => dm_rd_ready,
		Word_Byte => dm_Word_Byte
		);

	instruction_memory: Main_Memory
	GENERIC MAP (
		File_Address_Read => File_Instructions,
		File_Address_Write => "InstrMemCon.dat",
		Mem_Size_in_Word => Memory_Size,
		Num_Bytes_in_Word => 4,
		Num_Bits_in_Byte => 8,
		Read_Delay => 0,
		Write_Delay => 0
		)
	PORT MAP (
		clk => clk,
		address => im_address,
		we => im_we,
		re => im_re,
		data => im_data,
		initialize => im_initialize,
		dump => im_dump,
		wr_done => im_wr_done,
		rd_ready => im_rd_ready,
		Word_Byte => im_Word_Byte
		);
	
	-- Instantiate register bank
	regbank : for index in 1 to 31 generate
	regx: register32
	PORT MAP(
		I => I_array(index),
		clock => clk,
		load => load_array(index),
		clear => clear_array(index),
		Q => Q_array(index)
		);
	end generate regbank;

	-- INSTANTIATION OF STAGES
	-- IFETCH
	IFETCH: instruction_fetch
	PORT MAP (
		clk => clk,
		start => start_IF,
		pc_in => IF_pc_in,
		npc_out => IF_npc_out,
		instr_out => IF_instr_out,
		done => done_IF,
		address => im_address_std,
		Word_Byte => im_Word_Byte,
		we => im_we,
		re => im_re,
		rd_ready => im_rd_ready,
		data => im_data
		);

	-- ID	
  ID: instruction_decode
	PORT MAP (
		clk => clk,
		start => start_ID,
		instr_in => ID_instr_in,
		npc_in => ID_npc_in,
		load_array => ID_load_array,
		clear_array => ID_clear_array,
		Q_array => ID_Q_array,
		done => done_ID,
		opctrl_out => ID_opctrl_out,
		opfun_out => ID_opfun_out,
		reg_s => ID_reg_s,
		reg_t_cont => ID_reg_t_cont,
		reg_t_addr => ID_reg_t_addr,
		reg_d_addr => ID_reg_d_addr,
		shamt => ID_shamt,
		imm_16 => ID_imm_16,
		imm_32 => ID_imm_32,
		npc_out => ID_npc_out,
		I_array => ID_I_array
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

	-- MEM
	MEM: memory_access
	PORT MAP (
		clk => clk,
		start => start_MEM,
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
		address => dm_address_std,
		Word_Byte => dm_Word_Byte,
		we => dm_we,
		wr_done => dm_wr_done,
		re => dm_re,
		rd_ready => dm_rd_ready,
		data => dm_data
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
		Q_array => WB_Q_array,
		done => done_WB,
		load_array => WB_load_array,
		clear_array => WB_clear_array,
		I_array => WB_I_array
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
	dm_address <= to_integer(unsigned(dm_address_std));
	im_address <= to_integer(unsigned(im_address_std));

	-- MAPPING BETWEEN STAGES
	-- IF TO ID
	ID_instr_in <= IF_instr_out;
	ID_npc_in <= IF_npc_out;

	-- ID to EXE
	EXE_opfun_in <= ID_opfun_out;
	EXE_opctrl_in <= ID_opctrl_out;
	EXE_reg_s_cont <= ID_reg_s;
	EXE_reg_t_addr_in <= ID_reg_t_addr;
	EXE_reg_t_cont_in <= ID_reg_t_cont;
	EXE_reg_d_addr_in <= ID_reg_d_addr;
	EXE_shamt <= ID_shamt;
	EXE_imm_16 <= ID_imm_16;
	EXE_imm_32 <= ID_imm_32;
	EXE_npc_in <= ID_npc_out;

	-- EXE to MEM
	MEM_opfun_in <= EXE_opfun_out;
	MEM_opctrl_in <= EXE_opctrl_out;
	MEM_reg_t_addr_in <= EXE_reg_t_addr_out;
	MEM_reg_t_cont_in <= EXE_reg_t_cont_out;
	MEM_reg_d_addr_in <= EXE_reg_d_addr_out;
	MEM_npc_in <= EXE_npc_out;
	MEM_branch_cond <= EXE_branch_cond;
	MEM_alu_in <= EXE_alu_output;

	-- MEM to WB
	WB_alu_in <= MEM_alu_out;
	WB_opctrl_in <= MEM_opctrl_out;
	WB_opfun_in <= MEM_opfun_out;
	WB_reg_t_addr <= MEM_reg_t_addr_out;
	WB_reg_d_addr <= MEM_reg_d_addr_out;
	WB_mem_output <= MEM_mem_output;

	-- Main process
	main_process: process (clk)
	BEGIN
		if(clk'event and clk = '0') then
		  dm_data <= (others=>'Z');
			case state is
				when init1 =>
					Q_array(0) <= (others => '0');
					dm_initialize <= '1';
					for index in 1 to 31 loop
						clear_array(index) <= '0';
						Q_array(index) <= (others => 'Z');
						I_array(index) <= (others => '0');
						load_array <= (others => '0');
					end loop;
					clear_PC <= '0';
					dm_dump <= '1';
					dm_dump <= '0';
					state <= init2;
				when init2 =>
					dm_initialize <= '0';
					for index in 1 to 31 loop
						clear_array(index) <= '1';
					end loop;
					clear_PC <= '1';
					start_IF <= '1';
					state <= run;
					run_state <= state_if;
        		when run =>
					case run_state is
						when state_if =>
							start_IF <= '1';
							if (done_IF = '1') then
								start_IF <= '0';
								run_state <= state_id;
								dm_dump <= '0';
					    	end if;
					    
						when state_id =>
							I_array <= ID_I_array;
							ID_Q_array <= Q_array;
							clear_array <= ID_clear_array;
							load_array <= ID_load_array;
						    start_ID <= '1';
							if (done_ID = '1') then
								start_ID <= '0';
								run_state <= state_exe;
							end if;
					    
						when state_exe =>
							start_EXE <= '1';
							if (done_EXE = '1') then
								start_EXE <= '0';
								run_state <= state_mem;
							end if;
					    
						when state_mem =>
							start_MEM <= '1';
							if (done_MEM = '1') then
								start_MEM <= '0';
								run_state <= state_wb;
							end if;
					    
						when state_wb =>
							I_array <= WB_I_array;
							WB_Q_array <= Q_array;
							clear_array <= WB_clear_array;
							load_array <= WB_load_array;
							start_WB <= '1';
							load_PC <= '1';
							if (done_WB = '1') then
								start_WB <= '0';
								run_state <= state_if;
								dm_dump <= '1';
								load_PC <= '0';
							end if;
						when others =>
							run_state <= state_standby;
							state <= init1;
				      
				 end case;
			end case;
		end if;
	END process;
	
END;