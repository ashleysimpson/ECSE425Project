-- ID.vhd
-- Authors: Julien Castellano, Anthony Delage, Philippe Fortin Simard, Ashley Simpson
-- Decode stage of the processor

LIBRARY ieee;
LIBRARY work;
Use ieee.std_logic_1164.ALL;
Use ieee.numeric_std.all;
Use work.regbank_package.all;

ENTITY instruction_decode IS 
	port(
		clk : 				in std_logic;
		start :  			in std_logic;
		instr_in : 			in std_logic_vector(31 downto 0);
		npc_in : 			in std_logic_vector(31 downto 0);
		Q_array:			in Q_type;

		done : 				out std_logic;
		opctrl_out : 		out std_logic;
		stall:				out std_logic;
		reg_s_dep :			out std_logic_vector(1 downto 0);
		reg_t_dep :			out std_logic_vector(1 downto 0);
		-- if 1 then depends on result from MEM
		-- if 0 then depends on result from EXE
		dep_on_MEM : 		out std_logic;
		opfun_out :			out std_logic_vector(5 downto 0);
		reg_s :				out std_logic_vector(31 downto 0);
		reg_t_cont :		out std_logic_vector(31 downto 0);
		reg_t_addr :		out std_logic_vector(4 downto 0);
		reg_d_addr :		out std_logic_vector(4 downto 0);
		shamt : 			out std_logic_vector(4 downto 0);
		imm_16:				out std_logic_vector(15 downto 0);
		imm_32:				out std_logic_vector(31 downto 0);
		npc_out:			out std_logic_vector(31 downto 0);
		load_r31 :			out std_logic;
		I_r31 :				out std_logic_vector(31 downto 0)
	);
END instruction_decode;

ARCHITECTURE behavior OF instruction_decode IS
	type id_state_type is (id_analyze, id_send_inst, id_branch);
	signal id_state : id_state_type := id_analyze;
	signal opcode : 	std_logic_vector(5 downto 0) := (others => 'Z');
	signal addReg_s :	std_logic_vector(4 downto 0) := (others => 'Z');
	signal addReg_t :	std_logic_vector(4 downto 0) := (others => 'Z');
	signal addIntReg_s : integer := 0;
	signal addIntReg_t : integer := 0;
	signal imm : 		std_logic_vector(15 downto 0) := (others => 'Z');
	signal jumpAddr :	std_logic_vector(25 downto 0) := (others => 'Z');
	signal jumpAddr_32 : std_logic_vector(31 downto 0) := (others => 'Z');
	signal reg_s_cont_br : std_logic_vector(31 downto 0);
	signal reg_t_cont_br : std_logic_vector(31 downto 0);
	signal imm_32_br : std_logic_vector(31 downto 0);
	signal wrp0 : integer := 32;
	signal lw_wrp0 : std_logic := '0';
	signal doneSig : std_logic := '0';
	signal dontDecrement : std_logic := '0';
	constant NAT_32 :	natural := 32;
	constant SLV_4: std_logic_vector(2 downto 0) := "100";
	-- High & Low: -1, Mem: 0
	-- Registers to which current, i+1, i+2, i+3 instructions write
	shared variable wrp1 : integer := 32;
	shared variable wrp2 : integer := 32;
	shared variable wrp3 : integer := 32;
	-- used to store if istruction will be ready to be forwarded in MEM or not
	shared variable lw_wrp1 : std_logic;
	shared variable lw_wrp2 : std_logic;
	shared variable lw_wrp3 : std_logic;

	-- Counter for bubbles
	shared variable bubbles : integer := 0;
	shared variable Structural_hazard : integer :=0;
	shared variable stall_extender : integer :=0;
	
