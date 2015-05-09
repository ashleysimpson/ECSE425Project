library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity registerIFID is
	port(   
		instr_in:  		in std_logic_vector(31 downto 0);
		npc_in:			in std_logic_vector(31 downto 0);
    	clock:  		in std_logic;
    	load_pipe_reg:  in std_logic;
    	clear_pipe_reg: in std_logic;
    	instr_out:  	out std_logic_vector(31 downto 0);
    	npc_out:		out std_logic_vector(31 downto 0)
	);
end registerIFID;

architecture behaviour of registerIFID is

    -- Registers
 	COMPONENT register32
	port(   I:  in std_logic_vector(31 downto 0);
	    clock:  in std_logic;
	    load:   in std_logic;
	    clear:  in std_logic;
	    Q:  out std_logic_vector(31 downto 0)
	);
	end COMPONENT;

begin

    instr_reg: register32 
	PORT MAP (
		I => instr_in,
		clock => clock,
		clear => clear_pipe_reg,
		load => load_pipe_reg,
		Q => instr_out
	);

	npc_reg: register32 
	PORT MAP (
		I => npc_in,
		clock => clock,
		clear => clear_pipe_reg,
		load => load_pipe_reg,
		Q => npc_out
	);

end behaviour;