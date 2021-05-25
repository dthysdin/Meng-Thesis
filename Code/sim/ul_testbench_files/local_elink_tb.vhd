-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: elink_mux.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- This module test the functionality of the regional control module
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for local_elink_tb
--=============================================================================
entity local_elink_tb is
end entity local_elink_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of local_elink_tb is
	-- ========================================================
	-- type declarations
	-- ========================================================
	type t_string_in is array (natural range <>) of string(27 downto 1);
	type t_string_out is array (natural range <>) of string(32 downto 1);
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer range 1 to 16:= 1;
	constant g_WRITE_TO_FILE: integer range 0 to 1 := 1;  -- 1 = YES -- 0 = NO
	constant g_REGIONAL_ID	: integer range 0 to 1 := 0;  -- 1 = REGIONAL HIGH  -- 0 = REGIONAL LOW
	-- ========================================================
	-- signal declarations of the design under test
	-- ========================================================
	-- clock signals 
	signal clk_240	: std_logic := '0';
	signal clk_40	: std_logic := '0';
	-- reset 
	signal reset_p : std_logic;
	-- activate 
	signal activate_sim : std_logic := '0';
	signal activate_gbt : std_logic := '0';
	signal activate_ttc : std_logic := '0';
	-- gbt data 
	signal gbt_data : std_logic_vector(g_NUM_GBT_USED*80-1 downto 0);
	signal gbt_valid: std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_sel: 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_ready:	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_en : 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	-- ttc 
	signal ttc_ready	: std_logic; 
	signal ttc_valid	: std_logic; 
	signal ttc_data	: std_logic_vector(199 downto 0);
	signal trg_rx: t_mid_trginfo; -- (SOC,EOC,PHY,SOT,EOT)
	signal bcid_rx		: std_logic_vector(15 downto 0);
	-- elink mux 
	signal crateID_o	: std_logic_vector(3 downto 0);
	--
	signal packet_full_i: std_logic; 
	signal mux_val_o	: std_logic;
	signal mux_stop_o	: std_logic;
	signal mux_empty_o	: std_logic;
	signal mux_data_o	: std_logic_vector(7 downto 0);
	
	signal frame_val : std_logic;
	signal frame_data: std_logic_vector(167 downto 0);
	
