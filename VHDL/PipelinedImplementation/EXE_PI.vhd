-- EXE.vhd
-- Authors: Anthony Delage, Philippe Fortin Simard, Julien Castellano, Ashley Simpson
-- Execution stage of the processor.

LIBRARY ieee;
LIBRARY work;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all;

ENTITY execution IS
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
END execution;

ARCHITECTURE behavior OF execution IS
	type exe_state_type 	is (exe_base, exe_write_regs);
	signal exe_state : 		exe_state_type := exe_base;
	signal opfun_ctrl :		std_logic_vector(6 downto 0) := (others => 'Z');
	signal mult_result :	std_logic_vector(63 downto 0) := (others => '0');
	signal div_result :		std_logic_vector(31 downto 0) := (others => '0');
	signal div_rem :		std_logic_vector(31 downto 0) := (others => '0'); 
	signal I_hi, I_lo : 	std_logic_vector(31 downto 0) := (others => 'Z');
	signal load_hi, load_lo : std_logic := '1';
	signal clear_hi, clear_lo : std_logic := '1';
	signal Q_hi, Q_lo :		std_logic_vector(31 downto 0) := (others => 'Z');

	-- Component instantiation
	COMPONENT register32
		PORT (
			I:  in std_logic_vector(31 downto 0);
			clock:  in std_logic;
			load:   in std_logic;
			clear:  in std_logic;
			Q:  out std_logic_vector(31 downto 0)
		);
	END COMPONENT;

