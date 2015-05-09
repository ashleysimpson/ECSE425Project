-- MEM.vhd
-- Authors: Anthony Delage, Philippe Fortin Simard, Julien Castellano, Ashley Simpson
-- Memory Access stage of the processor.

LIBRARY ieee;
LIBRARY work;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.all;

ENTITY memory_access IS
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

			-- EXE to IF to increment instruction counter
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
END memory_access;

ARCHITECTURE behavior OF memory_access IS
	type mem_state_type 	is (mem_send, mem_write, mem_wait);
	signal mem_state : 		mem_state_type := mem_send;
	signal opfun_ctrl :		std_logic_vector(6 downto 0) := (others => 'Z');

BEGIN

	-- Concatenate opfun_in and opctrl
	opfun_ctrl(6) <= opctrl_in;
	opfun_ctrl(5 downto 0) <= opfun_in(5 downto 0);


	process(clk, start)
		-- No variable declarations. Signals used instead.
	begin
		branch_cond_out <= branch_cond;
		-- 	Start on clock edge and when start is enabled
		if (clk'event and clk = '1') then
			we <= '0';

			-- On rising edge of start signal, take inputs and compute outputs
			if (start = '1') then

				case mem_state is

					when mem_send =>

						-- Pass inputs to outputs when necessary
						opfun_out <= opfun_in;
						opctrl_out <= opctrl_in;
						reg_t_addr_out <= reg_t_addr_in;
						reg_d_addr_out <= reg_d_addr_in;
						alu_out <= alu_in;
				
						-- Set data line to high impedance
						data <= (others => 'Z');

						-- Access memory for memory access instructions
						case opfun_ctrl is
							-- lw : Load Word
							when "0100011" =>
								re <= '1';
								address <= alu_in;
								Word_Byte <= '1';
								mem_state <= mem_wait;

							-- lb : Load Byte
							when "0100000" =>
								re <= '1';
								address <= alu_in;
								Word_Byte <= '0';
								mem_state <= mem_wait;

							-- sw : Store Word
							when "0101011" =>
								address <= alu_in;
								Word_Byte <= '1';
								data <= reg_t_cont_in;
								mem_state <= mem_write;

							-- sb : Store Byte
							when "0101000" =>
								address <= alu_in;
								Word_Byte <= '0';
								data <= reg_t_cont_in;
								mem_state <= mem_write;

							when others =>
								mem_output <= (others => '0');
								done <= '1';
								mem_state <= mem_send; -- Stay in this state, MEM stage complete (unnecessary)

						end case;

					-- To allow delay for the data to "propagate" down the line	
					when mem_write =>
						if (stall ='1') then
							we <= '1';
							mem_state <= mem_wait;
						end if;
		
					when mem_wait =>

						-- Based on instruction, wait for ready signal and proceed.
						case opfun_ctrl is
							-- lw : Load Word
							when "0100011" =>
								-- Wait for rd_ready to be set to 1 by memory
								if(rd_ready = '1') then
									mem_output <= data;
									re <= '0';
									mem_state <= mem_send;
									-- Set done to 1 to signal end of MEM to main
									done <= '1';
								end if;

							-- lb : Load Byte
							when "0100000" =>
								-- Wait for rd_ready to be set to 1 by memory
								if(rd_ready = '1') then
									mem_output <= data;
									re <= '0';
									mem_state <= mem_send;
									-- Set done to 1 to signal end of MEM to main
									done <= '1';
								end if;

							-- sw : Store Word
							when "0101011" =>
								-- Wait for rd_ready to be set to 1 by memory
								if(wr_done = '1') then
									mem_output <= (others => '0');
									we <= '0';
									mem_state <= mem_send;
									-- Set done to 1 to signal end of MEM to main
									done <= '1';
								end if;

							-- sb : Store Byte
							when "0101000" =>
								-- Wait for rd_ready to be set to 1 by memory
								if(wr_done = '1') then
									mem_output <= (others => '0');
									we <= '0';
									mem_state <= mem_send;
									-- Set done to 1 to signal end of MEM to main
									done <= '1';
								end if;

							-- SHould never go here but jst in case, send to mem_send
							when others =>
								mem_state <= mem_send;
								done <= '1';

						end case;

				end case;

			-- When start is set to 0 by main, set done to 0 and wait for next start	
			else
				done <= '0';
			end if;
		end if;
	end process;
END behavior;