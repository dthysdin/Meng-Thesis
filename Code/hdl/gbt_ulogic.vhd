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
	generic (g_LINK_ID : integer := 0; g_NUM_HBFRAME_SYNC: integer := 1);
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
	ttc_sel_pulse_i     : in std_logic;
	-------------------------------------------------------------------
	-- mid gbt data --
	mid_rx_bus_i        : in t_mid_gbt;		
	-------------------------------------------------------------------
	--  header 
	header_rdreq_i      : in std_logic;
	-------------------------------------------------------------------
	-- avalon 
	av_gbt_monit_o      : out std_logic_vector(63 downto 0);
	-------------------------------------------------------------------
	-- gbt access --
	gbt_access_ack_i    : in  std_logic;		
	gbt_access_req_o    : out std_logic;		
	-------------------------------------------------------------------
	-- dw packet info --
	dw_packet_cnt_i    : in std_logic_vector(15 downto 0);
	-------------------------------------------------------------------
	-- gbt datapath info --
	gbt_datapath_o     : out t_mid_gbt_datapath; 
	gbt_datapath_cnt_o : out std_logic_vector(15 downto 0)
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
	-- ttc mode 
	signal s_ttc_mode : t_mid_mode := (continuous => '0', 
	                                   triggered  => '0', 
									   triggered_data => (others => '0'));
	-- payloads 
	signal s_payload        : t_mid_pload; 
	signal s_payloadID	    : std_logic_vector(3 downto 0);   
	signal s_payload_empty	: std_logic_vector(1 downto 0);                 
	signal s_payload_rdreq	: std_logic_vector(1 downto 0);   

	-- packets
	signal s_packet         : t_mid_pkt_array(1 downto 0);
	signal s_packet_rdreq 	: std_logic_vector(1 downto 0); 
	signal s_packet_active 	: std_logic_vector(9 downto 0);  

	-- e-links 
	signal s_missing_event_cnt : std_logic_vector(11 downto 0); 

	-- pulses 
	signal s_sox_pulse	: std_logic := '0';
	signal s_sel_pulse	: std_logic := '0'; 

	-- gbt access  
	signal s_gbt_access_req : std_logic;
	
	-- gbt datapath
	signal s_gbt_datapath     : t_mid_gbt_datapath;
	signal s_gbt_datapath_cnt : std_logic_vector(15 downto 0);
	
	-- avalon gbt monitor 
	signal s_cnt_monit    : unsigned(15 downto 0) := (others => '0');
	signal s_fsm_monit    : std_logic_vector(3 downto 0);

begin
	--=============================================================================
	-- Begin of p_enable_gbt
	-- This process enables and disables the transfer of trigger information to the 
	-- rest of the GBT user logic. No information is sent if the GBT link is down 
	-- That means : no RDH and no packets will be transmitted to the DWrappers
	--=============================================================================
	p_enable_gbt: process(clk_240)
	begin
	 if rising_edge(clk_240) then
	  if mid_rx_bus_i.en = '1' then 
	   s_sox_pulse <= ttc_sox_pulse_i;  -- ttc sox trigger pulse
	   s_sel_pulse <= ttc_sel_pulse_i;  -- ttc heartbeat frame sel
	   s_ttc_mode  <= ttc_mode_i;       -- ttc readout mode selection
	  end if;
	 end if;
	end process p_enable_gbt;	

	--============--
	-- PACKETIZER --
	--============--
	packetizer_inst: packetizer
	generic map (g_NUM_HBFRAME_SYNC => g_NUM_HBFRAME_SYNC, g_LINK_ID => g_LINK_ID)
	port map  (
	clk_240            => clk_240,	
	--	
	reset_i            => reset_i,	
	--
	sox_pulse_i        => s_sox_pulse,
	sel_pulse_i        => s_sel_pulse,
	--
	ttc_mode_i         => s_ttc_mode,
	--
	gbt_data_i         => mid_rx_bus_i.data,	
	gbt_val_i          => mid_rx_bus_i.valid,	
	--
	missing_event_cnt_o=> s_missing_event_cnt,								
	--
	packet_o           => s_packet,													
	packet_rdreq_i     => s_packet_rdreq,
	packet_active_o    => s_packet_active,
	-- 
	payload_o          => s_payload,
	payloadID_o        => s_payloadID,
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
	payload_rdreq_o     => s_payload_rdreq,
	--
	dw_packet_cnt_i     => dw_packet_cnt_i,
	--
	header_rdreq_i      => header_rdreq_i,
	--
	gbt_access_ack_i    => gbt_access_ack_i,
	gbt_access_req_o    => s_gbt_access_req,
	--
	gbt_datapath_o      => s_gbt_datapath,
	gbt_datapath_cnt_o  => s_gbt_datapath_cnt,
	--
	fsm_monit_o         => s_fsm_monit);  
    
	--=============================================================================
	-- Begin of p_cnt_monit
	-- This process is used to count the number of packet transmitted to the dwrapper
	--=============================================================================
	p_av_monit_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_cnt_monit <= (others => '0');
	  else
	   if s_cnt_monit = x"FFFF" then            
		s_cnt_monit <= (others => '0');      -- reset
	   elsif s_gbt_datapath.valid = '1' then
		s_cnt_monit <= s_cnt_monit+1;        -- increment
	   end if;
	  end if;
	 end if;
	end process p_av_monit_cnt;
   
    -- outputs 
	av_gbt_monit_o(31 downto 0)  <= std_logic_vector(s_cnt_monit) & s_missing_event_cnt & s_fsm_monit;  -- 16+12+4 = 32
	av_gbt_monit_o(63 downto 32) <= s_payloadID & std_logic_vector(to_unsigned(g_LINK_ID mod 2,4)) & "00" & s_packet_active & "000" & s_payload_empty(1) & "000" & s_payload_empty(0) & x"0"; -- 4+4+2+10+2+2+8 = 32
 
	gbt_access_req_o    <= s_gbt_access_req;   -- gbt access request
	gbt_datapath_o	    <= s_gbt_datapath;     -- gbt datapath
	gbt_datapath_cnt_o  <= s_gbt_datapath_cnt; -- gbt datapath counter
	 
	
end rtl;
--===========================================================================--
-- architecture end
--============================================================================--