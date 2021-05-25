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
--Entity declaration for elink_mux_tb
--=============================================================================
entity elink_mux_tb is
end entity elink_mux_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of elink_mux_tb is
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
	constant FILENAMES : t_string_in(4 downto 0) := ("file_out/reg_decoder_x0.txt",
	                                                 "file_out/loc_decoder_x3.txt",
	                                                 "file_out/loc_decoder_x2.txt",
	                                                 "file_out/loc_decoder_x1.txt",
	                                                 "file_out/loc_decoder_x0.txt");
	-- ========================================================
	-- signal declarations of the design under test
	-- ========================================================
	-- clock signals 
	signal clk_240	: std_logic := '0';
	signal clk_40	: std_logic := '0';
	-- reset 
	signal reset_p : std_logic; -- global reset
	signal reset_i : std_logic; -- global or internal reset
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
	signal ttc_data 	: std_logic_vector(199 downto 0);
	signal ttc_trigger_i: t_mid_trginfo; -- (SOC,EOC,PHY,SOT,EOT)
	signal ttc_bcid_i	: std_logic_vector(15 downto 0);
	signal ttc_info: t_mid_ttcinfo := (	orbit   => (others => '0'), 
										trg 	=> (others => '0'),	
										bcid 	=> (others => '0'),
	    								valid	=> '0');
	-- daq 
	signal daq_reset_i			: std_logic := '0';
	signal daq_start_i			: std_logic;
	-- elink mux 
	signal crateID_o	: std_logic_vector(3 downto 0);
    --
	signal mid_rx_en_i	 : std_logic;								
	signal mid_rx_data_i : std_logic_vector(39 downto 0);		 
	signal mid_rx_valid_i: std_logic;
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
	activate_ttc	=> activate_ttc, 		--: in std_logic;
	clk_40			=> clk_40,				--: in std_logic; -- 40 MHz
    daq_start       => daq_start_i,	        --: in std_logic;
	data			=> gbt_data				--: out std_logic_vector(79 downto 0) 
	    ); 
		 
	-- mid rx bus
	gbt_en(0)      <= gbt_ready(0) and gbt_sel(0);
	mid_rx_en_i    <= gbt_en(0);
	mid_rx_valid_i <= gbt_valid(0);
	mid_rx_data_i  <= gbt_data(39+40*g_REGIONAL_ID downto 0+40*g_REGIONAL_ID);
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
	-- TTC info
	--============================================================
	P_ttc_info: process
	begin 
		wait until rising_edge(clk_240);
		if ttc_info.valid = '1'  then   
			ttc_info.orbit <= ttc_data(79 downto 48);
			ttc_info.bcid	<= x"0" & ttc_data(43 downto 32);
			ttc_info.trg	<= ttc_data(31 downto 0); 

			-- update during physic trigger 
			if ttc_info.trg(4) = '1' then 
			 ttc_bcid_i <= ttc_info.bcid;
			end if;
		end if;
        -- 
		daq_start_i <= daq_reset_i;
	end process;
	-- valid 
	ttc_info.valid <= ttc_valid and ttc_ready and ttc_data(119);
	-- triggers
	ttc_trigger_i.soc <= ttc_info.trg(9); -- soc
	ttc_trigger_i.eoc <= ttc_info.trg(10);-- eoc
	ttc_trigger_i.phy <= ttc_info.trg(4); -- phy
	ttc_trigger_i.sot <= ttc_info.trg(7); -- sot
	ttc_trigger_i.eot <= ttc_info.trg(8); -- eot
	--============================================================
	-- register for  sox 
	--============================================================
	p_sox: process
	begin 
		wait until rising_edge(clk_240);
		wait until ttc_trigger_i.soc = '1';  
		 daq_reset_i <= '1';
		wait until rising_edge(clk_240);
		 daq_reset_i <= '0';
		wait until rising_edge(clk_240);
		wait;
	end process;
	
	reset_i <= reset_p or daq_reset_i;
	--============================================================
	-- DUT 
	--============================================================
	-- fifo not full 
	packet_full_i <= '0';

	DUT: entity work.elink_mux 
	generic map (g_REGIONAL_ID => g_REGIONAL_ID) 
	port map (
	clk_240				=> clk_240, 					--: in std_logic;							                       
	reset_i				=> reset_i, 					--: in std_logic;	
	daq_start_i         => daq_start_i,
	packet_full_i	    => packet_full_i,
	--
	mid_rx_en_i			=> mid_rx_en_i,					--: in std_logic;							
	mid_rx_valid_i		=> mid_rx_valid_i,				--: in std_logic;									
	mid_rx_data_i		=> mid_rx_data_i,	--: in std_logic_vector(39 downto 0);
	--							 
	ttc_bcid_i			=> ttc_bcid_i,						--: in std_logic_vector(15 downto 0);	
	ttc_trigger_i		=> ttc_trigger_i,								
	--
	crateID_o			=> crateID_o,					--: out std_logic_vector(3 downto 0);
	--
	mux_val_o			=> mux_val_o,                   --: 
	mux_stop_o			=> mux_stop_o,                  --: 
	mux_empty_o			=> mux_empty_o,                 --: 
	mux_data_o			=> mux_data_o                   --:	
					); 
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
	--============================================================
	-- This statement generates local and regional decoder modules
	--============================================================
	-- gen_all_dec: for i in 0 to 4 generate
	-- 	Llo_gen: if i < 4 generate 
	-- 		--======================================
	-- 		-- local decoder(0-3)
	-- 		--======================================	
	-- 		Loc_dec: entity work.local_decoder
	-- 		port map (
	-- 		clk_240			=> clk_240,							--: in std_logic;								       
	-- 		reset_i			=> reset_p,							--: in std_logic;								            				
	-- 		loc_en_i	    => gbt_valid(0),					--: in std_logic;								 
	-- 		loc_data_i		=> gbt_data(i*8+7 downto i*8+0),	--: in std_logic_vector(7 downto 0);			 
	-- 		loc_val_o       => loc_en(i),						--: out std_logic;								
	-- 		loc_data_o      => loc_bus(i)						--: out std_logic_vector(167 downto 0)	
	-- 		);  
	-- 		--========================================
	-- 		--  write local decoder(0-3) to text files 
	-- 		--========================================
	-- 		Loc_wr: entity work.write_loc_decoder_sim 
	-- 		generic map (g_FILE_NAME => FILENAMES(i))
	-- 		port map (
	-- 		clk_240		 => clk_240,		--: in std_logic;
	-- 		activate_sim => activate_sim,	--: in std_logic;
	-- 		activate_gbt => activate_gbt,	--: in std_logic;
	-- 		elink_frame_val		 => loc_en(i),		--: in std_logic; 
	-- 		elink_frame_data		 => loc_bus(i)		--: in std_logic_vector(169 downto 0)
	-- 		);
	-- 	end generate;
	-- 	Rlo_gen: if i = 4 generate 
	-- 		--======================================
	-- 		-- regional decoder
	-- 		--======================================
	-- 		Reg_dec: entity work.regional_decoder
	-- 		port map (
	-- 		clk_240			=> clk_240,				         --: in std_logic;								      
	-- 		reset_p			=> reset_p,				         --: in std_logic;								           							
	-- 		reg_en_i	    => gbt_valid(0),				 --: in std_logic;							
	-- 		reg_data_i		=> gbt_data(i*8+7 downto i*8+0), --: in std_logic_vector(7 downto 0);		 
	-- 		reg_val_o		=> reg_en(0),					 --: out std_logic;							 
	-- 		reg_data_o		=> reg_bus(0)					 --: out std_logic_vector(39 downto 0)	 
	-- 		); 
	-- 		--========================================
	-- 		--  write regional decoder 
	-- 		--========================================
	-- 		Reg_wr: entity work.write_reg_decoder_sim 
	-- 		generic map (g_FILE_NAME => FILENAMES(i))
	-- 		port map (
	-- 		clk_240		 => clk_240,		--: in std_logic;
	-- 		activate_sim => activate_sim,	--: in std_logic;
	-- 		activate_gbt => activate_gbt,	--: in std_logic;
	-- 		elink_frame_val		 => reg_en(0),		--: in std_logic; 
	-- 		elink_frame_data		 => reg_bus(0)		--: in std_logic_vector(39 downto 0)
	-- 		);
	-- 	end generate;
	-- end generate;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================
	