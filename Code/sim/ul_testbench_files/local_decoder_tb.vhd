-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: local_decoder_tb.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- This module test the functionality of the local decoder module
-- You can save the results in a text by enabling the g_WRITE_TO_FILE
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

-- Specific package 
use work.pack_cru_core.all;
--use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for local_decoder_tb
--=============================================================================
entity local_decoder_tb is
end entity local_decoder_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of local_decoder_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer := 1;
	constant g_WRITE_TO_FILE: integer := 1;
	constant g_REGIONAL_ID	: integer:= 0;	-- Range 0~1 -- 1 = UPPER SIDE  -- 0 = LOWER SIDE
	constant g_LOCAL_ID		: integer:= 3;	-- Range 0~7 -- LOCAL ID{0-3} REGIONAL ID must be 0
														 -- LOCAL ID{4-7} REGIONAL ID must be 1
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
	-- gbt data 
	signal gbt_data : std_logic_vector(g_NUM_GBT_USED*80-1 downto 0);
	signal gbt_valid: std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_sel: 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_ready:	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_en : 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	-- loc decoder 
	signal s_elink_frame_val : std_logic;
	signal s_elink_frame_data: std_logic_vector(167 downto 0);
	
	begin 
	--============================================================
	-- clock generator 
	--============================================================
	clk: entity work.clk_gen
	generic map (g_NUM_GBT_USED => 1)
	port map (
	activate_ttc	=> '0',							--: in std_logic; -- ttc
	activate_sim	=> activate_sim,				--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,				--: in std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0); -- gbt
	reset_p			=> reset_p,						--: in std_logic;
	clk_40 			=> clk_40,						--: out  std_logic;
	clk_100 		=> open,						--: out  std_logic;
	clk_240 		=> clk_240,						--: out  std_logic; 
	gbt_valid		=> gbt_valid,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_sel			=> gbt_sel,						--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_ready		=> gbt_ready,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	ttc_valid		=> open,						--: out std_logic;
	ttc_ready		=> open							--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	 
	Read_gbt: entity work.read_gbt_sim
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
	-- DUT
	--============================================================	
	loc_dec: entity work.local_decoder
	port map (
	clk_240				=> clk_240,  
	reset_p				=> reset_p,
	--
	elink_en_i			=> gbt_en(0),
	elink_valid_i		=> gbt_valid(0),
	elink_data_i		=> gbt_data(8*g_REGIONAL_ID+7+8*g_LOCAL_ID downto 8*g_REGIONAL_ID+0+8*g_LOCAL_ID),
	--
	elink_frame_val_o	=> s_elink_frame_val,
	elink_frame_data_o	=> s_elink_frame_data
	 ); 
	--============================================================
	-- stimulus 
	--============================================================
	STIMULUS: 
	process
	begin 
		-- initial 
		wait for 0 ps;
		activate_sim <= '1';
		activate_gbt <= '0';
		reset_p <= '1';
		wait for 47000 ps;
		reset_p <= '0';
		wait until rising_edge(clk_240);
		-- activate gtb readout   
		activate_gbt <= '1';
		-- end of packet 
		wait until s_elink_frame_data(158) = '1';
		wait until falling_edge(clk_40);
		-- desactivate the gbt readout 
		activate_gbt <= '0';
		activate_sim <= '0';
		assert false
			report"end of simulation"
			severity failure;
		wait;
	end process; 
	--============================================================
	-- check local card status  
	--============================================================
	P_cstatus: process 
	begin 
		wait until rising_edge(clk_240);
			if s_elink_frame_val = '1' then  
			
				-- check the start bit and card type 
				assert s_elink_frame_data(167 downto 166) = "11" 
					report "error in format" 
					severity Failure;
					
				-- check trigger sox and eox 
				assert s_elink_frame_data(159 downto 158) /= "11"  
					report "error in trigger" 
					severity Failure;
					
				-- check bunch crossing 
				assert s_elink_frame_data(151 downto 148) = x"0" 
					report "error in bcid" 
					severity Failure;
					
				-- check chambers 
				case s_elink_frame_data(131 downto 128) is 
				when x"1"|x"2"|x"4"|x"8" => 
					-- 1 chamber fired 
					assert s_elink_frame_data(127 downto 96) /= x"00000000" 
						report "error in strip patters" 
						severity Failure;
						
				when x"3"|x"5"|x"6"|x"A"|x"C" => 
					-- 2 chambers fired 
					assert s_elink_frame_data(95 downto 64) /= x"00000000" 
						report "error in strip patters" 
						severity Failure;
				
				when x"7"|x"B"|x"D"|x"E" => 
					-- 3 chambers fired 
					assert s_elink_frame_data(63 downto 32) /= x"00000000" 
						report "error in strip patters" 
						severity Failure;
				
				when x"F" => 
					-- 4 chambers fired 
					assert s_elink_frame_data(31 downto 0) /= x"00000000" 
						report "error in strip patters" 
						severity Failure;
				when others => null;
				end case;
				
			end if;	 
	end process;
	
	--============================================================
	-- write to file  
	--============================================================
	WR_GEN: if g_WRITE_TO_FILE = 1 generate 
		
		WR: entity work.write_loc_decoder_sim
		generic map (g_FILE_NAME => "file_out/loc_decoder_03.txt") -- needs to be updated 
		port map (
		clk_240			=> clk_240, 			--: in std_logic;
		activate_sim	=> activate_sim,		--: in std_logic;
		activate_gbt	=> activate_gbt,		--: in std_logic;
		elink_frame_val => s_elink_frame_val,	--: in std_logic; 
		elink_frame_data=> s_elink_frame_data	--: in std_logic_vector(167 downto 0)
	    );
	end generate; 
end architecture;
--=============================================================================
-- architecture end
--=============================================================================