BEGIN
	
	hi: register32 
	PORT MAP (
		I => I_hi,
		clock => clk,
		load => load_hi,
		clear => clear_hi,
		Q => Q_hi
		);

	lo: register32 
	PORT MAP (
		I => I_lo,
		clock => clk,
		load => load_lo,
		clear => clear_lo,
		Q => Q_lo
		);

	-- Concatenate opfun_in and opctrl
	opfun_ctrl(6) <= opctrl_in;
	opfun_ctrl(5 downto 0) <= opfun_in(5 downto 0);

	process (clk, start)
		-- No variable declarations. Signals used instead.
	begin

		-- 	Start on clock edge and when start is enabled
		if (clk'event and clk = '1') then
			
			-- On rising edge of start signal, take inputs and compute outputs
			if (start = '1') then

				case exe_state is

					when exe_base =>

						-- Pass inputs to outputs when necessary
						opfun_out <= opfun_in;
						opctrl_out <= opctrl_in;
						reg_t_cont_out <= reg_t_cont_in;
						reg_t_addr_out <= reg_t_addr_in;
						reg_d_addr_out <= reg_d_addr_in;
						npc_out <= npc_in;

						-- Opcode/function case statement
						case opfun_ctrl is
							-- add : Add
							when "1100000" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) + signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- sub : Subtract
							when "1100010" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) - signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- addi : Add Immediate
							when "0001000" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) + signed(imm_32));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- mult : Multiply
							when "1011000" =>
								I_hi<= std_logic_vector(signed(reg_s_cont) * signed(reg_t_cont_in))(63 downto 32);
								I_lo <= std_logic_vector(signed(reg_s_cont) * signed(reg_t_cont_in))(31 downto 0);
								branch_cond <= '0';
								exe_state <= exe_write_regs;

							-- div : Divide
							when "1011010" =>
								div_result <= std_logic_vector(signed(reg_s_cont) / signed(reg_t_cont_in));
								div_rem <= std_logic_vector(signed(reg_s_cont) rem signed(reg_t_cont_in));
								branch_cond <= '0';
								exe_state <= exe_write_regs;

							-- slt : Set Less Than
							when "1101010" =>
								if (signed(reg_s_cont) < signed(reg_t_cont_in)) then
									alu_output <= x"00000001";
								else 
									alu_output <= (others => '0');
								end if;
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- slti : Set Less Than Immediate
							when "0001010" =>
								if (signed(reg_s_cont) < signed(imm_32)) then
									alu_output <= x"00000001";
								else 
									alu_output <= (others => '0');
								end if;
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- and : And
							when "1100100" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) and signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- or : Or
							when "1100101" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) or signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- nor : Nor
							when "1100111" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) nor signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- xor : Exclusive Or
							when "1100110" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) xor signed(reg_t_cont_in));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- andi : And Immediate
							when "0001100" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) and signed(imm_32));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- ori : Or Immediate
							when "0001101" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) or signed(imm_32));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- xori : Exclusive Or Immediate
							when "0001110" =>
								alu_output <= std_logic_vector(signed(reg_s_cont) xor signed(imm_32));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- mfhi  : Move From High
							when "1010000" =>
								alu_output <= Q_hi;
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- mflo : Move From Low
							when "1010010" =>
								alu_output <= Q_lo;
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- lui : Load Upper Immediate
							when "0001111" =>
								alu_output(31 downto 16) <= imm_16(15 downto 0);
								alu_output(15 downto 0) <= (others => '0');
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- sll : Shift Left Logical
							when "1000000" =>
								alu_output <= to_stdlogicvector(to_bitvector(reg_t_cont_in) sll to_integer(unsigned(shamt)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- srl : Shift Right Logical
							when "1000010" =>
								alu_output <= to_stdlogicvector(to_bitvector(reg_t_cont_in) srl to_integer(unsigned(shamt)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- sra : Shift Right Arithmetic
							when "1000011" =>
								alu_output <= to_stdlogicvector(to_bitvector(reg_t_cont_in) sra to_integer(unsigned(shamt)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- lw : Load Word
							when "0100011" =>
								alu_output <= std_logic_vector(unsigned(signed(unsigned(reg_s_cont)) + signed(imm_32)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- lb : Load Byte
							when "0100000" =>
								alu_output <= std_logic_vector(unsigned(signed(unsigned(reg_s_cont)) + signed(imm_32)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- sw : Store Word
							when "0101011" =>
								alu_output <= std_logic_vector(unsigned(signed(unsigned(reg_s_cont)) + signed(imm_32)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- sb : Store Byte
							when "0101000" =>
								alu_output <= std_logic_vector(unsigned(signed(unsigned(reg_s_cont)) + signed(imm_32)));
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- beq : Branch Equal
							when "0000100" =>
								if (signed(reg_s_cont) = signed(reg_t_cont_in)) then
									alu_output <= imm_32;
									branch_cond <= '1';
								else
									alu_output <= (others => '0');
									branch_cond <= '0';
								end if;
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- bne : Branch Not Equal
							when "0000101" =>
								if (signed(reg_s_cont) /= signed(reg_t_cont_in)) then
									alu_output <= imm_32;
									branch_cond <= '1';
								else
									alu_output <= (others => '0');
									branch_cond <= '0';
								end if;
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- j : Jump
							when "0000010" =>
								alu_output <= (others => '0');
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- jr : Jump Register
							when "1001000" =>
								alu_output <= reg_s_cont;
								branch_cond <= '1';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							-- jal : Jump And Link
							when "0000011" =>
								alu_output <= (others => '0');
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

							when others =>
								alu_output <= (others => '0');
								branch_cond <= '0';
								-- Set done to 1 to signal end of EXE to main
								done <= '1';

						end case;

					when exe_write_regs =>

						case opfun_ctrl is
							-- mult : Multiply
							when "1011000" =>
								load_hi <= '1';
								load_lo <= '1';
								I_hi <= mult_result(63 downto 32);
								I_lo <= mult_result(31 downto 0);
								done <= '1';
								exe_state <= exe_base;

							-- div : Divide
							when "1011010" =>
								load_hi <= '1';
								load_lo <= '1';
								I_hi <= div_rem;
								I_lo <= div_result;
								done <= '1';
								exe_state <= exe_base;

							when others =>
								exe_state <= exe_base;

						end case;

				end case;
			-- When start is set to 0 by main, set done to 0 and wait for next start
			else
				done <= '0';
			end if;
		end if;
	end process;
END behavior;
