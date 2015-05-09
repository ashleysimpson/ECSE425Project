library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity registerEXME is
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
end registerEXME;

architecture behaviour of registerEXME is
begin
    process (clock)
	    variable opctrl: std_logic;
		variable opfun: std_logic_vector(5 downto 0);
		variable reg_t_cont: std_logic_vector(31 downto 0);
		variable reg_t_addr: std_logic_vector(4 downto 0);
		variable reg_d_addr: std_logic_vector(4 downto 0);
		variable npc: std_logic_vector(31 downto 0);
		variable alu: std_logic_vector(31 downto 0);
		variable branch_cond: std_logic;

	    begin 
	        if (rising_edge(clock) and load_pipe_reg = '1') then
	  			opctrl := opctrl_in;
				opfun := opfun_in;
				reg_t_cont := reg_t_cont_in;
				reg_t_addr := reg_t_addr_in;
				reg_d_addr := reg_d_addr_in;
				npc := npc_in;
				alu := alu_in;
				branch_cond := branch_cond_in;

	            opctrl_out <= opctrl;
				opfun_out <= opfun;
				reg_t_cont_out <= reg_t_cont;
				reg_t_addr_out <= reg_t_addr;
				reg_d_addr_out <= reg_d_addr;
				npc_out <= npc;
				alu_out <= alu;
				branch_cond_out <= branch_cond;

	        end if;

	        if (rising_edge(clock) and clear_pipe_reg = '0') then
	        	opctrl_out <= '0';
				opfun_out <= "000000";
				reg_t_cont_out <= "00000000000000000000000000000000";
				reg_t_addr_out <= "00000";
				reg_d_addr_out <= "00000";
				npc_out <= "00000000000000000000000000000000";
				alu_out <= "00000000000000000000000000000000";
				branch_cond_out <= '0';
	        end if;
	end process;
end behaviour;