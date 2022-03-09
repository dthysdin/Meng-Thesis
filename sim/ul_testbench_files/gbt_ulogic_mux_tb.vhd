-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: gbt_ulogic_mux_tb.vhd
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
--Entity declaration for gbt_ulogic_mux_tb
--=============================================================================
entity gbt_ulogic_mux_tb is
end entity gbt_ulogic_mux_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of gbt_ulogic_mux_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer := 1;
	constant g_WRITE_TO_FILE: integer := 1;
	constant g_FILE_NAME : string(21 downto 1) := "gbt_ulogic_mux_x0.txt";
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

	-- gbt_ulogic mux 
	signal mid_rx_bus_i   : t_mid_gbt_array(g_NUM_GBT_USED-1 downto 0);
	signal av_trg_monit_o : std_logic_vector(31 downto 0);
	signal av_gbt_monit_o : Array64bit(g_NUM_GBT_USED-1 downto 0);	
	signal av_dw_monit_o  : std_logic_vector(31 downto 0);		
	signal dw_datapath_o  : t_mid_dw_datapath;
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
	clk_100 		: out  std_logic;
	clk_240 		: out  std_logic; 
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
	-- reset 
	s_reset <= reset_p and sync_reset;
	--============================================================
	-- clock generator 
	--============================================================
	clk: clk_gen
	generic map (g_NUM_GBT_USED => g_NUM_GBT_USED)
	port map (
	activate_ttc	=> activate_ttc,	--: in std_logic; -- ttc
	activate_sim	=> activate_sim,	--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,	--: in std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	-- 
	reset_p			=> reset_p,			--: in std_logic;
	--
	clk_40 			=> clk_40,			--: out  std_logic;
	clk_100 		=> clk_100,		--: out  std_logic;
	clk_240 		=> clk_240,		--: out  std_logic; 
	--
	gbt_valid		=> gbt_valid,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel			=> gbt_sel,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready		=> gbt_ready,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	--
	ttc_valid		=> ttc_valid,		--: out std_logic;
	ttc_ready		=> ttc_ready		--: out std_logic	
	    );
		 
	-- gbt enable 
	GBT_gen: for i in 0 to g_NUM_GBT_USED-1 generate 

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
		data			=> gbt_data(79+80*i downto 80*i)
	    ); 

		gbt_en(i) <= gbt_ready(i) and gbt_sel(i);
		mid_rx_bus_i(i).en 		<= gbt_en(i);
		mid_rx_bus_i(i).valid	<= gbt_valid(i);
		mid_rx_bus_i(i).data	<= gbt_data(79+80*i downto i*80);
	end generate;
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
    av_trg_monit_o     => av_trg_monit_o,     --: out std_logic_vector(31 downto 0);
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
	DUT: entity work.gbt_ulogic_mux 
	generic map (g_DWRAPPER_ID => 0, 
	             g_HALF_NUM_GBT_USED => g_NUM_GBT_USED,
				 g_TIMEFRAME => 3)
	port map (
	-----------------------------------------------------------------------
	clk_240		   => clk_240,        --: in std_logic;
	reset_i	       => s_reset,        --: in std_logic;													
	afull_i 	   => '0',            --: in std_logic;			
	ttc_data_i     => ttc_txdata,     --: in t_mid_ttc; 
	ttc_mode_i     => ttc_mode,       --: in t_mid_mode;
    ttc_pulse_i    => ttc_pulse,      --: in t_mid_pulse;	
	mid_rx_bus_i   => mid_rx_bus_i,   --: in t_mid_gbt_array(g_HALF_NUM_GBT_USED-1 downto 0);
	av_gbt_monit_o => av_gbt_monit_o, --: out Array64bit(g_HALF_NUM_GBT_USED-1 downto 0);	
	av_dw_monit_o  => av_dw_monit_o,  --: out std_logic_vector(31 downto 0);		
	dw_datapath_o  => dw_datapath_o    --: out t_mid_dw_datapath														
	------------------------------------------------------------------------
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
		wait;
	end process;
	--============================================================
	-- p_write 
	--============================================================
	p_write : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable string_gap : string(4 downto 1) := "    ";
	begin
		wait until rising_edge(clk_240);
		-- simulation active 
		-- gbt link up 
		-- ttc link up
		if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
			if dw_datapath_o.valid = '1'  then
				hwrite(my_line, dw_datapath_o.data);
				-- sop
				if dw_datapath_o.sop = '1'  then
				 write(my_line, string'(" SOP"));
				else 
				write(my_line, string_gap);
				end if;
				-- eop
				if dw_datapath_o.eop = '1'  then
				 write(my_line, string'(" EOP"));
				else 
				 write(my_line, string_gap);
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================