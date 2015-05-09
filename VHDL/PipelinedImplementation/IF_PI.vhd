-- IF.vhd
-- Authors: Anthony Delage, Philippe Fortin Simard, Julien Castellano, Ashley Simpson
-- Instruction Fetch stage of the processor.

LIBRARY ieee;
LIBRARY work;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.ALL;

ENTITY instruction_fetch IS 
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
END instruction_fetch;

ARCHITECTURE behavior OF instruction_fetch IS
	-- Init FSM
	type if_state_type 		is (read_mem, mem_wait);
	signal if_state : 		if_state_type := read_mem;
	constant SLV_4 :		std_logic_vector(2 downto 0) := "100";
BEGIN

	process (clk)
		-- No variable declarations. Signals used instead.
	begin

		-- 	Start on clock edge and when start is enabled
		if (clk'event and clk = '1') then
			
			-- On rising edge of start signal, take inputs and compute outputs
			if (start = '1') then

				case if_state is

					when read_mem =>
						-- Fetch next instruction
						data <= (others => 'Z');
						we <= '0';
						re <= '1';
						address <= pc_in;
						Word_Byte <= '1';
						if_state <= mem_wait; 

					when mem_wait =>
						-- Wait for rd_ready to be set to 1 by memory
						if rd_ready = '1' then
							instr_out <= data;

							-- Update PC
							npc_out <= std_logic_vector(unsigned(pc_in) + unsigned(SLV_4));

							-- Set done to 1 to signal end of IF to main
							done <= '1';
							if_state <= read_mem;

						end if;
						
				end case;
				
			-- When start is set to 0 by main, set done to 0 and wait for next start
			else
				done <= '0';
			end if;
		end if;
	end process;
END behavior;