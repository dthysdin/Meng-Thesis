-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: all_decoder.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-- This module test the functionality of the both local and regional decoder
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
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for all_decoder_sim
--=============================================================================
entity all_decoder_sim is
end entity all_decoder_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of all_decoder_sim is
	-- ========================================================
	-- type declarations
	-- ========================================================
	type t_string is array (natural range <>) of string(27 downto 1);
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_USED	: integer := 1;
	constant FILENAMES : t_string(9 downto 0) := (
	"file_out/reg_decoder_01.txt",
	"file_out/loc_decoder_07.txt",
	"file_out/loc_decoder_06.txt",
	"file_out/loc_decoder_05.txt",
	"file_out/loc_decoder_04.txt",
	"file_out/reg_decoder_00.txt",
	"file_out/loc_decoder_03.txt",
	"file_out/loc_decoder_02.txt",
	"file_out/loc_decoder_01.txt",
	"file_out/loc_decoder_00.txt"
																 );
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
	signal loc_en : std_logic_vector(7 downto 0);
	signal loc_bus: t_mid_loc_array(7 downto 0);
	-- reg decoder 
	signal reg_en : std_logic_vector(1 downto 0);
	signal reg_bus: t_mid_reg_array(1 downto 0);
	-- counter 
	signal total_eox : std_logic_vector(9 downto 0):= (others => '0');
	
