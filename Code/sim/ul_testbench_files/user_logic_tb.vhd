-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File			: user_logic_tb.vhd
-- Author		: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company		: NRF iThemba LABS
-- Created   	: 2020-01-30
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version		: 0.7
-------------------------------------------------------------------------------
-- last changes: <24/08/2020> 
-- Reasons		:  
-------------------------------------------------------------------------------
-- TODO: 
--  
-------------------------------------------------------------------------------
-- Description:
-- <none>
-------------------------------------------------------------------------------
-- Copyright (c) 2018
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
--Entity declaration for user_logic_tb
--=============================================================================
entity user_logic_tb is
end entity user_logic_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of user_logic_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_INPUT: integer := 24;
	constant g_NUM_GBT_USED	: integer := 16;
	constant g_FILE_EPN1 : string(35 downto 1) := "ul_output_files/user_logic_enp1.txt";
	constant g_FILE_EPN0 : string(35 downto 1) := "ul_output_files/user_logic_epn0.txt";
	-- ========================================================
	-- signal declarations of the design under test
	-- ========================================================
	-- clock signals 
	signal clk_40	: std_logic := '0';
	-- reset 
	signal reset_p : std_logic;
	signal daq_start : std_logic := '0'; -- start gbt 
	-- activate 
	signal activate_sim : std_logic := '0';
	signal activate_gbt : std_logic := '0';
	signal activate_ttc : std_logic := '0';
	-- gbt data 
	signal gbt_data : Array80bit(g_NUM_GBT_INPUT-1 downto 0);
	signal gbt_valid: std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	signal gbt_sel:   std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	signal gbt_ready: std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);

	-- user logic 
	signal mms_clk     : std_logic;
	signal mms_reset   : std_logic := '0';
	signal mms_waitreq : std_logic ;
	signal mms_addr    : std_logic_vector(23 downto 0) := (others => '0');
	signal mms_wr      : std_logic := '0';
	signal mms_wrdata  : std_logic_vector(31 downto 0) := (others => '0');
	signal mms_rd      : std_logic := '0';
	signal mms_rdval   : std_logic;
	signal mms_rddata  : std_logic_vector(31 downto 0);

	signal ttc_rxclk   : std_logic;
	signal ttc_rxready : std_logic;
	signal ttc_rxvalid : std_logic;
	signal ttc_rxd     : std_logic_vector(199 downto 0);

	signal BlueGreenRed_LED_1 : std_logic_vector(0 to 2);
	signal BlueGreenRed_LED_2 : std_logic_vector(0 to 2);
	signal BlueGreenRed_LED_3 : std_logic_vector(0 to 2);
	signal BlueGreenRed_LED_4 : std_logic_vector(0 to 2);

	signal gbt_rx_ready_i  : std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	signal gbt_rx_bus_i    : t_cru_gbt_array(g_NUM_GBT_INPUT-1 downto 0);
	signal GBT_TX_BUS      : t_cru_gbt_array(g_NUM_GBT_INPUT-1 downto 0);

	signal fclk0  : std_logic;
	signal fval0  : std_logic;
	signal fsop0  : std_logic;
	signal feop0  : std_logic;
	signal fd0    : std_logic_vector(255 downto 0);
	--signal afull0 : std_logic := '0';

	signal fclk1  : std_logic;
	signal fval1  : std_logic;
	signal fsop1  : std_logic;
	signal feop1  : std_logic;
	signal fd1    : std_logic_vector(255 downto 0);
	--signal afull1 : std_logic := '0';
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
	generic (g_FILE_NAME    : string(30 downto 1) := "ul_input_files/sim_ttc_pon.txt");
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
	generic (g_FILE_NAME    : string(33 downto 1) := "ul_input_files/sim_gbt_dataX0.txt");
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

	component user_logic is
	generic ( g_NUM_GBT_LINKS : integer := 24; g_RAM_WIDTH : integer := 13); -- maximum gbt links
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
	-- GBT downlink (CRU -> FE) (gbt mux synchronizes ticks)
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
	end component user_logic;
	
