------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File	     : gbt_ulogic.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-27
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes 
-- <13-10-2020> Change the name of the module 
-- <13/02/2021> add the avalon output port 
-------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
-- Description: This modules instantiates the packetizer, the update_header  
-- as well as the transmitter modules. It also defines specific trigger signals 
-- used later to switch between triggered and continuous mode.
-------------------------------------------------------------------------
-- Copyright (c) 2018
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
--Entity declaration for gbt_ulogic top level 
--=============================================================================
entity gbt_ulogic is
	generic (g_LINK_ID : integer := 1);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240             : in std_logic;		
	-------------------------------------------------------------------
	-- reset --
	reset_i             : in std_logic;		
	-------------------------------------------------------------------
	-- timing and trigger control info --					 
	ttc_mode_i          : in t_mid_mode;
    ttc_sox_pulse_i     : in std_logic;
	ttc_eox_pulse_i     : in std_logic;
	ttc_sel_pulse_i     : in std_logic;	
	ttc_tfm_pulse_i     : in std_logic;
	-------------------------------------------------------------------
	-- mid rx bus --
	gbt_val_i           : in std_logic;
	gbt_data_i          : in std_logic_vector(79 downto 0);
	-------------------------------------------------------------------
	-- dw limited counter --
	dw_limited_cnt_i    : in std_logic_vector(15 downto 0);  
	-------------------------------------------------------------------
	-- mid config --
	mid_switch_i        : in std_logic_vector(3 downto 0);
	mid_sync_i          : in std_logic_vector(11 downto 0);
	-- mid monitor
	gbt_monitor_o       : out std_logic_vector(31 downto 0);
	-------------------------------------------------------------------
	-- gbt access --
	gbt_access_val_i    : in  std_logic;
	gbt_access_ack_i    : in  std_logic;		
	gbt_access_req_o    : out std_logic;
	-------------------------------------------------------------------		
	-- gbt datapath info --
	gbt_datapath_o      : out t_mid_gbt_datapath; 
	gbt_datapath_cnt_o  : out std_logic_vector(15 downto 0)
	--------------------------------------------------------------------
				);  
end gbt_ulogic;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of gbt_ulogic is
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- payloads 
	signal s_payload        : t_mid_pload;    
	signal s_payload_empty	: std_logic_vector(1 downto 0);                 
	signal s_payload_rdreq	: std_logic_vector(1 downto 0); 
	signal s_payload_monitor: t_mid_pload_monit;  
	-- packets
	signal s_packet         : t_mid_pkt_array(1 downto 0);
	signal s_packet_rdreq 	: std_logic_vector(1 downto 0);   
	signal s_packet_monitor : t_mid_elink_monit_array(1 downto 0);	
	-- gbt access  
	signal s_gbt_access_req : std_logic;
	-- gbt datapath
	signal s_gbt_datapath     : t_mid_gbt_datapath;
	signal s_gbt_datapath_cnt : std_logic_vector(15 downto 0);
	signal s_gbt_monitor_word : Array32bit(3 downto 0);
	signal s_trans_monitor    : t_mid_trans_monit;

begin	
	--============--
	-- PACKETIZER --
	--============--
	packetizer_inst: packetizer
	generic map (g_LINK_ID => g_LINK_ID)
	port map  (
	clk_240            => clk_240,	
	--	
	reset_i            => reset_i,	
	--
	sox_pulse_i        => ttc_sox_pulse_i,
	eox_pulse_i        => ttc_eox_pulse_i,
	sel_pulse_i        => ttc_sel_pulse_i,	
	tfm_pulse_i        => ttc_tfm_pulse_i,
	ttc_mode_i         => ttc_mode_i,
	--
	gbt_val_i          => gbt_val_i,	
	gbt_data_i         => gbt_data_i,
	--
	mid_sync_i         => mid_sync_i,							
	--
	packet_o           => s_packet,													
	packet_rdreq_i     => s_packet_rdreq,
	packet_monitor_o   => s_packet_monitor,
	-- 
	payload_o          => s_payload,
	payload_monitor_o  => s_payload_monitor,
	payload_empty_o    => s_payload_empty,
	payload_rdreq_i    => s_payload_rdreq);
	
	--============--
	-- TRANSMITTER --
	--============--
	transmitter_inst: transmitter
	port map (
	clk_240             => clk_240,
	--	
	reset_i             => reset_i,
	-- 
	packet_i            => s_packet,
	packet_rdreq_o      => s_packet_rdreq,
	--
	payload_i           => s_payload,
	payload_empty_i     => s_payload_empty,
	payload_rdreq_o     => s_payload_rdreq,
	--
	dw_limited_cnt_i    => dw_limited_cnt_i, 
	--
	gbt_access_val_i    => gbt_access_val_i,
	gbt_access_ack_i    => gbt_access_ack_i,
	gbt_access_req_o    => s_gbt_access_req,
	--
	gbt_datapath_o      => s_gbt_datapath,
	gbt_datapath_cnt_o  => s_gbt_datapath_cnt,
	--
	trans_monitor_o     => s_trans_monitor);  
    
	-- monitoring 
	s_gbt_monitor_word(0)(31 downto 28) <= s_packet_monitor(1).crateID or s_packet_monitor(0).crateID;    
	s_gbt_monitor_word(0)(27 downto 24) <= std_logic_vector(to_unsigned(g_LINK_ID mod 2,4));            
	s_gbt_monitor_word(0)(23 downto 14) <= s_packet_monitor(1).active_cards & s_packet_monitor(0).active_cards;     
	s_gbt_monitor_word(0)(13 downto 4)  <= s_packet_monitor(1).inactive_cards & s_packet_monitor(0).inactive_cards;  
	s_gbt_monitor_word(0)(3 downto 0)   <= s_packet_monitor(1).daq_enable & s_packet_monitor(0).daq_enable & s_packet_monitor(1).pending_cards & s_packet_monitor(0).pending_cards; -- 4-bit

	s_gbt_monitor_word(1)(31 downto 16) <= s_packet_monitor(1).fsm & s_packet_monitor(1).missing_event_cnt;  
	s_gbt_monitor_word(1)(15 downto 0)  <= s_packet_monitor(0).fsm & s_packet_monitor(0).missing_event_cnt;  

	s_gbt_monitor_word(2)(31 downto 16) <= s_payload_monitor.missing_load_cnt(1);  
	s_gbt_monitor_word(2)(15 downto 0)  <= s_payload_monitor.missing_load_cnt(0);  

	s_gbt_monitor_word(3)(31 downto 16) <= s_trans_monitor.pushed_cnt;
	s_gbt_monitor_word(3)(15 downto 12) <= s_trans_monitor.fsm;
	s_gbt_monitor_word(3)(11 downto 8)  <= s_packet(1).ready & s_packet(0).ready & (not s_payload_empty);
	s_gbt_monitor_word(3)(7 downto 0)   <= (others => '0'); -- full signals
    
	-- output
    gbt_monitor_o <= s_gbt_monitor_word(1) when mid_switch_i  = x"1" else 
				     s_gbt_monitor_word(2) when mid_switch_i  = x"2" else 
				     s_gbt_monitor_word(3) when mid_switch_i  = x"3" else
				     s_gbt_monitor_word(0);

	gbt_access_req_o    <= s_gbt_access_req;   -- gbt access request
	gbt_datapath_o	    <= s_gbt_datapath;     -- gbt datapath
	gbt_datapath_cnt_o  <= s_gbt_datapath_cnt; -- gbt datapath counter
	 
	
end rtl;
--===========================================================================--
-- architecture end
--============================================================================--