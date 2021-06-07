-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: transmitter.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company	: NRF iThemba LABS
-- Created   	: 2020-10-12
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version	: 2.0
-------------------------------------------------------------------------------
-- last changes 
-- <04/12/2020> set the LINK ID to a fix value 
-- <13/02/2021> add the avalon output port 
--              remove unnecessary logic  	
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to perform data transmisssion.
--------------------------------------------------------------------------------
-- Requirements: <no special requirements> 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Reference:
-- This code was inspired by the dummy user logic example provided by ALICE CRU team.
-- Follow the link below for more information. 
-- https://gitlab.cern.ch/alice-cru/cru-fw/-/blob/master/DETECTOR-UL/DUMMY-UL/hdl/user_logic.vhd
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_mid_ul.all;
use work.pack_cru_core.all;
--=============================================================================
--Entity declaration for packetizer
--=============================================================================
entity transmitter is
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240            : in std_logic;
	-------------------------------------------------------------------
	-- avalon + auto reset --	
	reset_i            : in std_logic;										
	-------------------------------------------------------------------
	-- packet info --
	packet_i           : in t_mid_pkt_array(1 downto 0);				 
	packet_rdreq_o     : out std_logic_vector(1 downto 0);				
	-------------------------------------------------------------------
	-- payload info --
	payload_i          : in t_mid_pload;							 									
	payload_rdreq_o    : out std_logic_vector(1 downto 0);	
	-------------------------------------------------------------------
	-- dw packet info --
	dw_packet_cnt_i    : in std_logic_vector(15 downto 0);
	-------------------------------------------------------------------
	-- header info --
	header_rdreq_i     : in std_logic;				 														
	-------------------------------------------------------------------
	-- gbt access info --
	gbt_access_ack_i   : in  std_logic;										
	gbt_access_req_o   : out std_logic;			
	-------------------------------------------------------------------
	-- gbt packet info --
	gbt_datapath_o     : out t_mid_gbt_datapath;								 
	gbt_datapath_cnt_o: out std_logic_vector(15 downto 0);
	-------------------------------------------------------------------
	-- fsm monitor 
	fsm_monit_o     : out std_logic_vector(3 downto 0)								
	------------------------------------------------------------------------
       );  
end transmitter;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of transmitter is
	-- ===================================================
	-- SYMBOLIC ENCODED state machine: t_trans_state
	-- ===================================================
	type t_trans_state is (
		                IDLE,
			        PLOAD_RDY,
			        PLOAD_VAL,
			        PLOAD_ACCESS,
			        PLOAD_SEND);
						
	signal state : t_trans_state := IDLE;

	signal s_total_cnt: unsigned(15 downto 0) := (others => '0');
	signal s_loadA: unsigned(15 downto 0);
	signal s_loadB: unsigned(15 downto 0);
	-- request packet 
	signal s_packet_rdreq  : std_logic_vector(1 downto 0);
	-- gbt datapath registers
	signal s_gbt_datapath: t_mid_gbt_datapath;
	-- fsm status 
	signal s_fsm_monit : std_logic_vector(3 downto 0);

