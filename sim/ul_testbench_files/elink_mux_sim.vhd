------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File			: elink_mux.vhd
-- Author		: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company		: NRF iThemba LABS
-- Created   	: 2020-06-27
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version		: 0.2
-------------------------------------------------------------------------------
-- last changes: <05/06/2020> 
-- Reasons		:  
-- change signal names
-- decrease buffer sizes
-------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
--	Description:
-- The objective of the code below is to store incoming data from 4 local data frame 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for elink_mux
--=============================================================================
entity cmp_elink_mux is
	generic ( g_REGIONAL_ID : natural);
	port (
	-----------------------------------------------------------------------
	clk_240			: in std_logic;								-- TTC clock bus                       
	reset_p			: in std_logic;								-- reset active high
	--
	mid_rx_en_i		: in std_logic;								-- mid enable
	mid_rx_valid_i	: in std_logic;								-- mid data valid 	
	mid_rx_data_i	: in std_logic_vector(39 downto 0);		-- mid e-links raw data 
	--
	ttc_valid_i		: in std_logic;								-- TTC VALID 
	ttc_bcid_i		: in std_logic_vector(15 downto 0);		-- TTC BC
	ttc_trigger_i	: in t_mid_trginfo;							-- TTC trigger info (SOC,EOC,PHY,SOT,EOT)	
	--
	packet_full_i	: in std_logic;								-- Packet full flag in 
	--
	elink_trigger_o 	: out std_logic_vector(2 downto 0);
	elink_full_o 		: out std_logic_vector(4 downto 0);
	elink_empty_o 		: out std_logic_vector(4 downto 0);
	elink_active_o 	: out std_logic_vector(4 downto 0);
	elink_req_o 		: out std_logic_vector(4 downto 0);
	elink_pause_o		: out std_logic_vector(4 downto 0);
	elink_resume_o		: out std_logic;
	--
	packet_crateID_o	: out std_logic_vector(3 downto 0);	-- Packet crate ID 
	packet_ready_o		: out std_logic;								-- Packet ready 
	packet_val_o		: out std_logic;								-- Packet val 
	packet_size_o		: out std_logic_vector(15 downto 0);	-- Packet counter 
	packet_data_o		: out std_logic_vector(255 downto 0)	-- Packet data out
	------------------------------------------------------------------------
				);  
end cmp_elink_mux;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of cmp_elink_mux is
	-- ========================================================
	-- SYMBOLIC ENCODED state machine: state_reg; state_next
	-- ========================================================
	type t_loc_mux_state is (IDLE, RE_REG, RE_LOC, MUX_LOC); 
	signal state_next : t_loc_mux_state;
	signal state_reg  : t_loc_mux_state; 
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal loc_data		: t_mid_loc_array(3 downto 0);	-- local frame data  
	signal loc_req 		: std_logic_vector(3 downto 0);	-- local request
	
	signal reg_req 	: std_logic;								-- regional frme read
	signal reg_data	: std_logic_vector(39 downto 0);		-- regional frame data  
	
	signal temp_val   : std_logic;								-- temporary packet valid
	signal temp_stop  : std_logic;								-- temporary packet stop
	signal temp_data 	: std_logic_vector(255 downto 0); 	-- temporary packet data
	
	signal out_val   	: std_logic;								-- temporary output valid
	signal out_data	: std_logic_vector(7 downto 0);		-- temporary output byte data
	
	signal resume		: std_logic;								-- resume data acquisition
	signal pause		: std_logic_vector(4 downto 0);		-- pause data acquisition

	signal elink_active	: std_logic_vector(4 downto 0);	-- elink active
	signal elink_full		: std_logic_vector(4 downto 0);	-- memory full
	signal elink_empty	: std_logic_vector(4 downto 0);	-- memories empty
	
	signal state_time : integer := 0;
