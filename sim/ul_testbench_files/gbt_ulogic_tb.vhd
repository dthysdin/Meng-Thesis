-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: gbt_ulogic.vhd
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
--Entity declaration for gbt_ulogic_tb
--=============================================================================
entity gbt_ulogic_tb is
end entity gbt_ulogic_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of gbt_ulogic_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer := 1;
	constant g_WRITE_TO_FILE: integer := 1;
	constant g_FILE_NAME : string(17 downto 1) := "gbt_ulogic_x0.txt";
	-- ========================================================
	-- signal declarations of the design under test
	-- ========================================================
	-- clock signals 
	signal clk_240	: std_logic := '0';
	signal clk_40	: std_logic := '0';
	signal clk_100	: std_logic := '0';
	-- reset 
	signal reset_p : std_logic;
	signal sync_reset : std_logic;
	signal s_reset : std_logic;
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
    
	signal ttc_txdata    : t_mid_ttc;
	signal ttc_pulse     : t_mid_pulse;
	signal ttc_mode      : t_mid_mode;
	-- gbt datapath 
	signal mid_rx_bus			: t_mid_gbt;
	signal gbt_access_ack		: std_logic;
	signal gbt_access_req		: std_logic;
	signal gbt_datapath_done_o	: std_logic;	
	signal gbt_datapath_o		: t_mid_datapath;
	
    -- avalon 
	signal av_trg_monit   : std_logic_vector(31 downto 0);
	signal av_gbt_monit   : std_logic_vector(31 downto 0);
    --=======================================================--
	-- component declaration 
	--=======================================================--
	component clk_gen is 
	generic (g_NUM_GBT_USED : natural := 1);
	port (
	-------------------------------------------------------------------
	activate_ttc: in std_logic; -- ttc
	activate_sim: in std_logic; -- sim  
	activate_gbt: in std_logic; -- gbt
	reset_p		: in std_logic;
	clk_40 		: out  std_logic;
	clk_100 	: out  std_logic;
	clk_240 	: out  std_logic; 
	gbt_valid	: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel		: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready	: out std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	ttc_valid	: out std_logic;
	ttc_ready	: out std_logic
	-------------------------------------------------------------------
	 );  
	end component clk_gen;
	
	component read_ttc_tb is
	generic (g_FILE_NAME    : string(23 downto 1) := "file_in/sim_ttc_pon.txt");
	port (
	-------------------------------------------------------------------
	activate_sim : in std_logic;
	activate_ttc : in std_logic;
	clk_40       : in std_logic; 
	data         : out std_logic_vector(199 downto 0) 
	-------------------------------------------------------------------
	 );  
	end component read_ttc_tb;	
	
	component read_gbt_sim is
	generic (g_FILE_NAME    : string(26 downto 1) := "file_in/sim_gbt_dataX0.txt");
	port (
	-------------------------------------------------------------------
    activate_sim : in std_logic;
	activate_gbt : in std_logic;
	activate_ttc : in std_logic;
	clk_40       : in std_logic; -- 40 MHz 
	daq_start    : in std_logic;
	data         : out std_logic_vector(79 downto 0)	
	-------------------------------------------------------------------
	 );  
	end component read_gbt_sim;
	
