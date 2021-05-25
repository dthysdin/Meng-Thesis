-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: regional_control_sim.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: --
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
--Entity declaration for packetizer_tb
--=============================================================================
entity packetizer_tb is
end entity packetizer_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of packetizer_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer := 1;
	constant g_WRITE_TO_FILE: integer := 1;
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
	--
	signal mid_rx_bus		: t_mid_gbt;
	--
	signal packet_val_o		: std_logic_vector(1 downto 0);										 
	signal packet_data_o	:Array256bit(1 downto 0);		
	signal packet_empty_o	: std_logic_vector(1 downto 0);				
	signal packet_rdreq_i 	: std_logic_vector(1 downto 0);				
	-- 
	signal payload_size_o	: Array16bit(1 downto 0);			 
	signal payload_empty_o	: std_logic_vector(1 downto 0);				
	signal payload_rdreq_i	: std_logic_vector(1 downto 0);				
	signal payload_crateID_o: std_logic_vector(3 downto 0);				 
	signal payload_size_val_o: std_logic;
	
begin 
	--============================================================
	-- clock generator 
	--============================================================
	clk: entity work.clk_gen
	generic map (g_NUM_GBT_USED => 1)
	port map (
	activate_ttc	=> activate_ttc,				--: in std_logic; -- ttc
	activate_sim	=> activate_sim,				--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,				--: in std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0); -- gbt
	reset_p			=> reset_p,						--: in std_logic;
	clk_40 			=>	clk_40,						--: out  std_logic;
	clk_100 			=>	open,							--: out  std_logic;
	clk_240 			=>	clk_240,						--: out  std_logic; 
	gbt_valid		=>	gbt_valid,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_sel			=>	gbt_sel,						--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_ready		=> gbt_ready,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	ttc_valid		=> ttc_valid,					--: out std_logic;
	ttc_ready		=> ttc_ready					--: out std_logic	
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
	data				=> gbt_data				--: out std_logic_vector(79 downto 0)
	    ); 
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	mid_rx_bus.en 		<= gbt_en(0);
	mid_rx_bus.valid	<= gbt_valid(0);
	mid_rx_bus.data	<= gbt_data;
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
	-- register for  TTC data 
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
			bcid_rx <= x"0" & ttc_data(43 downto 32);
		end if;
	end process;
	--============================================================
	-- DUT 
	--============================================================
	DUT: entity work.packetizer
		port map (
		clk_240				=> clk_240,					--: in std_logic;									                      
		reset_p				=> reset_p,					--: in std_logic;	
		--
		mid_rx_bus_i		=> mid_rx_bus,				--: in t_mid_gbt;	
		--
		ttc_valid_i			=> ttc_valid,				--: in std_logic;									
		ttc_bcid_i			=> bcid_rx,					--: in std_logic_vector(15 downto 0);		
		ttc_trigger_i		=> trg_rx, 					-- TTC TRG 
		--
		packet_val_o		=>	packet_val_o,			--: out std_logic;										 
		packet_data_o		=>	packet_data_o,			--: out std_logic_vector(255 downto 0);			
		packet_empty_o		=>	packet_empty_o,		--: out std_logic_vector(1 downto 0);				
		packet_rdreq_i 	=>	packet_rdreq_i,		--: in std_logic_vector(1 downto 0);				
		-- 
		payload_size_o		=>	payload_size_o,		--: out std_logic_vector(31 downto 0);			 
		payload_empty_o	=>	payload_empty_o,		--: out std_logic_vector(1 downto 0);				
		payload_rdreq_i	=>	payload_rdreq_i,		--: in std_logic_vector(1 downto 0);				
		payload_crateID_o	=>	payload_crateID_o,	--: out std_logic_vector(3 downto 0);				 
		payload_size_val_o=>	payload_size_val_o	--: out std_logic										

		);
	--============================================================
	-- read request 
	--============================================================
	p_request : process
	begin 
		wait until rising_edge(clk_240);
		-- request payload 
		if payload_empty_o = "00" then 
			payload_rdreq_i <= "11";
		else 
			payload_rdreq_i <= "00";
		end if;
		
		-- request packets 
		if packet_empty_o(1) = '0' then
			packet_rdreq_i <= "10";
		elsif packet_empty_o(0) = '0' then 
			packet_rdreq_i <= "01";
		else 
			packet_rdreq_i <= "00";
		end if;
		-- 
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
	
end architecture;
--=============================================================================
-- architecture end
--=============================================================================