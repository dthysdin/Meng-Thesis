-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: updated_header_sim.vhd
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
--Entity declaration for updated_header_sim
--=============================================================================
entity updated_header_sim is
end entity updated_header_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of updated_header_sim is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_OUTPUT	: integer := 1;
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
	signal activate_ttc : std_logic := '0';
	signal activate_gbt : std_logic := '0';
	-- ttc 
	signal ttc_ready	: std_logic; 
	signal ttc_data	: std_logic_vector(199 downto 0);
	-- gbt 
	signal gbt_valid: std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_sel: 	std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_ready:	std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_en : 	std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	-- updatyed_header
	signal updated_req  : std_logic;
	signal updated_empty : std_logic;
	signal updated_info: t_mid_ttcinfo;
	signal ttc_info: t_mid_ttcinfo := (	orbit => (others => '0'), 
													trg 	=> (others => '0'),	
													bcid 	=> (others => '0'),
													valid	=> '0');
	signal req_collect : std_logic := '0';
	signal ack_collect : std_logic;
	
begin 
	--============================================================
	-- clock generator 
	--============================================================
	GNCLK: entity work.clk_gen(behavior)
	generic map (g_NUM_GBT_OUTPUT => 1)
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
	ttc_valid		=> ttc_info.valid,			--: out std_logic;
	ttc_ready		=> ttc_ready					--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	  
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	--============================================================
	-- read TTC data 
	--============================================================
	RDTTC: entity work.read_ttc_sim 
	generic map (g_FILE_NAME  => "file_in/sim_ttc_pon.txt")
	port map (
	activate_sim 	=> activate_sim,			--: in std_logic;
	activate_ttc  	=> activate_ttc,			--: in std_logic;
	clk_40     		=> clk_40,					--: in std_logic; -- 40 MHz 
	data       		=> ttc_data					--: out std_logic_vector(199 downto 0)
	);
	--============================================================
	-- update header  
	--============================================================
	UH: update_header
	port map (
	clk_240				=> clk_240, 			-- : in std_logic;                    	-- TTC clock                      
	reset_p				=> reset_p, 			-- : in std_logic;                    	-- Reset active high
	ttc_info_i			=> ttc_info,			-- : in t_mid_ttcinfo;
	mid_rx_en_i 		=> gbt_en(0),			-- : in std_logic;
	updated_req_i		=> updated_req,		-- : in std_logic; 
	updated_empty_o	=> updated_empty,		-- : out std_logic; 
	updated_info_o		=> updated_info		-- : out t_mid_ttcinfo
       );  
	--============================================================
	-- register for  TTC data 
	--============================================================
	P_ttc: process
	begin 
		wait until rising_edge(clk_240);
		if ttc_info.valid = '1' and ttc_ready = '1' and ttc_data(119) = '1' then   
			ttc_info.orbit <= ttc_data(79 downto 48);
			ttc_info.bcid	<= x"0" & ttc_data(43 downto 32);
			ttc_info.trg	<= ttc_data(31 downto 0); 
		end if;
	end process p_ttc;
	--============================================================
	-- register to request and acknoledge write data 
	--============================================================
	P_reg_req: process
	begin 
		wait until rising_edge(clk_240);
		--
		if updated_empty /= '1' and ttc_info.valid = '1' then 
			-- extract from memory 
			if ack_collect = '0' then
				updated_req <= '1';
			end if;
		else 
			updated_req <= '0';
		end if;
		--
		if updated_req = '1' then 
			-- request collection 
			req_collect <= '1';
		elsif ack_collect = '1' then 
			-- acknoledge collection 
			req_collect <= '0';
		end if;
	end process p_reg_req;
	--============================================================
	-- write to file
	--============================================================
	WUH: entity work.write_update_header_sim
	generic map (g_FILE_NAME => "file_out/link_x0/sim_update_header_x0.txt")
	port map (
	clk_240			=> clk_240,							--: in std_logic;
	activate_sim	=> activate_sim,					--: in std_logic;
	activate_gbt	=> activate_gbt,					--: in std_logic;
	updated_info 	=> updated_info,					--: in t_mid_ttcinfo;
	req_collect		=> req_collect,					--: in std_logic;
	ack_collect		=> ack_collect						--: out std_logic
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
		wait until ttc_ready = '1';
		-- sox 
		wait until updated_info.trg(9) = '1' or updated_info.trg(7) = '1' ;
		report "- sox successfully received - ";
		-- eox
		wait until updated_info.trg(10) = '1' or updated_info.trg(8) = '1' ;
		report "- eox successfully received - ";
		-- all trigger collected 
		wait until ack_collect = '1';
		wait until rising_edge(clk_40);
		--desactivate the gbt readout 
		activate_gbt <= '0';
		activate_ttc <= '0';
		activate_sim <= '0';
		assert false
			report"end of simulation"
			severity failure;
		wait;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================