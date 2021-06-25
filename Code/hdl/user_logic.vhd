-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : user_logic.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-01-30
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'02'
-- Version   : 2.0
-------------------------------------------------------------------------------
-- last changes:
-- <09/06/2020> update the memory sizes
-- <19/08/2020> optimize the design
-- <23/09/2020> add GBT uplink port connections 
-- <05/12/2020> fix the bugs and reset the system at the begining of each run
-- <18/12/2020> synchronize the timeframes
-- <13/02/2021> add avalon 
-- <21/02/2021> --
-------------------------------------------------------------------------------
-- TODO:  
-- # test the current UL in triggered mode 
-- # test the code in the cavern in both continuous and triggered mode
-------------------------------------------------------------------------------
-- Description:
-- This code below is the user logic firmware of the MID detector. 
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
--Entity declaration for user_logic
--=============================================================================
entity user_logic is
	generic (g_NUM_GBT_LINKS : integer := 24; g_RAM_WIDTH : integer := 13); -- maximum gbt links
	port (
	---------------------------------------------------------------------------
	mms_clk     : in  std_logic;
	mms_reset   : in  std_logic;
	mms_waitreq : out std_logic ;
	mms_addr    : in  std_logic_vector(23 downto 0);
	mms_wr      : in  std_logic;
	mms_wrdata  : in  std_logic_vector(31 downto 0);
	mms_rd      : in  std_logic;
	mms_rdval   : out std_logic;
	mms_rddata  : out std_logic_vector(31 downto 0);
	---------------------------------------------------------------------------
	ttc_rxclk   : in  std_logic;
	ttc_rxrst   : in  std_logic;
	ttc_rxready : in  std_logic;
	ttc_rxvalid : in  std_logic;
	ttc_rxd     : in  std_logic_vector(199 downto 0);
	---------------------------------------------------------------------------
	BlueGreenRed_LED_1 : out std_logic_vector(0 to 2);
	BlueGreenRed_LED_2 : out std_logic_vector(0 to 2);
	BlueGreenRed_LED_3 : out std_logic_vector(0 to 2);
	BlueGreenRed_LED_4 : out std_logic_vector(0 to 2);
	---------------------------------------------------------------------------
	gbt_rx_ready_i  : in  std_logic_vector(g_NUM_GBT_LINKS-1 downto 0);
	gbt_rx_bus_i    : in  t_cru_gbt_array(g_NUM_GBT_LINKS-1 downto 0);
	---------------------------------------------------------------------------
	GBT_TX_READY    : in  std_logic_vector(g_NUM_GBT_LINKS-1 downto 0);
	GBT_TX_BUS      : out t_cru_gbt_array(g_NUM_GBT_LINKS-1 downto 0);
	---------------------------------------------------------------------------
	fclk0  : out std_logic;
	fval0  : out std_logic;
	fsop0  : out std_logic;
	feop0  : out std_logic;
	fd0    : out std_logic_vector(255 downto 0);
	afull0 : in std_logic;
	---------------------------------------------------------------------------
	fclk1  : out std_logic;
	fval1  : out std_logic;
	fsop1  : out std_logic;
	feop1  : out std_logic;
	fd1    : out std_logic_vector(255 downto 0);
	afull1 : in std_logic
	 ---------------------------------------------------------------------------
    );
end entity user_logic;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of user_logic is
	-- ========================================================
	-- constant declarations
	-- ========================================================
        constant c_NUM_GBT_USED     : integer := 16;  -- number of gbt links used for the MID readout chain (16 by default ) 
	constant c_NUM_HBFRAME      : integer := 256; -- number of HBFs collected during a single TF (256 HBF by default)  
	constant c_NUM_HBFRAME_SYNC : integer := 128; -- number of HBFs collected before synchronization of all gbt frames (128 HBF by default)
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- timing & trigger control register 
	signal s_ttc_data  : t_mid_ttc; 
        signal s_ttc_pulse : t_mid_pulse;
	signal s_ttc_mode  : t_mid_mode;

	-- gbt data input bus
	signal s_mid_rx_bus : t_mid_gbt_array(c_NUM_GBT_USED-1 downto 0);    -- 16 gbt links

	-- avalon monitor 
	signal s_av_gbt_monit : Array64bit(c_NUM_GBT_USED-1 downto 0);       -- avalon registers from 16 gbt links 
	signal s_av_dw_monit  : Array32bit(1 downto 0);                      -- avalon registers from 2 EPNs 
	signal s_av_trg_monit : std_logic_vector(31 downto 0);               -- avalon register from TTC 
	signal s_av_cruid_config : std_logic;                                -- avalon register to config the cruid

	-- reset 
	signal s_av_reset     : std_logic := '0';                            -- avalon reset 
	signal hard_reset     : std_logic := '0';                            -- hard reset 
	signal soft_reset     : std_logic := '0';                            -- soft reset
	signal s_reset        : std_logic := '0';                            -- (hard reset OR soft reset)
	
	-- datapath access
	signal s_dw_datapath : t_mid_dw_datapath_array(1 downto 0);          -- 2 CRU end-points
	
	