begin 
	--============================================================
	-- clock generator 
	--============================================================
	clk: entity work.clk_gen(behavior)
	generic map (g_NUM_GBT_USED => 1)
	port map (
	activate_ttc	=> '0',							--: in std_logic; -- ttc
	activate_sim	=> activate_sim,				--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,				--: in std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0); -- gbt
	reset_p			=> reset_p,						--: in std_logic;
	clk_40 			=>	clk_40,						--: out  std_logic;
	clk_100 			=>	open,							--: out  std_logic;
	clk_240 			=>	clk_240,						--: out  std_logic; 
	gbt_valid		=>	gbt_valid,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_sel			=>	gbt_sel,						--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	gbt_ready		=> gbt_ready,					--: out std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	ttc_valid		=> open,							--: out std_logic;
	ttc_ready		=> open							--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	 
	Rd_gbt: entity work.read_gbt_sim
	generic map (g_FILE_NAME => "file_in/sim_gbt_dataX0.txt")
	port map (
	activate_sim	=> activate_sim, 		--: in std_logic;
	activate_gbt	=> activate_gbt, 		--: in std_logic;
	clk_40			=> clk_40,				--: in std_logic; -- 40 MHz 
	data				=> gbt_data				--: out std_logic_vector(79 downto 0)
	    ); 
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	--============================================================
	-- This statement generates all 10 elink decoders 
	--============================================================
	gen_all_dec: for i in 0 to 9 generate
		Llo_gen: if i < 4 generate 
			--======================================
			-- local decoder(0-3)
			--======================================	
			Llo_dec: entity work.local_decoder
			port map (
			clk_240			=>	clk_240,								--: in std_logic;								-- TTC clock bus       
			reset_p			=>	reset_p,								--: in std_logic;								-- Reset active high            
			elink_en_i		=>	gbt_en(0),							--: in std_logic;								-- Elink enable in
			elink_valid_i	=> gbt_valid(0),						--: in std_logic;								-- Elink data valid in 
			elink_data_i		=> gbt_data(i*8+7 downto i*8+0),	--: in std_logic_vector(7 downto 0);		-- Elink data in  	 
			elink_frame_val_o =>	loc_en(i),							--: out std_logic;								-- Elink enable out 
			elink_frame_data_o =>	loc_bus(i)							--: out std_logic_vector(167 downto 0)	-- Elink data out 
			);  
			--========================================
			--  write local decoder(0-3) to text files 
			--========================================
			Llo_wr: entity work.write_loc_decoder_sim 
			generic map (g_FILE_NAME => FILENAMES(i))
			port map (
			clk_240		 => clk_240,		--: in std_logic;
			activate_sim => activate_sim,	--: in std_logic;
			activate_gbt => activate_gbt,	--: in std_logic;
			elink_frame_val		 => loc_en(i),		--: in std_logic; 
			elink_frame_data		 => loc_bus(i)		--: in std_logic_vector(169 downto 0)
			);
		end generate;
		Rlo_gen: if i = 4 generate 
			--======================================
			-- regional decoder(0)
			--======================================
			Rlo_dec: entity work.regional_decoder
			port map (
			clk_240			=>	clk_240,								--: in std_logic;								-- 240MHz clock bus       
			reset_p			=>	reset_p,								--: in std_logic;								-- Reset active high            
			elink_en_i		=>	gbt_en(0),							--: in std_logic;								-- Elink enable in
			elink_valid_i	=> gbt_valid(0),						--: in std_logic;								-- Elink data valid in 
			elink_data_i		=> gbt_data(i*8+7 downto i*8+0),	--: in std_logic_vector(7 downto 0);	-- Elink data in  	 
			elink_frame_val_o		=>	reg_en(0),							--: out std_logic;							-- Elink enable out 
			elink_frame_data_o		=>	reg_bus(0)							--: out std_logic_vector(39 downto 0)	-- Elink data out 
			); 
			--========================================
			--  write regional decoder(0) to text file 
			--========================================
			Rlo_wr: entity work.write_reg_decoder_sim 
			generic map (g_FILE_NAME => FILENAMES(i))
			port map (
			clk_240		 => clk_240,		--: in std_logic;
			activate_sim => activate_sim,	--: in std_logic;
			activate_gbt => activate_gbt,	--: in std_logic;
			elink_frame_val		 => reg_en(0),		--: in std_logic; 
			elink_frame_data		 => reg_bus(0)		--: in std_logic_vector(39 downto 0)
			);
		end generate;
		Lhi_gen : if i > 4 and i < 9 generate
			--======================================
			-- local decoder(4-7)
			--======================================
			Lhi_dec: entity work.local_decoder
			port map (
			clk_240			=>	clk_240,								--: in std_logic;								-- TTC clock bus       
			reset_p			=>	reset_p,								--: in std_logic;								-- Reset active high            
			elink_en_i		=>	gbt_en(0),							--: in std_logic;								-- Elink enable in
			elink_valid_i	=> gbt_valid(0),						--: in std_logic;								-- Elink data valid in 
			elink_data_i		=> gbt_data(i*8+7 downto i*8+0),	--: in std_logic_vector(7 downto 0);		-- Elink data in  	 
			elink_frame_val_o		=>	loc_en(i-1),						--: out std_logic;								-- Elink enable out 
			elink_frame_data_o		=>	loc_bus(i-1)						--: out std_logic_vector(167 downto 0)	-- Elink data out 
			); 
			--========================================
			--  write local decoder(4-7) to text files 
			--========================================
			Llo_wr: entity work.write_loc_decoder_sim 
			generic map (g_FILE_NAME => FILENAMES(i))
			port map (
			clk_240		 => clk_240,		--: in std_logic;
			activate_sim => activate_sim,	--: in std_logic;
			activate_gbt => activate_gbt,	--: in std_logic;
			elink_frame_val		 => loc_en(i-1),	--: in std_logic; 
			elink_frame_data		 => loc_bus(i-1)	--: in std_logic_vector(169 downto 0)
			);
		end generate;
		rhi_gen: if i = 9 generate
			--======================================
			-- regional decoder(1)
			--======================================
			Rhi_dec: entity work.regional_decoder
			port map (
			clk_240			=>	clk_240,								--: in std_logic;								-- 240MHz clock bus       
			reset_p			=>	reset_p,								--: in std_logic;								-- Reset active high            
			elink_en_i		=>	gbt_en(0),							--: in std_logic;								-- Elink enable in
			elink_valid_i	=> gbt_valid(0),						--: in std_logic;								-- Elink data valid in 
			elink_data_i		=> gbt_data(i*8+7 downto i*8+0),	--: in std_logic_vector(7 downto 0);	-- Elink data in  	 
			elink_frame_val_o		=>	reg_en(1),							--: out std_logic;							-- Elink enable out 
			elink_frame_data_o		=>	reg_bus(1)							--: out std_logic_vector(39 downto 0)	-- Elink data out 
			);
			--========================================
			--  write regional decoder(1) to text file 
			--========================================
			Rlo_wr: entity work.write_reg_decoder_sim 
			generic map (g_FILE_NAME => FILENAMES(i))
			port map (
			clk_240		 => clk_240,		--: in std_logic;
			activate_sim => activate_sim,	--: in std_logic;
			activate_gbt => activate_gbt,	--: in std_logic;
			elink_frame_val		 => reg_en(1),		--: in std_logic; 
			elink_frame_data		 => reg_bus(1)		--: in std_logic_vector(39 downto 0)
			);
		end generate; 
	end generate;
	--============================================================
	-- stimulus 
	--============================================================
	P_TOTAL_EOX: process 
	begin 
		wait until rising_edge(clk_240);
		for i in 0 to 7 loop 
			if loc_bus(i)(158) = '1' then 
			total_eox(i) <= '1';
			end if;
		end loop;
		
		for i in 0 to 1 loop 
			if reg_bus(i)(30) = '1' then 
			total_eox(i+8) <= '1';
			end if;
		end loop;
	end process;
	
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
		wait until total_eox = "1111111111";
		wait until falling_edge(clk_40);
		-- desactivate the gbt readout 
		activate_gbt <= '0';
		activate_sim <= '0';
		assert false
			report"end of simulation"
			severity failure;
		wait;
	end process; 
	
end architecture;