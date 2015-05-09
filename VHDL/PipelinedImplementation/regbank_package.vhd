library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package regbank_package is
	type I_type is array (31 downto 0) of std_logic_vector(31 downto 0);
	type load_type is array (31 downto 0) of std_logic;
	type clear_type is array (31 downto 0) of std_logic;
	type Q_type is array (31 downto 0) of std_logic_vector(31 downto 0);
end package regbank_package;