begin
	--=============================================================================
    -- Begin of p_hard_reset
    -- This process creates synchrounous trailing edge hard reset
    --=============================================================================
    p_hard_reset: process(s_av_reset, clk_240)
	 variable ff : std_logic := '0';
    begin 
	 if s_av_reset = '1' then 
       ff := '1';
	   hard_reset <= '1';
      elsif rising_edge(clk_240) then 
       hard_reset <= ff;
	   ff := '0';
     end if; 
    end process p_hard_reset;

	-- hard reset OR soft reset 
	s_reset <= hard_reset or soft_reset;

	--=============--
	-- ttc_ulogic -- 
	--=============--
        ttc_ulogic_inst: ttc_ulogic
	generic map(g_NUM_HBFRAME      => c_NUM_HBFRAME,      -- number of HBFs collected during a single TF 
	            g_NUM_HBFRAME_SYNC => c_NUM_HBFRAME_SYNC) -- number of HBFs collected before synchronization of all gbt links used for MID
	port map (
	clk_240	           => ttc_rxclk, 
	hard_reset         => hard_reset,
	soft_reset         => soft_reset, 
	ttc_rxd_i          => ttc_rxd,
	ttc_rxready_i      => ttc_rxready,
    ttc_rxvalid_i      => ttc_rxvalid,   
	ttc_data_o         => s_ttc_data,
	ttc_mode_o         => s_ttc_mode,  
	ttc_pulse_o        => s_ttc_pulse,  
    av_trg_monit_o     => s_av_trg_monit
       );  
	--===================--
	-- gbt_ulogic_select -- 
	--===================--
	gbt_ulogic_select_inst: gbt_ulogic_select
	generic map (g_NUM_GBT_INPUT  => g_NUM_GBT_LINKS,     -- total number of cru gbt link ports available (24 links max)
                     g_NUM_GBT_OUTPUT => c_NUM_GBT_USED)      -- total number of cru gbt link ports used for MID   
	port map (
	gbt_rx_ready_i	=> gbt_rx_ready_i,
	gbt_rx_bus_i	=> gbt_rx_bus_i,
	mid_rx_bus_o	=> s_mid_rx_bus
	 ); 
	--================--
	-- gbt_ulogic_mux --
	--================--
	gbt_ulogic_mux_inst0: gbt_ulogic_mux
	generic map(g_DWRAPPER_ID => 0,                        -- ID of the CRU end-point 
                    g_HALF_NUM_GBT_USED => c_NUM_GBT_USED/2,   -- half the number of cru gbt links used for MID (8 links max)
		    g_NUM_HBFRAME_SYNC  => c_NUM_HBFRAME_SYNC) -- number of HBFs collected before synchronization of all gbt links used for MID            
	port map(
	clk_240		  => ttc_rxclk,               
	reset_i	          => s_reset,
	afull_i 	  => afull0,		
	ttc_data_i	  => s_ttc_data,
	ttc_mode_i	  => s_ttc_mode,
	ttc_pulse_i       => s_ttc_pulse,
	mid_rx_bus_i      => s_mid_rx_bus(c_NUM_GBT_USED/2-1 downto 0),
	av_cruid_config_i => s_av_cruid_config,
	av_gbt_monit_o    => s_av_gbt_monit(c_NUM_GBT_USED/2-1 downto 0),
	av_dw_monit_o     => s_av_dw_monit(0),
	dw_datapath_o     => s_dw_datapath(0)
			);  
	--================--
	-- gbt_ulogic_mux --
	--================--
	gbt_ulogic_mux_inst1: gbt_ulogic_mux
	generic map(g_DWRAPPER_ID => 1,                        -- ID of the CRU end-point 
                    g_HALF_NUM_GBT_USED => c_NUM_GBT_USED/2,   -- half the number of cru gbt link used for MID (8 links max) 
	            g_NUM_HBFRAME_SYNC  => c_NUM_HBFRAME_SYNC) -- number of HBFs collected before synchronization of all gbt links used for MID 
	port map(
	clk_240		  => ttc_rxclk,               
	reset_i           => s_reset,
	afull_i 	  => afull1,			
	ttc_data_i	  => s_ttc_data,
	ttc_mode_i	  => s_ttc_mode,
	ttc_pulse_i       => s_ttc_pulse,
	mid_rx_bus_i      => s_mid_rx_bus(c_NUM_GBT_USED-1 downto c_NUM_GBT_USED/2),
	av_cruid_config_i => s_av_cruid_config,
	av_gbt_monit_o    => s_av_gbt_monit(c_NUM_GBT_USED-1 downto c_NUM_GBT_USED/2),
	av_dw_monit_o     => s_av_dw_monit(1),
	dw_datapath_o     => s_dw_datapath(1)
			);  
	--===============--
	-- avalon_ulogic --
	--===============--
	AVL: avalon_ulogic
	generic map(g_NUM_GBT_USED => c_NUM_GBT_USED)         -- number of cru gbt link used for MID             
	port map (
	mms_clk 	=> mms_clk,
	mms_reset 	=> mms_reset,
	mms_waitreq     => mms_waitreq,
	mms_addr	=> mms_addr,
	mms_wr		=> mms_wr,
	mms_wrdata	=> mms_wrdata,
	mms_rd		=> mms_rd,
	mms_rdval	=> mms_rdval,
	mms_rddata	=> mms_rddata,
	-- reset
	reset		=> s_av_reset,
	cruid           => s_av_cruid_config,
	-- monitors
	trg_monit       => s_av_trg_monit,   
    gbt_monit       => s_av_gbt_monit, 
	dw_monit        => s_av_dw_monit
		);

	-- define leds
	BlueGreenRed_LED_1 <=not("100"); -- blue (active low)
	BlueGreenRed_LED_2 <=not("010"); -- green (active low)
	BlueGreenRed_LED_3 <=not("001"); -- red (active low)
	BlueGreenRed_LED_4 <=not("101"); -- blue + red (active low)
	
	-- define d-wrappers clock
	fclk0 <= ttc_rxclk;
	fclk1 <= ttc_rxclk;
	
	-- D-Wrappers 
	fval0 <= s_dw_datapath(0).valid;
	fsop0 <= s_dw_datapath(0).sop;
	feop0 <= s_dw_datapath(0).eop;
	fd0   <= s_dw_datapath(0).data;
	-- 
	fval1 <= s_dw_datapath(1).valid;
	fsop1 <= s_dw_datapath(1).sop;
	feop1 <= s_dw_datapath(1).eop;
	fd1   <= s_dw_datapath(1).data;
	-----------------------------------------------------------------------------
	-- FAKE DATA GENERATOR for GBT TX 
	-- (temp test feature, only constant pattern : STREAM)
	-----------------------------------------------------------------------------
	gen_stream : for i in 0 to g_NUM_GBT_LINKS-1 generate
	 gen_char : for j in 0 to 96/4-1 generate
	  GBT_TX_BUS(i).data((j+1)*4-1 downto j*4) <= std_logic_vector(to_unsigned(i+1,4)); 
	 end generate;

	 GBT_TX_BUS(i).data(111 downto 96) <= x"CAFE" when i>=g_NUM_GBT_LINKS/2 else x"BEEF";
	 GBT_TX_BUS(i).icec         <= "0000";
	 GBT_TX_BUS(i).data_valid   <= TTC_RXVALID; -- to synchronse all valids (GBT fails otherwise)
	 GBT_TX_BUS(i).is_data_sel  <= '0';         -- we simulate simple STREAM mode only
	end generate;

end architecture rtl;
--=============================================================================
-- architecture end
--=============================================================================