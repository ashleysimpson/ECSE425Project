library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity registerIDEX is
	port(
		opctrl_in:		in std_logic; --
		opfun_in:		in std_logic_vector(5 downto 0);
		reg_s_in:		in std_logic_vector(31 downto 0); --
		reg_t_cont_in:	in std_logic_vector(31 downto 0); --
		reg_t_addr_in:	in std_logic_vector(4 downto 0); --
		reg_d_addr_in:	in std_logic_vector(4 downto 0); --
		shamt_in: 		in std_logic_vector(4 downto 0); --
		imm_16_in:		in std_logic_vector(15 downto 0);
		imm_32_in:		in std_logic_vector(31 downto 0); --
		npc_in:			in std_logic_vector(31 downto 0); --

    	clock:  		in std_logic;
    	load_pipe_reg:  in std_logic;
    	clear_pipe_reg: in std_logic;

    	opctrl_out:		out std_logic;
		opfun_out:		out std_logic_vector(5 downto 0);
		reg_s_out:		out std_logic_vector(31 downto 0); --
		reg_t_cont_out:	out std_logic_vector(31 downto 0); --
		reg_t_addr_out:	out std_logic_vector(4 downto 0);
		reg_d_addr_out:	out std_logic_vector(4 downto 0);
		shamt_out: 		out std_logic_vector(4 downto 0);
		imm_16_out:		out std_logic_vector(15 downto 0);
		imm_32_out:		out std_logic_vector(31 downto 0); --
		npc_out:		out std_logic_vector(31 downto 0) --
	);
end registerIDEX;

architecture behaviour of registerIDEX is
begin

	process (clock)
	    variable opctrl: std_logic; --
		variable opfun: std_logic_vector(5 downto 0);
		variable reg_s: std_logic_vector(31 downto 0); --
		variable reg_t_cont: std_logic_vector(31 downto 0); --
		variable reg_t_addr: std_logic_vector(4 downto 0); --
		variable reg_d_addr: std_logic_vector(4 downto 0); --
		variable shamt: std_logic_vector(4 downto 0); --
		variable imm_16: std_logic_vector(15 downto 0);
		variable imm_32: std_logic_vector(31 downto 0); --
		variable npc: std_logic_vector(31 downto 0);

	    begin 
	        if (rising_edge(clock) and load_pipe_reg = '1') then
	  			opctrl := opctrl_in;
				opfun := opfun_in;
				reg_s := reg_s_in;
				reg_t_cont := reg_t_cont_in;
				reg_t_addr := reg_t_addr_in;
				reg_d_addr := reg_d_addr_in;
				shamt := shamt_in;
				imm_16 := imm_16_in;
				imm_32 := imm_32_in;
				npc := npc_in;

	            opctrl_out <= opctrl;
				opfun_out <= opfun;
				reg_s_out <= reg_s;
				reg_t_cont_out <= reg_t_cont;
				reg_t_addr_out <= reg_t_addr;
				reg_d_addr_out <= reg_d_addr;
				shamt_out <= shamt;
				imm_16_out <= imm_16;
				imm_32_out <= imm_32;
				npc_out <= npc;
	        end if;

	        if (rising_edge(clock) and clear_pipe_reg = '0') then
	        	opctrl_out <= '0';
				opfun_out <= "000000";
				reg_s_out <= "00000000000000000000000000000000";
				reg_t_cont_out <= "00000000000000000000000000000000";
				reg_t_addr_out <= "00000";
				reg_d_addr_out <= "00000";
				shamt_out <= "00000";
				imm_16_out <= "0000000000000000";
				imm_32_out <= "00000000000000000000000000000000";
				npc_out <= "00000000000000000000000000000000";
	        end if;
	end process;

end behaviour;