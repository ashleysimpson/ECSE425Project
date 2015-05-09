-- tb_EXE.vhd
-- Authors: Anthony Delage, Philippe Fortin Simard, Julien Castellano, Ashley Simpson
-- Testbench for execution stage of the processor.

LIBRARY ieee;
LIBRARY work;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all;

ENTITY tb_exe IS
    PORT    (
    		-- Inputs
			clk : 			in std_logic;
			tb_instr_in :		in std_logic_vector(31 downto 0);
			tb_reg_s_cont_int:	in integer;
			tb_reg_t_cont_int : in integer;
			tb_npc_in :		in std_logic_vector(31 downto 0);
			
			-- Outputs that are passed directly from inputs
			tb_opfun_out :		out std_logic_vector(5 downto 0);
			tb_opctrl_out :	out std_logic;
			tb_reg_t_addr_out : out std_logic_vector(4 downto 0);
			tb_reg_t_cont_out : out std_logic_vector(31 downto 0);
			tb_reg_d_addr_out : out std_logic_vector(4 downto 0);
			tb_npc_out :		out std_logic_vector(31 downto 0);

			-- ALU-generated ouputs
			tb_branch_cond :	out std_logic; 						-- 0 if NPC, 1 if ALU result
			tb_alu_output :		out std_logic_vector(31 downto 0);
			tb_alu_output_int : out integer;
			tb_done :			out std_logic 						-- Set to 1 when done computing (outputs are ready)
		);
END tb_exe;

ARCHITECTURE behavior OF tb_exe IS
	signal tb_start :			std_logic;
	signal tb_opfun_in : 		std_logic_vector(5 downto 0);
	signal tb_opctrl_in : 		std_logic;							-- 0 when opcode, 1 when function
	signal tb_reg_s_cont :		std_logic_vector(31 downto 0);
	signal tb_reg_t_cont_in :	std_logic_vector(31 downto 0);
	signal tb_reg_t_addr_in : 	std_logic_vector(4 downto 0);
	signal tb_reg_d_addr_in :	std_logic_vector(4 downto 0);
	signal tb_shamt :			std_logic_vector(4 downto 0);
	signal tb_imm_16 :			std_logic_vector(15 downto 0);
	signal tb_imm_32 :			std_logic_vector(31 downto 0);
	constant NAT_32 :	natural := 32;
BEGIN

	-- Split up instr_in
	tb_opfun_in <= tb_instr_in(31 downto 26);
	with tb_opfun_in select
		tb_opctrl_in <=
			'1' when "000000",
			'0' when others;

	tb_reg_t_addr_in <= tb_instr_in(20 downto 16);
	tb_reg_d_addr_in <= tb_instr_in(15 downto 11);
	tb_shamt <= tb_instr_in(10 downto 6);
	tb_imm_16 <= tb_instr_in(15 downto 0);
	tb_imm_32 <= std_logic_vector(resize(signed(tb_imm_16), NAT_32));

	-- Convert integer inputs to appropriate signals
	tb_reg_s_cont <= std_logic_vector(to_signed(tb_reg_s_cont_int, 32));
	tb_reg_t_cont_in <= std_logic_vector(to_signed(tb_reg_t_cont_int, 32));

	-- EXE port map	
	exe_stage: ENTITY execution PORT MAP (
		clk => clk,
		start => tb_start,
		opfun_in => tb_opfun_in,
		opctrl_in => tb_opctrl_in,
		reg_s_cont => tb_reg_s_cont,
		reg_t_addr_in => tb_reg_t_addr_in,
		reg_t_cont_in => tb_reg_t_cont_in,
		reg_d_addr_in => tb_reg_d_addr_in,
		shamt => tb_shamt,
		imm_16 => tb_imm_16,
		imm_32 => tb_imm_32,
		npc_in => tb_npc_in,
		opfun_out => tb_opfun_out,
		opctrl_out => tb_opctrl_out,
		reg_t_addr_out => tb_reg_t_addr_out,
		reg_t_cont_out => tb_reg_t_cont_out,
		reg_d_addr_out => tb_reg_d_addr_out,
		npc_out => tb_npc_out,
		branch_cond => tb_branch_cond,
		alu_output => tb_alu_output,
		done => tb_done
		);

	-- Process to run exe stage
	
END behavior;