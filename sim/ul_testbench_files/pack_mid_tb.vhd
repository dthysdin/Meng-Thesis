-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File			: pack_mid_tb.vhd
-- Author		: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company		: NRF iThemba LABS
-- Created   	: 2020-06-24
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version		: 0.3
-------------------------------------------------------------------------------
-- last changes 
-- <13/10/2020> change the component declarations 
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- MID user logic testbench package
-- Mostly used for component declarations, types and records.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

package pack_mid_tb is  
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
	clk_40       : in std_logic; -- 40 MHz 
	data         : out std_logic_vector(79 downto 0)	
	-------------------------------------------------------------------
	 );  
	end component read_gbt_sim;	

end pack_mid_tb;

package body pack_mid_tb is 

end pack_mid_tb;
--=============================================================================
-- package body end
--=============================================================================