begin 
	--============================================================
	-- clock generator 
	--============================================================
	clk: entity work.clk_gen
	generic map (g_NUM_GBT_USED => g_NUM_GBT_USED)
	port map (
	activate_ttc	=> activate_ttc,	--: in std_logic; -- ttc
	activate_sim	=> activate_sim,	--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,	--: in std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	-- 
	reset_p			=> reset_p,			--: in std_logic;
	--
	clk_40 			=> clk_40,			--: out  std_logic;
	clk_100 		=> open,			--: out  std_logic;
	clk_240 		=> clk_240,			--: out  std_logic; 
	--
	gbt_valid		=> gbt_valid,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel			=> gbt_sel,			--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready		=> gbt_ready,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	--
	ttc_valid		=> ttc_valid,		--: out std_logic;
	ttc_ready		=> ttc_ready		--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	 
	read_gbt: entity work.read_gbt_sim
	generic map (g_FILE_NAME => "file_in/sim_gbt_dataX0.txt")
	port map (
	activate_sim	=> activate_sim, 		--: in std_logic;
	activate_gbt	=> activate_gbt, 		--: in std_logic;
	clk_40			=> clk_40,				--: in std_logic; -- 40 MHz 
	data			=> gbt_data				--: out std_logic_vector(79 downto 0)
	    ); 
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	--============================================================
	-- read TTC data 
	--============================================================
	read_ttc: entity work.read_ttc_tb 
	generic map (g_FILE_NAME  => "file_in/sim_ttc_pon.txt")
	port map (
	activate_sim 	=> activate_sim,			--: in std_logic;
	activate_ttc  	=> activate_ttc,			--: in std_logic;
	clk_40     		=> clk_40,					--: in std_logic; -- 40 MHz 
	data       		=> ttc_data					--: out std_logic_vector(199 downto 0)
	);
	--============================================================
	-- DUT 
	--============================================================
	DUT: entity work.local_elink
	port map (
	-------------------------------------------------------------------
	clk_240        => clk_240,      --: in std_logic;				           
	reset_i        => reset_p,      --: in std_logic;
    --
	daq_stop_i     => daq_stop_i,   --: in std_logic;
	daq_start_i    => daq_start_i,  --: in std_logic;
	daq_valid_i    => daq_valid_i,  --: in std_logic;	
	daq_resume_i   => daq_resume_i, --: in std_logic;
	-- 
	orb_pause_o    => --: out std_logic;
	eox_pause_o    => --: out std_logic;
    --	
	mid_rx_en_i    => --: in std_logic;								
	mid_rx_data_i  => --: in std_logic_vector(7 downto 0);		
	mid_rx_valid_i => --: in std_logic;									
    --
	ttc_bcid_i 	   => --: in std_logic_vector(15 downto 0);		 										 
	ttc_trigger_i  => --: in t_mid_trginfo;							
    ---
	loc_rdreq_i	   => --: in std_logic;
	--	
	loc_val_o	   => --: out std_logic;								 
	loc_data_o	   => --: out std_logic_vector(167 downto 0);	 								 
	loc_empty_o	   => --: out std_logic;								 								
	loc_active_o   => --: out std_logic;								 
	loc_inactive_o => --: out std_logic                         
	 );   
	--============================================================
	-- register for  TTC 
	--============================================================
	p_ttc: process
	begin 
		wait until rising_edge(clk_240);
		if ttc_valid = '1' and ttc_ready = '1' and ttc_data(119) = '1' then  
			-- (SOC,EOC,PHY,SOT,EOT)
			trg_rx.soc <= ttc_data(9); -- soc
			trg_rx.eoc <= ttc_data(10);-- eoc
			trg_rx.phy <= ttc_data(4); -- phy
			trg_rx.sot <= ttc_data(7); -- sot
			trg_rx.eot <= ttc_data(8); -- eot
			-- BC 
			bcid_rx <= x"0" & ttc_data(43 downto 32);
		end if;
	end process;
	--============================================================
	-- frame encoder 
	--============================================================
	encoder: entity work.frame_encoder_tb
	port map (
	clk_240				=> clk_240,			--: in std_logic;							      
	reset_p				=> reset_p,			--: in std_logic;							  
	--
	mux_val_i			=> mux_val_o,		--: in std_logic;							
	mux_data_i			=> mux_data_o,		--: in std_logic_vector(7 downto 0);		
	--
	frame_val_o	        => frame_val,	    --: out std_logic;
	frame_data_o	    => frame_data       --: out std_logic_vector(167 downto 0)	
	 );  

	--============================================================
	-- stimulus 
	--============================================================
	p_stimulus: process
	begin 
		-- initial 
		wait for 0 ps;
		activate_sim <= '1';
		activate_ttc <= '0';
		activate_gbt <= '0';
		reset_p <= '1';
		wait for 47000 ps;
		reset_p <= '0';
		wait until rising_edge(clk_240);
		-- activate ttc readout 
		activate_ttc <= '1'; 
		-- activate gtb readout
		activate_gbt <= '1';

		wait until rising_edge(clk_40);
		wait;
	end process;
	--============================================================
	-- write to file  
	--============================================================
	WR_GEN: if g_WRITE_TO_FILE = 1 generate 
		
		WR: entity work.write_elink_mux_tb
		generic map (g_FILE_NAME => "file_out/elink_mux_00.txt")
		port map (
		clk_240			=> clk_240, 				--: in std_logic;
		activate_sim	=> activate_sim,			--: in std_logic;
		activate_gbt	=> activate_gbt,			--: in std_logic;
		activate_ttc	=> activate_ttc,			--: in std_logic;
		frame_val	    => frame_val,			    --: in std_logic;
		frame_stop      => mux_stop_o,				--: in std_logic;
		frame_data      => frame_data			    --: in std_logic_vector(167 downto 0)
	    );
	end generate; 

end architecture;
--=============================================================================
-- architecture end
--=============================================================================
	