--=============================================================================
-- architecture begin
--=============================================================================
begin 
	--=============================================================================
	-- Begin of LOC_GEN
	-- This statement generates the port mapping of 4 local boards
	--=============================================================================
	LOC_GEN : for i in 0 to 3 generate		 
		--================--
		-- LOCAL ELINKS 	--
		--================--
		ELL: local_elink 
		port map ( 
		clk_240					=>  clk_240,
		reset_p					=> reset_p,
		mid_rx_en_i				=>	mid_rx_en_i,
		mid_rx_valid_i			=>	mid_rx_valid_i,
		mid_rx_data_i			=>	mid_rx_data_i(7+8*i downto 8*i),
		ttc_valid_i				=>	ttc_valid_i,
		ttc_bcid_i				=>	ttc_bcid_i,
		ttc_trigger_i			=>	ttc_trigger_i,
		loc_res_i				=>	resume,
		loc_req_i				=>	loc_req(i),
		loc_pau_o				=>	pause(i),
		loc_full_o				=>	elink_full(i),
		loc_empty_o				=>	elink_empty(i),
		loc_active_o			=>	elink_active(i),
		loc_data_o				=>	loc_data(i));
	end generate LOC_GEN;
	--=====================--
	-- REGIONAL ELINKS 	--
	--=====================--
	ERE: regional_elink
	generic map ( g_REGIONAL_ID => g_REGIONAL_ID)
	port map ( 
	clk_240					=> clk_240,
	reset_p					=> reset_p,
	mid_rx_en_i				=>	mid_rx_en_i,
	mid_rx_valid_i			=>	mid_rx_valid_i,
	mid_rx_data_i			=>	mid_rx_data_i(39 downto 32),
	ttc_valid_i				=>	ttc_valid_i,
	ttc_bcid_i				=>	ttc_bcid_i,
	ttc_trigger_i			=>	ttc_trigger_i,
	reg_res_i				=>	resume,
	reg_req_i				=>	reg_req,
	reg_pau_o				=>	pause(4),
	reg_full_o				=>	elink_full(4),
	reg_empty_o				=>	elink_empty(4),
	reg_active_o			=>	elink_active(4),
	reg_ID_o					=>	packet_crateID_o,
	reg_data_o				=>	reg_data);
	--=============================================================================
	-- Begin of p_daq
	-- This process enables the resume the data taking 
	--=============================================================================
		p_daq: process(clk_240)
				variable is_pausing : natural range 0 to 5 := 0;
			begin
				if rising_edge(clk_240) then 
					-- default 
					resume  <= '0';
					-- convert pause into natural 
					-- is_pausing = reg#L + loc#3 + loc#2 + loc#1 + loc#0
					is_pausing := f_ADD_5INT (pause); 
					-- number of boards active = number of pause signals sent 
					-- but at t = 0ns, 0 board active and 0 signal sent  (hence we meet this condition)
					-- to overcome this issue, wait until at least 2 boards send a pause signal,
					-- make sure all buffers are empty and the state_reg = idle then resume the DAQ
					if ((pause = elink_active) and (is_pausing > 2)) then 
						if elink_empty = "11111" and state_reg = idle then 
							resume <= '1';
						end if;
					-- emergency 
					-- buffer full
					elsif elink_full /= "00000" then 
						resume <= '1';
					end if;
				end if;
			end process;
	--=============================================================================
	-- Begin of p_state
	-- This process contains sequential part of the state machine
	--=============================================================================
	p_state: process(clk_240, reset_p)
	begin
		if rising_edge(clk_240) then
			if reset_p = '1' then
				state_reg <= idle;
			else
				state_reg <= state_next;
			end if;
		end if;
	end process p_state; 
	--=============================================================================
	-- Begin of p_timer 
	-- This process counts the number of clock cycles spent in the same state 
	--============================================================================= 
	p_timer: process(clk_240)
	begin 
		if rising_edge(clk_240) then 
			if reset_p = '1' then
				state_time <= 0;
			else 
				if state_reg /= state_next then  
					-- reset counter during change in state 
					state_time  <= 0;
				else 
					-- state time max  
					if state_time > 21 then 
						state_time <= 0;
					else 
						-- increment counter 
						state_time <= state_time + 1;
					end if;
				end if; 
			end if;
		end if; 
	end process p_timer; 
	--=============================================================================
	-- Begin of p_state_cb
	-- This process contains combitional part of the state machine
	--=============================================================================
	p_state_cb: process(state_time, state_reg, packet_full_i,elink_empty, loc_data, reg_data)
	variable loc_id: integer range 0 to 3 := 0;
	begin 
		-- default state -- 
		state_next	<= state_reg;
		-- default signals
		reg_req <= '0';
		loc_req <= x"0";
		-- default output --
		out_data	<= (others => '0');	
		out_val   <= '0';				
		-- case state --
		case state_reg is 
		when idle =>
			if packet_full_i /= '1' then
				-- regional 
				if elink_empty(4) /= '1'  then
					reg_req <= '1';	-- request regional
					state_next <= re_reg;	
				-- locals
				elsif elink_empty(3 downto 0) /= x"F" then
					state_next <= mux_loc;
				end if;
			end if;
		--================
		-- RE REGIONAL --
		--================
		-- state "Re_reg"	
		when Re_reg  =>
			-- read byte fragments of the regional word 
			out_data <= reg_data(39-state_time*8 downto 32-state_time*8);  
			out_val <= '1'; 
			if state_time = 4 then
				-- last byte  
				if elink_empty(4) = '1' and elink_empty(3 downto 0) /= x"F" then
					-- data available in local memories 
					state_next <= mux_loc;  
				else 
					state_next <= idle;
				end if;
			end if;
		--============
		-- MUX LOC  --
		--============
		-- state "mux_loc"	
		when mux_loc  =>
			-- assign local ID 
			if elink_empty(3) /= '1' then 
				-- loc#3
				loc_id := 3;
				loc_req(3) <= '1';
			elsif elink_empty(2) /= '1' then 
				-- loc#2
				loc_id := 2;
				loc_req(2) <= '1';
			elsif elink_empty(1) /= '1' then
				-- loc#1
				loc_id := 1;
				loc_req(1) <= '1';
			elsif elink_empty(0) /= '1' then 
				-- loc#0
				loc_id := 0;
				loc_req(0) <= '1';
			end if;
			-- change state  
			if elink_empty(3 downto 0) /= x"F" then 
				state_next <= re_loc;
			else
				state_next <= idle;
			end if;
		--==============
		-- RE LOCALS --
		--==============
		-- state "Re_loc"	
		when re_loc => 		
			-- read byte fragments of the extracted local word
			out_data <= loc_data(loc_id)(167-state_time*8 downto 160-state_time*8); 
			out_val <= '1'; 
			
			case state_time is 
			when 4 => 
				-------------
				-- No strip --
				-------------
				-- fifth byte of the local extracted word 
				if loc_data(loc_id)(131 downto 128) = x"0" then
					-- no strip patterns
					-- change state 
					if loc_id = 0 then 
						state_next <= idle;
					else
						state_next <= mux_loc;
					end if;
				end if;
			when 8 => 
				---------------
				-- 1 chamber --
				---------------
				-- nineth byte of the local extracted word
				case loc_data(loc_id)(131 downto 128) is 
				when x"1"|x"2"|x"4"|x"8" =>
					-- change state
					if loc_id = 0 then 
						state_next <= idle;
					else
						state_next <= mux_loc;
					end if;
				when others => null;
				end case;
			when 12 => 
				----------------
				-- 2 chambers --
				----------------             
				-- thirdteenth byte of the local extracted word
				case loc_data(loc_id)(131 downto 128)  is 
				when x"3"|x"5"|x"6"|x"9"|x"A"|x"C" =>
					-- change state 
					if loc_id = 0 then 
						state_next <= idle;
					else 
						state_next <= mux_loc;
					end if;
				when others => null;
				end case;
				
			when 16 => 
				----------------
				-- 3 chambers --
				----------------              
				-- seventeenth byte of the local extracted word
				case loc_data(loc_id)(131 downto 128)  is 
				when x"7"|x"B"|x"E" =>
					-- change state
					if loc_id = 0 then 
						state_next <= idle;
					else 
						state_next <= mux_loc;
					end if;
				when others => null;
				end case;
				
			when 20 => 
				-----------------
				-- 4 chambers --
				----------------            
				-- twenty-first byte of the local extracted word
				-- change state
				if loc_id = 0 then 
					state_next <= idle;
				else 
					state_next <= mux_loc;
				end if;
			when others => null;
			end case;	
		when others =>
		-- all the other states (not defined)
		-- jump to save state (ERROR?!)
		state_next <= idle;
		end case; 		
	end process p_state_cb;
	--=============================================================================
	-- Begin of p_readout
	-- This process contains combitional part of the state machine
	--=============================================================================
	p_readout: process(clk_240)
	variable index : integer range 0 to 32 := 0; --packet byte counter 
	begin
		if rising_edge(clk_240) then
			-- default --
			temp_val <= '0'; 						-- temporary enable out  
			temp_stop <= '0';						-- temporary stop 
			if reset_p = '1' then 
				index := 0;              			-- reset counter 
				temp_data <= (others => '0'); -- reset temporary packet register 
			else 
				if out_val = '1' then 
					-- store (0 - 31 bytes) in the temporary packet register
					temp_data(255-index*8 downto 248-index*8) <= out_data;
						-- check index 
						if index = 31 then 
							-- last byte of the packet register
							-- enable the packet readout 
							-- reset the byte counter 
							temp_val <= '1';
							index := 0;
						else 
							-- increment index
							index := index + 1;
						end if;
				elsif resume = '1' and elink_full = "00000" then 
					if index > 0 then 
						-- fill the space with zeros
						-- stop the data taking 
						temp_data <= temp_data(255 downto 248-index*8) & std_logic_vector(to_unsigned(0,248-index*8));  
						temp_val <= '1';  
						temp_stop <= '1';
						index := 0;
					elsif index = 0 then  
						--end of trigger data
						temp_stop <= '1';
					end if;
				end if;
			end if;
		end if;
	end process p_readout;
	--=============================================================================
	-- Begin of p_pushed
	-- This process counts the number of pscket data pushed 
	--=============================================================================
	p_pushed: process(clk_240)
		variable pushed : unsigned(15 downto 0) := x"0000";
	begin
		if rising_edge(clk_240) then
			-- default 
			packet_size_o <= (others => '0');
			packet_ready_o <= '0';
			-- increment the word pushed 
			if temp_val = '1'  then 
				pushed := pushed + 1;
			end if;
			-- last push
			if temp_stop = '1' then  
				packet_size_o <= std_logic_vector(pushed);
				packet_ready_o <= '1';
				pushed := x"0000";
			end if;
		end if;
	end process p_pushed;
	-- packet
	packet_val_o <= temp_val;
	packet_data_o <= temp_data;	
	-- status --
	elink_req_o <= reg_req & loc_req;
	elink_empty_o 	<=	elink_empty; 
	elink_full_o 	<=	elink_full; 
	elink_active_o <=	elink_active; 
	elink_pause_o 	<= pause;
	elink_resume_o	<= resume;
	elink_trigger_o <= reg_data(31 downto 30) & reg_data(24);
end rtl;
--=============================================================================
-- architecture end
--=============================================================================