BEGIN
	opcode(5 downto 0) <= instr_in(31 downto 26);
	addReg_s <= instr_in(25 downto 21);
	addReg_t <= instr_in(20 downto 16);
	imm <= instr_in(15 downto 0);
	addIntReg_s <= to_integer(unsigned(addReg_s));
	addIntReg_t <= to_integer(unsigned(addReg_t));
	done <= doneSig;


	-- HAZARD DETECTION PROCESS
	process(doneSig)

	begin
		if (doneSig'event and doneSig = '1') then
			wrp3 := wrp2;
			wrp2 := wrp1;
			wrp1 := wrp0;
			lw_wrp3 := lw_wrp2;
			lw_wrp2 := lw_wrp1;
			lw_wrp1 := lw_wrp0;
		end if;
	end process;
		
	process (clk, start)
		begin

		I_r31 <= (others => '0');
		load_r31 <= '0';
		reg_s_dep <="00";
		reg_t_dep <="00";
	-- check for clock rising edge
		if (clk'event and clk ='1') then 
			-- check for start rising edge 
			if (start = '1') then
			 		case id_state is 
						when id_analyze =>
							--check if R type, then get address of operands
							if (opcode = "000000") then 						
								if (wrp1 = to_integer(unsigned(instr_in(25 downto 21))) or wrp1 = to_integer(unsigned(instr_in(20 downto 16)))) then --rs and rt);
									-- check if the dependency is with the reg_s
									if (instr_in(5 downto 0) = "001000") then
										bubbles := 3;
									else  
										if (lw_wrp1 = '0') then	
											dep_on_MEM <= '0';
											if (wrp1 = to_integer(unsigned(instr_in(25 downto 21)))) then
												reg_s_dep <= "01";
											elsif (wrp1 = to_integer(unsigned(instr_in(20 downto 16)))) then
												reg_t_dep <= "01";
											else 
												reg_s_dep <= "00";
												reg_t_dep <= "00";
											end if;
										else
											dep_on_MEM <='1';
											bubbles :=1;
												reg_s_dep <= "10";
												reg_t_dep <= "10";
										--does not matter there will be a stall
										--for the case when fwd implemented
										end if;
										bubbles := 0;
									end if;
								elsif ((wrp2 = to_integer(unsigned(instr_in(25 downto 21))) or wrp2 = to_integer(unsigned(instr_in(20 downto 16))))) then
									if (instr_in(5 downto 0) = "001000") then
										bubbles := 2;
									else
										if (lw_wrp2 = '0') then	
											dep_on_MEM <= '0';
											if (wrp2 = to_integer(unsigned(instr_in(25 downto 21)))) then
												reg_s_dep <= "10";
											elsif (wrp2 = to_integer(unsigned(instr_in(20 downto 16)))) then
												reg_t_dep <= "10";
											else 
												reg_s_dep <= "00";
												reg_t_dep <= "00";
											end if;
										else 
											dep_on_MEM <= '1';
											bubbles :=0;
											if (wrp2 = to_integer(unsigned(instr_in(25 downto 21)))) then
												reg_s_dep <= "10";
											elsif (wrp2 = to_integer(unsigned(instr_in(20 downto 16)))) then
												reg_t_dep <= "10";
											else 
												reg_s_dep <= "00";
												reg_t_dep <= "00";

											end if;
										end if;
										bubbles := 0;
									end if;
								elsif (wrp3 = to_integer(unsigned(instr_in(25 downto 21))) or wrp3 = to_integer(unsigned(instr_in(20 downto 16)))) then
									if (instr_in(5 downto 0) = "001000") then
										bubbles := 1;
									else 
										if (lw_wrp3 = '0') then
											dep_on_MEM <='0';
											if (wrp3 = to_integer(unsigned(instr_in(25 downto 21)))) then
												reg_s_dep <= "11";
											elsif (wrp3 = to_integer(unsigned(instr_in(20 downto 16)))) then
												reg_t_dep <= "11";
											else 
												reg_s_dep <= "00";
												reg_t_dep <= "00";
											end if;
										else 
											dep_on_MEM <='1';
											if (wrp3 = to_integer(unsigned(instr_in(25 downto 21)))) then
												reg_s_dep <= "11";
											elsif (wrp3 = to_integer(unsigned(instr_in(20 downto 16)))) then
												reg_t_dep <= "11";
											else 
												reg_s_dep <= "00";
												reg_t_dep <= "00";
											end if;
										end if;
										bubbles := 0;
									end if;
								else 
									bubbles :=0;
									reg_s_dep <= "00";
									reg_t_dep <= "00";

									-- forwardingEXE <= "00";
								end if;
							wrp0 <= to_integer(unsigned(instr_in(15 downto 11)));
							-- Jump instruction
							elsif (opcode = "000010") then 
								--For the case when forwarding is implemented and jump ready in ID
								-- set the destination register as '11111' or 31 since it does not matter for data hazards
								wrp0 <= 31;
								
							--jump and link instruction
							elsif (opcode = "000011") then
								--For the case when forwarding is implemented and jump ready in ID
								wrp0 <= 31;

								-- load word or byte 
							elsif ((opcode = "100011") or (opcode = "100000")) then 
								Structural_hazard := 2;
								lw_wrp0 <= '1';
								if ((wrp1 = to_integer(unsigned(instr_in(25 downto 21))))) then --rs and rt);
									bubbles := 0;
									if (lw_wrp1 = '0') then
										dep_on_MEM <= '0';
										reg_s_dep <= "01";
									else 
										dep_on_MEM <= '1';
										bubbles :=1;
										reg_s_dep <= "01";
									end if;
								elsif ((wrp2 = to_integer(unsigned(instr_in(25 downto 21))))) then
									if (lw_wrp2 = '0') then
										dep_on_MEM <='0';
										reg_s_dep <= "10";
									else 
										dep_on_MEM <='1';
										reg_s_dep <= "10";
									end if;
									bubbles :=0;
								elsif ((wrp3 = to_integer(unsigned(instr_in(25 downto 21))))) then
									if (lw_wrp3 = '0') then
										dep_on_MEM <='0';
										reg_s_dep <= "11";
									else 
										dep_on_MEM <='1';
										reg_s_dep <= "11";
									end if;
									bubbles :=0;
								else 
									bubbles := 0;
								end if;
								wrp0 <= to_integer(unsigned(instr_in(20 downto 16)));

							-- store word or byte
							-- used to detect the structural hazard associated with storing to MEM
							elsif ((opcode = "101011") or (opcode = "101000")) then 
								Structural_hazard := 2;
								wrp0 <= 31;
								bubbles :=0;
									if ((wrp1 = to_integer(unsigned(instr_in(25 downto 21))))) then --rs and rt);
										if (lw_wrp1 = '0') then
											dep_on_MEM <= '0';
											reg_s_dep <= "01";
										else 
											dep_on_MEM <= '1';
											reg_s_dep <= "01";
											bubbles :=1;
										end if;
									elsif ((wrp2 = to_integer(unsigned(instr_in(25 downto 21))))) then
										if (lw_wrp2 = '0') then
											dep_on_MEM <='0';
											reg_s_dep <= "10";
										else 
											dep_on_MEM <='1';
											reg_s_dep <= "10";
										end if;
									elsif ((wrp3 = to_integer(unsigned(instr_in(25 downto 21))))) then
										if (lw_wrp3 = '0') then
											dep_on_MEM <='0';
											reg_s_dep <= "11";
										else 
											dep_on_MEM <='1';
											reg_s_dep <= "11";
										end if;
										
									else
									bubbles := 0; 

									end if;

							-- Load upper immediate lui
							elsif (opcode = "001111") then
							 -- for this case nothing is needed for EXE stage
								wrp0 <= to_integer(unsigned(instr_in(20 downto 16)));	

							-- The other I type instructions, including SW, SB
							else
								if ((wrp1 = to_integer(unsigned(instr_in(25 downto 21))))) then --rs and rt);
									bubbles := 0;
									if (lw_wrp1 = '0') then
										dep_on_MEM <= '0';
										reg_s_dep <= "01";
									else 
										dep_on_MEM <= '1';
										bubbles := 1;
										reg_s_dep <= "01";
									end if;					
								elsif ((wrp2 = to_integer(unsigned(instr_in(25 downto 21))))) then
									if (lw_wrp2 = '0') then
										dep_on_MEM <='0';
										reg_s_dep <= "10";
									else 
										dep_on_MEM <='1';
										reg_s_dep <= "10";
									end if;
								bubbles :=0;
								elsif ((wrp3 = to_integer(unsigned(instr_in(25 downto 21))))) then
									if (lw_wrp3 = '0') then
										dep_on_MEM <='0';
										reg_s_dep <= "11";
									else 
										dep_on_MEM <='1';
										reg_s_dep <= "11";
									end if;
									bubbles :=0;
								else 
									bubbles := 0;
								end if;
							wrp0 <= to_integer(unsigned(instr_in(20 downto 16)));	
							end if;
							id_state <= id_send_inst;
				-- check for the instruction type
						when id_send_inst =>
							if (bubbles > 0) then
								opctrl_out <= '1';
								opfun_out <= "000000";
								reg_t_cont(31 downto 0) <= (others => '0');
								reg_s(31 downto 0) <= (others => '0');
								reg_d_addr(4 downto 0) <= "00000";
								bubbles := bubbles -1;
								stall <= '1';
								dontDecrement <= '1';
								npc_out <= npc_in;
								doneSig <='1';
								id_state <= id_analyze;
								-- In the case of a Load or store, the pipe needs to stall while instruction in MEM
								-- If a load or store is found during analyse, 
							elsif (Structural_hazard = 1) then
								stall_extender := 2;
								stall <= '1';
								dontDecrement <= '1';
								Structural_hazard :=0;
								opctrl_out <= '1';
								opfun_out <= "000000";
								reg_t_cont(31 downto 0) <= (others => '0');
								reg_s(31 downto 0) <= (others => '0');
								reg_d_addr(4 downto 0) <= "00000";
								npc_out <= npc_in;
								doneSig <='1';
								id_state <= id_analyze;

							else  
								if (stall_extender > 0) then
									stall_extender := stall_extender -1;
								else
									stall  <='0';
									dontDecrement <='0';
								end if;

								if (Structural_hazard > 0) then
									Structural_hazard := Structural_hazard -1;
								end if;
								-- R type
								if (opcode = "000000") then
									opctrl_out <= '1';
									opfun_out <= instr_in(5 downto 0);
									reg_d_addr(4 downto 0) <= instr_in(15 downto 11);
									shamt <= instr_in(10 downto 6);
									imm_16(15 downto 0) <= (others => '0');
									imm_32(31 downto 0) <= (others => '0');
									jumpAddr(25 downto 0) <= instr_in(25 downto 0);
								--	npc_out(31 downto 0) <= npc_in(31 downto 0);
									reg_s(31 downto 0) <= Q_array(addIntReg_s);
									reg_s_cont_br(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);
									reg_t_addr(4 downto 0) <= (others =>'0');
									if (dontDecrement ='1') then 
										npc_out <=npc_in;
									else
										npc_out <= std_logic_vector(unsigned(npc_in) + unsigned(SLV_4));
									end if;
									-- check if it is a jr
									if (instr_in(5 downto 0) = "001000") then
										doneSig <='0';
										id_state <= id_branch;
									else 
										doneSig <='1';
										id_state <= id_analyze;
									end if;
									
								-- Jump
								elsif (opcode = "000010") then
									opctrl_out <= '0';
									opfun_out <= instr_in(31 downto 26);
									reg_d_addr(4 downto 0) <= "00000";
									shamt <= "00000";
									imm_16(15 downto 0) <= (others => '0');
									imm_32(31 downto 0) <= (others => '0');
									reg_s(31 downto 0) <= (others => '0');
									reg_t_cont(31 downto 0) <= (others => '0');
									reg_t_addr (4 downto 0) <= (others =>'0');
									doneSig <='0';
									id_state <= id_branch;

								-- Jump and link	
								elsif (opcode = "000011") then
									opctrl_out <= '0';
									opfun_out <= instr_in(31 downto 26);
									reg_d_addr(4 downto 0) <= "00000";
									shamt <= "00000";
									imm_16(15 downto 0) <= imm;
									imm_32(31 downto 0) <= (others => '0');
									npc_out(31 downto 0) <= "000000" & instr_in(25 downto 0);
									I_r31 <= npc_in(31 downto 0);
									load_r31 <= '1';
									reg_s(31 downto 0) <= (others => '0');
									reg_t_cont(31 downto 0) <= (others => '0');
									reg_t_addr (4 downto 0) <= (others =>'0');
									-- Operation writes to register 31
									wrp0 <= 31;
									doneSig <='0';
									id_state <= id_branch;

								-- beq : branch equal		
								elsif (opcode = "000100") then
									opctrl_out <= '0';
									opfun_out <= instr_in(31 downto 26);
									reg_d_addr(4 downto 0) <= "00000";
									shamt <= "00000";
									imm_16(15 downto 0) <= imm;
									imm_32(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
									imm_32_br(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
									reg_s(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_addr(4 downto 0) <= addReg_t(4 downto 0);
									reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);
									reg_s_cont_br(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_cont_br(31 downto 0) <= Q_array(addIntReg_t);
									if (instr_in(31 downto 26) = "101011") or (instr_in(31 downto 26) = "101000") or (instr_in(31 downto 26) = "000100") or (instr_in(31 downto 26) = "000101") then
										wrp0 <= 0;
									else
										wrp0 <= addIntReg_t;
									end if;
									doneSig <='0';
									id_state <= id_branch;

								-- bne : Branch Not Equal
								elsif (opcode = "000101") then 
									opctrl_out <= '0';
									opfun_out <= instr_in(31 downto 26);
									reg_d_addr(4 downto 0) <= "00000";
									shamt <= "00000";
									imm_16(15 downto 0) <= imm;
									imm_32(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
									imm_32_br(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
									--npc_out(31 downto 0) <= npc_in(31 downto 0);
									reg_s(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_addr(4 downto 0) <= addReg_t(4 downto 0);
									reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);
									reg_s_cont_br(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_cont_br(31 downto 0) <= Q_array(addIntReg_t);
									if (instr_in(31 downto 26) = "101011") or (instr_in(31 downto 26) = "101000") or (instr_in(31 downto 26) = "000100") or (instr_in(31 downto 26) = "000101") then
										wrp0 <= 0;
									else
										wrp0 <= addIntReg_t;
									end if;
									doneSig <='0';
									id_state <= id_branch;
								

								-- I type
								else  
									opctrl_out <= '0';
									opfun_out <= instr_in(31 downto 26);
									reg_d_addr(4 downto 0) <= "00000";
									shamt <= "00000";
									imm_16(15 downto 0) <= imm;
									imm_32(31 downto 0) <= std_logic_vector(resize(signed(imm), NAT_32));
									npc_out <= std_logic_vector(unsigned(npc_in) + unsigned(SLV_4));
									reg_s(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_addr(4 downto 0) <= addReg_t(4 downto 0);
									reg_t_cont(31 downto 0) <= Q_array(addIntReg_t);
									reg_s_cont_br(31 downto 0) <= Q_array(addIntReg_s);
									reg_t_cont_br(31 downto 0) <= Q_array(addIntReg_t);
									if (instr_in(31 downto 26) = "101011") or (instr_in(31 downto 26) = "101000") or (instr_in(31 downto 26) = "000100") or (instr_in(31 downto 26) = "000101") then
										wrp0 <= 0;
									else
										wrp0 <= addIntReg_t;
									end if;
									doneSig <= '1';
									id_state <= id_analyze;

								end if;
							end if;
						
						when id_branch =>

							--beq
							if (opcode = "000100") then
								if (signed(reg_s_cont_br) = signed(reg_t_cont_br)) then
									npc_out <= imm_32_br;
									opctrl_out <= '1';
									opfun_out <= "100000";
									reg_t_cont(31 downto 0) <= (others => '0');
									reg_s(31 downto 0) <= (others => '0');
									reg_d_addr(4 downto 0) <= "00000";
								else 
									npc_out <= std_logic_vector(unsigned(npc_in) + unsigned(SLV_4));
								end if;
							--bne			
							elsif (opcode = "000101") then
								if (signed(reg_s_cont_br) /= signed(reg_t_cont_br)) then
									npc_out <= imm_32_br;
									opctrl_out <= '1';
									opfun_out <= "100000";
									reg_t_cont(31 downto 0) <= (others => '0');
									reg_s(31 downto 0) <= (others => '0');
									reg_d_addr(4 downto 0) <= "00000";
								else 
									npc_out <= std_logic_vector(unsigned(npc_in) + unsigned(SLV_4));
								end if;
							--jump		
							elsif (opcode = "000010") then
								npc_out(31 downto 0) <= "000000" & instr_in(25 downto 0);
								opctrl_out <= '1';
								opfun_out <= "100000";
								reg_t_cont(31 downto 0) <= (others => '0');
								reg_s(31 downto 0) <= (others => '0');
								reg_d_addr(4 downto 0) <= "00000";
							--jump and link
							elsif (opcode = "000011") then 
								npc_out(31 downto 0) <= "000000" & instr_in(25 downto 0);
								opctrl_out <= '1';
								opfun_out <= "100000";
								reg_t_cont(31 downto 0) <= (others => '0');
								reg_s(31 downto 0) <= (others => '0');
								reg_d_addr(4 downto 0) <= "00000";
							-- jump register, only R type that will come here
							elsif (opcode = "000000") then
								npc_out <= reg_s_cont_br;
								opctrl_out <= '1';
								opfun_out <= "100000";
								reg_t_cont(31 downto 0) <= (others => '0');
								reg_s(31 downto 0) <= (others => '0');
								reg_d_addr(4 downto 0) <= "00000";
							else
								npc_out <= std_logic_vector(unsigned(npc_in) + unsigned(SLV_4));
							end if;
						id_state <= id_analyze;
						doneSig <='1';
					end case;			
			else 
				doneSig <= '0'; 
			end if; 
		end if ;
	end process;
END behavior;