begin  
	
	--===============================================================================
	-- Begin of p_total_cnt 
	-- This process countains the total number of packets data to be sent during a HBF 
	--===============================================================================
	p_total_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  -- case state --
	  case state is
	  when IDLE => 
	   -- initial condition
	   s_total_cnt <= x"0000"; 
	   s_loadA <= x"0000";
	   s_loadB <= x"0000";
				
	  when PLOAD_VAL => 
	   if payload_i.valid = '1' then 
	    -- number of packets transmitted during a heartbeat frame 
	    s_loadA <= unsigned(payload_i.data(1));                      -- copy the number of heartbeat frame packets collected from upper part of the GBT link
	    s_loadB <= unsigned(payload_i.data(0));                      -- copy the number of heartbeat frame packets collected from lower part of the GBT link
	    s_total_cnt <= sum_Array16bit(payload_i.data);               -- copy the total number of heartbeat frame packets collected from both part of the GBT link
	   end if;
				
	  when PLOAD_ACCESS => 
	   -- decrement --
	   if s_total_cnt > x"0000" and gbt_access_ack_i = '1' then                               
	    s_total_cnt <= s_total_cnt - 1;
	   end if;
				
	  when PLOAD_SEND =>  
	   -- decrement --
	   if s_total_cnt > x"0000" and dw_packet_cnt_i < x"0100" then -- less then 8KB 
	    s_total_cnt <= s_total_cnt - 1;
	   end if;
						
	   -- all heartbeat frame packets collected from the GBT link 
	   if s_total_cnt = s_loadB then 
	    s_loadA <= x"0000";                       -- all heartbeat frame packets collected from upper part of the GBT link
	   elsif s_total_cnt = x"0000" then
	    s_loadB <= x"0000";                       -- all heartbeat frame packets collected from lower part of the GBT link
	   end if;

	  when others => null;
	  end case;
	 end if;
	end process p_total_cnt;
	--=============================================================================
	-- Begin of p_state
	-- This process is a sequencial state machine
	--============================================================================= 
	p_state: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  if reset_i = '1' then 
	   state <= IDLE;
	  else 
	   -- default 
	   s_gbt_datapath.done <= '0';  -- gbt datapath done
				
	   -- case state --
	   case state is
	   --======--
	   -- IDLE -- 
	   --======--
	   -- state "IDLE"
	   when IDLE => 
	    -- header request
	    if header_rdreq_i = '1' then  
	     state <= PLOAD_RDY; 
	    end if;
	   --===========--
	   -- PLOAD_RDY -- 
	   --===========--
	   -- state "PLOAD_RDY"
	   when PLOAD_RDY => 
	    if payload_i.ready = '1' then 
	     state <= PLOAD_VAL;
	    end if;
	   --===========--
	   -- PLOAD_VAL -- 
	   --===========--
	   -- state "PLOAD_VAL"
	   when PLOAD_VAL => 
	    if payload_i.valid = '1' then 
	     state <= PLOAD_ACCESS;
	    end if;
	   --=============--
	   -- PLOAD_ACCESS -- 
	   --=============--
	   -- state "PLOAD_ACCESS"	
	   when PLOAD_ACCESS =>              
	    if gbt_access_ack_i = '1' then			
	      state <= PLOAD_SEND;		 
		end if;
	   --============--
	   -- PLOAD_SEND -- 
	   --============--
	   -- state "PLOAD_SEND"
	   when PLOAD_SEND =>
	    if dw_packet_cnt_i = x"0100" then 
		 state <= PLOAD_ACCESS;
		elsif s_total_cnt = x"0000" then
	     s_gbt_datapath.done <= '1';	  
	     state <= IDLE;
	    end if;

	   when others => 
	    -- all the other states (not defined)
	    -- jump to save state (ERROR?!)
	    state <= IDLE;
	   end case;
	  end if;
	 end if;
	end process p_state;
	--=============================================================================
	-- Begin of p_state_out 
	-- This process transmits the data output of the sequential state machine
	--=============================================================================
	p_state_out: process(clk_240)
	 variable packet_select : std_logic_vector(1 downto 0) := "00";
	begin 
	 if rising_edge(clk_240) then 
		
	  -- default gbt datapath out --
	  s_gbt_datapath.valid  <= '0';            			           			 
	  s_gbt_datapath.data <= (others => '0');
      
	  -- concatenate 
	  packet_select := packet_i(1).valid & packet_i(0).valid;

	  if state = PLOAD_SEND  then 	
	   -- less than 8KB 
	   case packet_select is 
	   when "10" =>
		s_gbt_datapath.data <= packet_i(1).data;		
	    s_gbt_datapath.valid <= '1';
	   when "01" =>
		s_gbt_datapath.data <= packet_i(0).data;		
		s_gbt_datapath.valid <= '1';
	   when others => null;
	   end case;
	  end if;
	 end if;
	end process p_state_out;
	--===========================================================================
	-- Begin of p_prdreq
	-- This process requests packets from the upper and lower part of the GBT link
	--===========================================================================
	p_prdreq: process(state, gbt_access_ack_i, s_total_cnt, dw_packet_cnt_i, s_loadA, s_loadB)
	begin 
	 -- default --
	 s_packet_rdreq <= "00";

	 case state is
	 when PLOAD_ACCESS => 
	  -- access granted 
	  if gbt_access_ack_i = '1' then 
	   if s_total_cnt > x"0000" and s_loadA > x"0000" then 
	    s_packet_rdreq <= "10";                                    -- request packets from upper part of the GBT link
	   elsif s_total_cnt > x"0000" and s_loadB > x"0000" then
	    s_packet_rdreq <= "01";                                    -- request packets from upper part of the GBT link
           end if;
	  end if;
	 
	 when PLOAD_SEND => 
	  -- less than 8KB data 
	  if dw_packet_cnt_i < x"0100" and s_total_cnt > x"0000" then 
	   if s_total_cnt > s_loadB then
	    s_packet_rdreq <= "10";                                   -- request packets from upper part of the GBT link
	   else 
	    s_packet_rdreq <= "01";                                   -- request packets from lower part of the GBT link
           end if;
	  end if;
	 when others => null;
	 end case;
	end process p_prdreq;

	-- FSM status 
	s_fsm_monit <= x"0" when state = IDLE         else -- 0000
		       x"1" when state = PLOAD_RDY    else -- 0001
		       x"2" when state = PLOAD_VAL    else -- 0010
		       x"4" when state = PLOAD_ACCESS else -- 0100
		       x"8" when state = PLOAD_SEND   else -- 1000
		       x"F";                               -- 1111 -- error!!!!
	
	-- packet request
	packet_rdreq_o(1) <= s_packet_rdreq(1) and packet_i(1).ready; -- read from upper part of the GBT link
	packet_rdreq_o(0) <= s_packet_rdreq(0) and packet_i(0).ready; -- read from lower part of the GBT link
	-- gbt access request 
	gbt_access_req_o <= '1' when state = PLOAD_ACCESS and gbt_access_ack_i /= '1' else '0';
	-- payload request 
	payload_rdreq_o <= "11" when state = PLOAD_RDY and payload_i.ready = '1' else "00";  
	-- gbt datapath
	gbt_datapath_o.valid <= s_gbt_datapath.valid;
	gbt_datapath_o.data  <= s_gbt_datapath.data;
	gbt_datapath_o.done  <= s_gbt_datapath.done;
	gbt_datapath_cnt_o   <= std_logic_vector(s_total_cnt); 
	-- avalon monitor
	fsm_monit_o <= s_fsm_monit;
	
end rtl;
--=============================================================================
-- architecture end
--=============================================================================