-- ID.vhd
-- Authors: Julien Castellano, Anthony Delage, Philippe Fortin Simard, Ashley Simpson
-- Decode stage of the processor

LIBRARY ieee;
LIBRARY work;
Use ieee.std_logic_1164.ALL;
Use ieee.numeric_std.all;
Use work.regbank_package.all;

ENTITY instruction_decode IS 
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


END instruction_decode;

ARCHITECTURE behavior OF instruction_decode IS
	signal opcode : 	std_logic_vector(5 downto 0) := (others => 'Z');
	signal addReg_s :	std_logic_vector(4 downto 0) := (others => 'Z');
	signal addReg_t :	std_logic_vector(4 downto 0) := (others => 'Z');
	signal addIntReg_s : integer := 0;
	signal addIntReg_t : integer := 0;
	signal imm : 		std_logic_vector(15 downto 0) := (others => 'Z');
	constant NAT_32 :	natural := 32;
BEGIN
	opcode(5 downto 0) <= instr_in(31 downto 26);
	addReg_s <= instr_in(25 downto 21);
	addReg_t <= instr_in(20 downto 16);
	imm <= instr_in(15 downto 0);
	addIntReg_s <= to_integer(unsigned(addReg_s));
	addIntReg_t <= to_integer(unsigned(addReg_t));
		
decode: process (clk, start)
	begin

	for index in 1 to 31 loop
			clear_array(index) <= '1';
			I_array(index) <= (others => '0');
			load_array <= (others => '0');
	end loop;

	-- check for clock rising edge
		if (clk'event and clk ='1') then 
			-- check for start rising edge 
			if (start = '1') then
				-- check for the instruction type
				-- R type
				if (opcode = "000000") then
					opctrl_out <= '1';
					opfun_out <= instr_in(5 downto 0);
					reg_d_addr(4 downto 0) <= instr_in(15 downto 11);
					shamt <= instr_in(10 downto 6);
					imm_16(15 downto 0) <= (others => '0');
					imm_32(31 downto 0) <= (others => '0');
					npc_out(31 downto 0) <= npc_in(31 downto 0);
					reg_s(31 downto 0) <= Q_array(addIntReg_s);
					reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);
					reg_t_addr(4 downto 0) <= (others =>'0');

				-- Jump
				elsif (opcode = "000010") then
					opctrl_out <= '0';
					opfun_out <= instr_in(31 downto 26);
					reg_d_addr(4 downto 0) <= "00000";
					shamt <= "00000";
					imm_16(15 downto 0) <= (others => '0');
					imm_32(31 downto 0) <= (others => '0');
					npc_out(31 downto 0) <= "000000" & instr_in(25 downto 0);
					reg_s(31 downto 0) <= (others => '0');
					reg_t_cont(31 downto 0) <= (others => '0');
					reg_t_addr (4 downto 0) <= (others =>'0');

				-- Jump and link	
				elsif (opcode = "000011") then
					opctrl_out <= '0';
					opfun_out <= instr_in(31 downto 26);
					reg_d_addr(4 downto 0) <= "00000";
					shamt <= "00000";
					imm_16(15 downto 0) <= imm;
					imm_32(31 downto 0) <= (others => '0');
					npc_out(31 downto 0) <= "000000" & instr_in(25 downto 0);
					I_array(31) <= npc_in(31 downto 0);
					load_array(31) <= '1';
					reg_s(31 downto 0) <= (others => '0');
					reg_t_cont(31 downto 0) <= (others => '0');
					reg_t_addr (4 downto 0) <= (others =>'0');

				-- I type
				else
					opctrl_out <= '0';
					opfun_out <= instr_in(31 downto 26);
					reg_d_addr(4 downto 0) <= "00000";
					shamt <= "00000";
					imm_16(15 downto 0) <= imm;
					imm_32(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
					npc_out(31 downto 0) <= npc_in(31 downto 0);
					reg_s(31 downto 0) <= Q_array(addIntReg_s);
					reg_t_addr(4 downto 0) <= addReg_t(4 downto 0);
					reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);

				end if;
				done <= '1';
			else 
				done <= '0'; 
			end if; 
		end if ;
	end process;
END behavior;