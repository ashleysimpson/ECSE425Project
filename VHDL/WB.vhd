-- WB.vhd
-- Authors: Julien Castellano, Anthony Delage, Philippe Fortin Simard, Ashley Simpson
-- Write back stage of the processor

LIBRARY ieee;
LIBRARY work;
Use ieee.std_logic_1164.ALL;
Use ieee.numeric_std.all;
Use work.regbank_package.all;

ENTITY write_back IS 
	port(
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
END write_back;

ARCHITECTURE behavior OF write_back IS
	signal opfun_ctrl : 	std_logic_vector(6 downto 0) := (others => 'Z');
	signal addIntReg_t :	integer := 0;
	signal addIntReg_d :	integer := 0; 

BEGIN
	opfun_ctrl(6) <= opctrl_in;
	opfun_ctrl(5 downto 0) <= opfun_in(5 downto 0);
	addIntReg_t <= to_integer(unsigned(reg_t_addr));
	addIntReg_d <= to_integer(unsigned(reg_d_addr));
	
	process (clk, start)
	begin

	for index in 1 to 31 loop
			clear_array(index) <= '1';
	end loop;


	-- check for clock rising edge
		if (clk'event and clk ='1') then 
			-- check for start rising edge 
			if (start = '1') then
				
				case opfun_ctrl is
					-- add : Add
					when "1100000" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- sub : Subtract
					when "1100010" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					--addi : Add Immediate
					when "0001000" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';


					-- slt : Set Less Than
					when "1101010" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- slti : Set Less Than Immediate
					when "0001010" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';

					-- and : And
					when "1100100" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- or : Or
					when "1100101" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- nor : Nor
					when "1100111" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- xor : Exclusive Or
					when "1100110" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- andi : And Immediate
					when "0001100" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';

					-- ori : Or Immediate
					when "0001101" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';

					-- xori : Exclusive Or Immediate
					when "0001110" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';		
						
					-- mfhi  : Move From High
					when "1010000" =>	
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- mflo : Move From Low
					when "1010010" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- lui : Load Upper Immediate
					when "0001111" =>
						I_array(addIntReg_t) <= alu_in(31 downto 0);
						load_array(addIntReg_t) <= '1';	

					-- sll : Shift Left Logical
					when "1000000" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- srl : Shift Right Logical
					when "1000010" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- sra : Shift Right Arithmetic
					when "1000011" =>
						I_array(addIntReg_d) <= alu_in(31 downto 0);
						load_array(addIntReg_d) <= '1';

					-- lw : Load Word
					when "0100011" =>
						I_array(addIntReg_t) <= mem_output(31 downto 0);
						load_array(addIntReg_t) <= '1';

					-- lb : Load Byte
					when "0100000" =>
						I_array(addIntReg_t) <= mem_output(31 downto 0);
						load_array(addIntReg_t) <= '1';

					when others =>
						I_array(addIntReg_t) <= (others => '0');
						load_array(addIntReg_t) <= '0';

				end case;

				-- Set done signal to 1 to notify the end of WB to main
				done <= '1';
			--When start is set to 0 by main, set done to 0 and wait for next start
			else
				done <= '0';
			end if; 
		end if;
	end process;
END behavior;