begin 
    
	--============================================================
	-- clock generator 
	--============================================================
	clk: clk_gen
	generic map (g_NUM_GBT_USED => 1)
	port map (
	activate_ttc	=> activate_ttc,	--: in std_logic; -- ttc
	activate_sim	=> activate_sim,	--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,	--: in std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	-- 
	reset_p			=> reset_p,			--: in std_logic;
	--
	clk_40 			=>	clk_40,			--: out  std_logic;
	clk_100 		=>	clk_100,		--: out  std_logic;
	clk_240 		=>	clk_240,		--: out  std_logic; 
	--
	gbt_valid		=>	gbt_valid,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel			=>	gbt_sel,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready		=> gbt_ready,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	--
	ttc_valid		=> ttc_valid,		--: out std_logic;
	ttc_ready		=> ttc_ready		--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	 
	read_gbt: read_gbt_sim
	generic map (g_FILE_NAME => "file_in/sim_gbt_dataX0.txt")
	port map (
	activate_sim	=> activate_sim, 		--: in std_logic;
	activate_gbt	=> activate_gbt, 		--: in std_logic; 
	activate_ttc	=> activate_ttc, 		--: in std_logic;
	clk_40			=> clk_40,				--: in std_logic; -- 40 MHz
    daq_start       => ttc_pulse.sox,	    --: in std_logic;
	data			=> gbt_data				--: out std_logic_vector(79 downto 0) 
	    ); 
		 
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	mid_rx_bus.en <= gbt_en(0);
	mid_rx_bus.valid <= gbt_valid(0);
	mid_rx_bus.data	<= gbt_data;
	--============================================================
	-- read TTC data 
	--============================================================
	read_ttc: read_ttc_tb 
	generic map (g_FILE_NAME  => "file_in/sim_ttc_pon.txt")
	port map (
	activate_sim 	=> activate_sim,			--: in std_logic;
	activate_ttc  	=> activate_ttc,			--: in std_logic;
	clk_40     		=> clk_40,					--: in std_logic; -- 40 MHz 
	data       		=> ttc_data					--: out std_logic_vector(199 downto 0)
	);
	--============================================================
	-- TTC info
	--============================================================
	mid_ttc: ttc_ulogic 
	generic map (g_TIMEFRAME => 3)
	port map (
	clk_240	           => clk_240,          --: in std_logic
	av_reset_i         => reset_p,          --: in std_logic
    av_trg_monit_o     => av_trg_monit,     --: out std_logic_vector(31 downto 0);
    sync_reset_o       => sync_reset,       --: out std_logic;   

	ttc_rxd_i          => ttc_data,          --: in std_logic_vector(199 downto 0);
    ttc_rxvalid_i      => ttc_valid,        --: in std_logic;   
    ttc_rxready_i      => ttc_ready,              --: in std_logic;  

	ttc_data_o         => ttc_txdata,         --: out t_mid_ttc;
    ttc_mode_o         => ttc_mode,         --: out t_mid_mode;
    ttc_pulse_o        => ttc_pulse         --: out t_mid_pulse
       ); 
	--============================================================
	-- DUT
	--============================================================
	DUT: gbt_ulogic
	generic map (g_LINK_ID => 7, g_DWRAPPER_ID => 1, g_TIMEFRAME => 3)
	port map (
	-----------------------------------------------------------------------

	clk_240             => clk_240,         --: in std_logic;	
	--	
	reset_i             => s_reset,         --: in std_logic;
	--							
	ttc_data_i          => ttc_txdata,     --: in t_mid_ttc;
	ttc_mode_i          => ttc_mode,        --: out t_mid_mode;
    ttc_pulse_i         => ttc_pulse,        --: out t_mid_pulse
	--
	mid_rx_bus_i        => mid_rx_bus,      --: in t_mid_gbt;
	--		 
	av_gbt_monit_o      => av_gbt_monit,    --: out std_logic_vector(31 downto 0);
	--
	gbt_access_ack_i    => gbt_access_ack,  --: in  std_logic;		
	gbt_access_req_o    => gbt_access_req,  --: out std_logic;
	--		
	gbt_datapath_o      => gbt_datapath_o,      --: out t_mid_datapath; 
	gbt_datapath_done_o => gbt_datapath_done_o  --: out std_logic

				);  
	--============================================================
	-- register for  TTC 
	--============================================================
	p_ttc: process
	begin 
		wait until rising_edge(clk_240);
		if gbt_access_req = '1' then  
		 gbt_access_ack <= '1';
		else
		 gbt_access_ack <= '0';
		end if;
	end process;
	--============================================================
	-- register for reset
	--============================================================
	p_reset: process
	begin 
		wait until rising_edge(clk_240);
	    s_reset <= reset_p or sync_reset;
	end process;

	
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
		wait;
	end process;
	--============================================================
	-- p_write 
	--============================================================
	p_write : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
	begin
		wait until rising_edge(clk_240);
		-- simulation active 
		-- gbt link up 
		-- ttc link up
		if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
			if gbt_datapath_o.valid = '1'  then
				hwrite(my_line, gbt_datapath_o.data);
				-- sop
				if gbt_datapath_o.sop = '1'  then
				write(my_line, string'(" SOP"));
				else 
				write(my_line, string'("    "));
				end if;
				-- eop
				if gbt_datapath_o.eop = '1'  then
				write(my_line, string'(" EOP"));
				else 
				write(my_line, string'("     "));
				end if;
				-- done
				if gbt_datapath_done_o = '1'  then
				write(my_line, string'(" DONE"));
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================