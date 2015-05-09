-- FowardingUnit.vhd
-- Authors: Julien Castellano, Anthony Delage, Philippe Fortin Simard, Ashley Simpson
-- Fowarding unit of the processor.

LIBRARY ieee;
LIBRARY work;
Use ieee.std_logic_1164.ALL;
Use ieee.numeric_std.all;
Use work.regbank_package.all;

ENTITY forwarding_unit IS 
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
end forwarding_unit;

ARCHITECTURE behavior OF forwarding_unit IS
	-- If 1 then result from 2 cycles ago needed, if 0, next result needed
	type fwd_state_type 	is (fwd_store, fwd_output);
	signal fwd_state : 	fwd_state_type := fwd_store;
	shared variable prevEXEresult : std_logic_vector(31 downto 0);
	shared variable prev2EXEresult : std_logic_vector(31 downto 0);
	shared variable prevMEMresult : std_logic_vector(31 downto 0);
BEGIN

	process(clk)
	begin 

		if (clk'event and clk ='1') then

			if (start = '1') then
				case fwd_state is 
					when fwd_output => 
						-- check that the pipeline is not stalled
						if (stall = '0') then
							if (dep_on_mem = '0') then
								if ( reg_s_dep = "01") then		
								--check if reg_s needs the value
									reg_s_cont_out <= alu_output;									
									if (reg_t_dep = "01") then
										reg_t_cont_out <= alu_output;
									elsif (reg_t_dep = "10") then
										reg_t_cont_out <= prevEXEresult;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prev2EXEresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;

								elsif ( reg_s_dep = "10") then		
								--check if reg_s needs the value
									reg_s_cont_out <= prevEXEresult;									
									if (reg_t_dep = "01") then
										reg_t_cont_out <= alu_output;
									elsif (reg_t_dep = "10") then
										reg_t_cont_out <= prevEXEresult;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prev2EXEresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;
								elsif ( reg_s_dep = "11") then		
								--check if reg_s needs the value
									reg_s_cont_out <= prev2EXEresult;									
									if (reg_t_dep = "01") then
										reg_t_cont_out <= alu_output;
									elsif (reg_t_dep = "10") then
										reg_t_cont_out <= prevEXEresult;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prev2EXEresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;
								else 
									reg_s_cont_out <= reg_s_cont_in;									
									if (reg_t_dep = "01") then
										reg_t_cont_out <= alu_output;
									elsif (reg_t_dep = "10") then
										reg_t_cont_out <= prevEXEresult;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prev2EXEresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;		
								end if;
							elsif (dep_on_mem = '1') then

								if ( reg_s_dep = "10") then		
								--check if reg_s needs the value
									reg_s_cont_out <= mem_output;									
									if (reg_t_dep = "10") then
										reg_t_cont_out <= mem_output;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prevMEMresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;
								elsif ( reg_s_dep = "11") then		
								--check if reg_s needs the value
									reg_s_cont_out <= prevMEMresult;									
									if (reg_t_dep = "10") then
										reg_t_cont_out <= mem_output;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prevMEMresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;
								else 
									reg_s_cont_out <= reg_s_cont_in;									
									if (reg_t_dep = "10") then
										reg_t_cont_out <= mem_output;
									elsif (reg_t_dep = "11") then
										reg_t_cont_out <= prevMEMresult;
									else 
										reg_t_cont_out <= reg_t_cont_in;
									end if;		
								end if;
							end if;
						-- if the pipeline is stalled do nothing
						else 
						end if;
					fwd_state <= fwd_store;
					when fwd_store =>
						prev2EXEresult := prevEXEresult;
						prevEXEresult := alu_output;
						prevMEMresult := mem_output;
						fwd_state <= fwd_output;
				fwdDone <= '1';
				end case;
			else 
				fwdDone <= '0';
			end if;
		end if;
	end process;
END behavior;