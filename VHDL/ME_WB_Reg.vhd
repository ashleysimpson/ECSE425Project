library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity registerMEWB is
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
end registerMEWB;

architecture behaviour of registerMEWB is
begin
    process (clock)
	    variable opctrl: std_logic;
		variable opfun: std_logic_vector(5 downto 0);
		variable reg_t_addr: std_logic_vector(4 downto 0);
		variable reg_d_addr: std_logic_vector(4 downto 0);
		variable alu: std_logic_vector(31 downto 0);
		variable mem_output : std_logic_vector(31 downto 0);

	    begin 
	        if (rising_edge(clock) and load_pipe_reg = '1') then
	  			opctrl := opctrl_in;
				opfun := opfun_in;
				reg_t_addr := reg_t_addr_in;
				reg_d_addr := reg_d_addr_in;
				alu := alu_in;
				mem_output := mem_output_in;

	            opctrl_out <= opctrl;
				opfun_out <= opfun;
				reg_t_addr_out <= reg_t_addr;
				reg_d_addr_out <= reg_d_addr;
				alu_out <= alu;
				mem_output_out <= mem_output;

	        end if;

	        if (rising_edge(clock) and clear_pipe_reg = '0') then
	        	opctrl_out <= '0';
				opfun_out <= "000000";
				reg_t_addr_out <= "00000";
				reg_d_addr_out <= "00000";
				alu_out <= "00000000000000000000000000000000";
				mem_output_out <= "00000000000000000000000000000000";
	        end if;
	end process;
end behaviour;