begin 
	--============================================================
	-- clock generator 
	--============================================================
	clk: clk_gen
	generic map (g_NUM_GBT_USED => g_NUM_GBT_INPUT)
	port map (
	activate_ttc	=> activate_ttc,	--: in std_logic; -- ttc
	activate_sim	=> activate_sim,	--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,	--: in std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	-- 
	reset_p			=> reset_p,			--: in std_logic;
	--
	clk_40 			=> clk_40,			--: out  std_logic;
	clk_100 		=> mms_clk,		    --: out  std_logic;
	clk_240 		=> ttc_rxclk,		--: out  std_logic; 
	--
	gbt_valid		=> gbt_valid,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel			=> gbt_sel,		    --: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready		=> gbt_ready,		--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	--
	ttc_valid		=> ttc_rxvalid,		--: out std_logic;
	ttc_ready		=> ttc_rxready		--: out std_logic	
	    );

	-- gbt enable 
	GBT_gen: for i in 0 to g_NUM_GBT_INPUT-1 generate 
		--============================================================
	    -- read GBT data 
	    --============================================================	 
		 read_gbt: read_gbt_sim
		 generic map (g_FILE_NAME => "ul_input_files/sim_gbt_dataX0.txt")
		 port map (
		 activate_sim	=> activate_sim, 		--: in std_logic;
		 activate_gbt	=> activate_gbt, 		--: in std_logic; 
		 activate_ttc	=> activate_ttc, 		--: in std_logic;
		 clk_40			=> clk_40,				--: in std_logic; 
    	 daq_start      => daq_start,	        --: in std_logic;
		 data			=> gbt_data(i)
	     ); 
 
	 gbt_rx_bus_i(i).data(79 downto 0) <= gbt_data(i);
	 gbt_rx_bus_i(i).data(111 downto 80) <= (others => '0');
	 gbt_rx_bus_i(i).icec  <= (others => '0');
	 gbt_rx_bus_i(i).data_valid  <= gbt_valid(i);
	 gbt_rx_bus_i(i).is_data_sel <= gbt_sel(i);
	 gbt_rx_ready_i(i) <= gbt_ready(i);
	end generate;
	
	--============================================================
	-- read TTC data 
	--============================================================
	read_ttc: read_ttc_tb 
	generic map (g_FILE_NAME  => "ul_input_files/sim_ttc_pon.txt")
	port map (
	activate_sim 	=> activate_sim,			--: in std_logic;
	activate_ttc  	=> activate_ttc,			--: in std_logic;
	clk_40     		=> clk_40,					--: in std_logic; -- 40 MHz 
	data       		=> ttc_rxd					--: out std_logic_vector(199 downto 0)
	);
	--============================================================
	-- DUT
	--============================================================  
	DUT: user_logic
	generic map( g_NUM_GBT_LINKS => g_NUM_GBT_INPUT, g_RAM_WIDTH => 13) -- maximum gbt links
	port map(
	---------------------------------------------------------------------------
	mms_clk     => mms_clk,         --: in  std_logic;
	mms_reset   => mms_reset,       --: in  std_logic;
	mms_waitreq => mms_waitreq,     --: out std_logic ;
	mms_addr    => mms_addr,        --: in  std_logic_vector(23 downto 0);
	mms_wr      => mms_wr,          --: in  std_logic;
	mms_wrdata  => mms_wrdata,      --: in  std_logic_vector(31 downto 0);
	mms_rd      => mms_rd,          --: in  std_logic;
	mms_rdval   => mms_rdval,       --: out std_logic;
	mms_rddata  => mms_rddata,      --: out std_logic_vector(31 downto 0);

	ttc_rxclk   => ttc_rxclk,       --: in  std_logic;
	ttc_rxrst   => '0',             --: in  std_logic;
	ttc_rxready => ttc_rxready,     --: in  std_logic;
	ttc_rxvalid => ttc_rxvalid,     --: in  std_logic;
	ttc_rxd     => ttc_rxd,         --: in  std_logic_vector(199 downto 0);

	BlueGreenRed_LED_1 => BlueGreenRed_LED_1, --: out std_logic_vector(0 to 2);
	BlueGreenRed_LED_2 => BlueGreenRed_LED_2, --: out std_logic_vector(0 to 2);
	BlueGreenRed_LED_3 => BlueGreenRed_LED_3, --: out std_logic_vector(0 to 2);
	BlueGreenRed_LED_4 => BlueGreenRed_LED_4, --: out std_logic_vector(0 to 2);

	gbt_rx_ready_i  => gbt_rx_ready_i,        --: in  std_logic_vector(g_NUM_GBT_LINKS-1 downto 0);
	gbt_rx_bus_i    => gbt_rx_bus_i,          --: in  t_cru_gbt_array(g_NUM_GBT_LINKS-1 downto 0);

	GBT_TX_READY    => (others => '1'),       --: in  std_logic_vector(g_NUM_GBT_LINKS-1 downto 0);
	GBT_TX_BUS      => GBT_TX_BUS,            --: out t_cru_gbt_array(g_NUM_GBT_LINKS-1 downto 0);

	fclk0  => fclk0,    --: out std_logic;
	fval0  => fval0,    --: out std_logic;
	fsop0  => fsop0,    --: out std_logic;
	feop0  => feop0,    --: out std_logic;
	fd0    => fd0,      --: out std_logic_vector(255 downto 0);
	afull0 => '0',   --: in std_logic;

	fclk1  => fclk1,    --: out std_logic;
	fval1  => fval1,    --: out std_logic;
	fsop1  => fsop1,    --: out std_logic;
	feop1  => feop1,    --: out std_logic;
	fd1    => fd1,      --: out std_logic_vector(255 downto 0);
	afull1 => '0'    --: in std_logic

			);
	--============================================================
	-- stimulus 
	--============================================================
	p_stimulus: process
	begin 
		-- initial 
		wait for 0 ps;
		activate_sim <= '1'; -- activate the simulation 
		activate_ttc <= '0'; -- activate the timing & trigger file generator
		activate_gbt <= '0'; -- activate the gbt raw data file generators
		reset_p <= '1';
		wait for 47000 ps;
		reset_p <= '0';
		wait until rising_edge(ttc_rxclk);
		-- activate ttc readout 
		activate_ttc <= '1';
		-- activate gtb readout
		activate_gbt <= '1';
		wait for 57 us; -- delay 
		daq_start <= '1';
		wait;
	end process;
	--============================================================
	-- p_write_to_file
	--============================================================
	--=======--
	-- EPN#1 -- 
	--=======--
	p_EPN1 : process
	 file my_file : text open write_mode is g_FILE_EPN1;
	 variable my_line  : line;
	 variable string_gap : string(4 downto 1) := "    ";
	begin
	 wait until rising_edge(ttc_rxclk);
	 if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
	  if fval1 = '1'  then
	   hwrite(my_line, fd1);
	   -- sop
	   if fsop1 = '1'  then
		write(my_line, string'(" SOP"));
	   else 
		write(my_line, string_gap);
	   end if;
	   -- eop
	   if feop1 = '1'  then
		write(my_line, string'(" EOP"));
	   else 
		write(my_line, string_gap);
	   end if;
	  writeline(my_file, my_line);
	  end if;
	 end if;
	end process;

	--=======--
	-- EPN#0 -- 
	--=======--
	p_EPN0 : process
	 file my_file : text open write_mode is g_FILE_EPN0;
	 variable my_line  : line;
	 variable string_gap : string(4 downto 1) := "    ";
	begin
	 wait until rising_edge(ttc_rxclk);
	 if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
	  if fval0 = '1'  then
	   hwrite(my_line, fd0);
	   -- sop
	   if fsop0 = '1'  then
		write(my_line, string'(" SOP"));
	   else 
		write(my_line, string_gap);
	   end if;
	   -- eop
	   if feop0 = '1'  then
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