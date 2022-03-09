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
entity packetizer_sim is
end entity packetizer_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of packetizer_sim is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_NUM_GBT_OUTPUT	: integer := 1; -- number of links tested (not needed)
	constant g_TEST_WITHOUT_GBT: integer := 0; -- 1 to disable the GBT link 
															 -- 0 to enable the GBT link
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
	-- gbt data 
	signal gbt_data 	: std_logic_vector(g_NUM_GBT_OUTPUT*80-1 downto 0);
	signal gbt_valid	: std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_sel		: 	std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_ready	:	std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	signal gbt_en 		: std_logic_vector(g_NUM_GBT_OUTPUT-1 downto 0);
	-- ttc 
	signal ttc_ready	: std_logic; 
	signal ttc_valid	: std_logic; 
	signal ttc_data	: std_logic_vector(199 downto 0);
	signal trg_rx		: t_mid_trginfo; -- (SOC,EOC,PHY,SOT,EOT)
	signal bcid_rx		: std_logic_vector(15 downto 0):= x"0000";
	-- update header
	signal updated_req	: std_logic; 
	signal updated_empty : std_logic; 
	signal ttc_info  		: t_mid_ttcinfo;
	signal updated_info  : t_mid_ttcinfo;
	-- rl_link 
	signal mid_rx_bus			: t_mid_gbt;
	signal rl_packet_req		: std_logic_vector(2*1 - 1 downto 0);	-- 2 x req buff
	signal rl_packet_ready 	: std_logic_vector(2*1 - 1 downto 0);	-- 2 x ready buff
	signal rl_packet_size  	: std_logic_vector(2*16 - 1 downto 0);	-- 2 x count buff
	signal rl_packet_data  	: std_logic_vector(2*256 - 1 downto 0);	-- 2 x data buff
	signal rl_packet_empty 	: std_logic_vector(2*1 - 1 downto 0);	-- 2 x empty buff
	signal rl_crateID 	  	: std_logic_vector(3 downto 0);			-- crate ID 
	-- packetizer 
	signal access_req 	  	: std_logic;		-- request
	signal gbt_packet_done 	: std_logic;		-- gbt packet complete (done)
	signal gbt_packet		  	: t_mid_datapath; -- gbt packet record out  
	-- checking 
	signal sans_gbt : std_logic;
	
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
	ttc_valid		=> ttc_valid,					--: out std_logic;
	ttc_ready		=> ttc_ready					--: out std_logic	
	    );  
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
	-- register for  TTC data 
	--============================================================
	ttc_info.valid <= ttc_valid;
	P_ttc: process
	begin 
		wait until rising_edge(clk_240);
		if ttc_info.valid = '1' and ttc_ready = '1' and ttc_data(119) = '1' then   
			ttc_info.orbit <= ttc_data(79 downto 48);
			ttc_info.bcid	<= x"0" & ttc_data(43 downto 32);
			ttc_info.trg	<= ttc_data(31 downto 0); 
			--
			-- (SOC,EOC,PHY,SOT,EOT)
			trg_rx.soc <= ttc_data(9); -- soc
			trg_rx.eoc <= ttc_data(10);-- eoc
			trg_rx.phy <= ttc_data(4); -- phy
			trg_rx.sot <= ttc_data(7); -- sot
			trg_rx.eot <= ttc_data(8); -- eot
			bcid_rx <= x"0" & ttc_data(43 downto 32);
		end if;
	end process p_ttc;
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
	-- read GBT data 
	--============================================================	 
	RDGBT: entity work.read_gbt_sim
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
	--=============================================================================
	-- Begin TST_GEN
	-- This statement generates the zero suppression of the gbt data 
	--=============================================================================
	TST_GEN_No :  if g_TEST_WITHOUT_GBT /= 1 generate
		-- with gbt data 
		sans_gbt <= '0';
		RLY: entity work.rl_link 
		port map (
		clk_240				=> clk_240,					--: in std_logic;									-- TTC clock bus                       
		reset_p				=> reset_p,					--: in std_logic;									-- reset active high
		mid_rx_bus_i		=> mid_rx_bus,				--: in t_mid_gbt;									-- mid gbt bus
		ttc_valid_i			=> ttc_valid,				--: in std_logic;									-- TTC VALID 
		ttc_bcid_i			=> bcid_rx,					--: in std_logic_vector(15 downto 0);			-- TTC BC
		ttc_trigger_i		=> trg_rx, 					--: in std_logic_vector(3 downto 0);			-- TTC TRG (SOT,PHY,EOT,HB)
		rl_packet_req_i	=>	rl_packet_req,			--: in std_logic_vector(2*1 - 1 downto 0);	-- 2 x req buff
		rl_packet_ready_o	=>	rl_packet_ready,		--: out std_logic_vector(2*1 - 1 downto 0);	-- 2 x ready buff
		rl_packet_size_o	=>	rl_packet_size,		--: out std_logic_vector(2*16 - 1 downto 0);-- 2 x count buff
		rl_packet_data_o	=>	rl_packet_data,		--: out std_logic_vector(2*256 - 1 downto 0);-- 2 x data buff
		rl_packet_empty_o	=>	rl_packet_empty,		--: out std_logic_vector(2*1 - 1 downto 0);	-- 2 x empty buff
		rl_crateID_o 		=>	rl_crateID				--: out std_logic_vector(2*4 - 1 downto 0)	-- 2 x crate ID 
				);
		-- write output to file
		with_data: entity work.write_packetizer_sim
		generic map (g_FILE_NAME => "file_out/link_x0/sim_packet_with_data.txt")
		port map (
		clk_240				=> clk_240,					--: in std_logic;
		activate_sim		=> activate_sim,			--: in std_logic;
		activate_gbt		=> activate_gbt,			--: in std_logic;
		activate_ttc		=> activate_ttc,			--: in std_logic;
		gbt_packet_done	=>	gbt_packet_done,		--: in std_logic;	
		gbt_packet			=>	gbt_packet				--: in t_mid_datapath  	
	    );
	end generate TST_GEN_No;
	
	TST_GEN_Yes :  if g_TEST_WITHOUT_GBT = 1 generate
		-- sans gbt data
		sans_gbt <= '1';
		rl_packet_ready 	<= "00";					-- never ready 
		rl_packet_size		<=	(others => '0');	-- size 0 
		rl_packet_data 	<= (others => '0');	-- no data 
		rl_packet_empty 	<= "11"; 				-- always empty
		rl_crateID 			<= x"55";				-- crate#5
		-- write output to file
		without_data: entity work.write_packetizer_sim
		generic map (g_FILE_NAME => "file_out/link_x0/sim_packet_sans_data.txt")
		port map (
		clk_240				=> clk_240,					--: in std_logic;
		activate_sim		=> activate_sim,			--: in std_logic;
		activate_gbt		=> activate_gbt,			--: in std_logic;
		activate_ttc		=> activate_ttc,			--: in std_logic;
		gbt_packet_done	=>	gbt_packet_done,		--: in std_logic;	
		gbt_packet			=>	gbt_packet				--: in t_mid_datapath  	
	    );
	end generate TST_GEN_yes;
	
	--============================================================
	-- component under test (packetizer)
	--============================================================
	PCKTZ: packetizer
	generic map ( g_LINK_ID => 0, g_DWRAPPER_ID => 0)
	port map(
	clk_240				=> clk_240, 				--: in std_logic;		-- TTC clock                      
	reset_p				=> reset_p, 				--: in std_logic;		-- reset active high
	rl_packet_ready_i	=> rl_packet_ready,		--: in std_logic_vector(2*1 - 1 downto 0);	-- 2 x ready buff
	rl_packet_size_i	=> rl_packet_size,		--: in std_logic_vector(2*16 - 1 downto 0);	-- 2 x count buff
	rl_packet_data_i	=>	rl_packet_data,		--: in std_logic_vector(2*256 - 1 downto 0);-- 2 x data buff
	rl_packet_empty_i	=>	rl_packet_empty,		--: in std_logic_vector(2*1 - 1 downto 0);	-- 2 x empty buff
	rl_crateID_i 		=>	rl_crateID,				--: in std_logic_vector(2*4 - 1 downto 0);	-- 2 x crate ID 
	rl_packet_req_o	=>	rl_packet_req,			--: out std_logic_vector(2*1 - 1 downto 0);	-- 2 x req buff
	updated_empty_i	=>	updated_empty,			--: in std_logic;		-- buff empty
	updated_info_i		=>	updated_info,			--: in t_mid_ttcinfo;	-- ttc info 
	updated_req_o		=>	updated_req,			--: out std_logic;		-- request
	access_ack_i		=>	'1', --(always)		--: in  std_logic;		-- acknoledge
	access_req_o 		=>	access_req,				--: out std_logic;		-- request
	gbt_packet_done_o	=>	gbt_packet_done,		--: out std_logic;		-- gbt packet complete (done)
	gbt_packet_o		=>	gbt_packet				--: out t_mid_datapath	-- gbt packet record out  															
       );  
	--============================================================
	-- check DUT 
	--============================================================
	p_checking: process
	variable cnt : integer := 0;
	begin 
		wait until rising_edge(clk_240);
		if sans_gbt = '1' then 
			if gbt_packet.valid = '1' then
				-- increment 
				cnt := cnt + 1;
				case cnt is 
				when 1 =>  
					-- sop
					if gbt_packet.sop = '1' then
						assert gbt_packet.data(7 downto 0) = x"06"		
							report "wrong header version" 
							severity warning;
						assert gbt_packet.data(15 downto 8)= x"40" 		
							report "wrong header version" 
							severity warning;
						assert gbt_packet.data(31 downto 16)= x"000A" 	
							report "wrong feedID" 			
							severity warning;
						assert gbt_packet.data(47 downto 40)= x"25"		
							report "wrong systemID" 		
							severity warning;
						assert gbt_packet.data(79 downto 64)= x"0040" 	
							report "wrong offset" 			
							severity warning;
						assert gbt_packet.data(95 downto 80)= x"0040" 	
							report "wrong memory size" 	
							severity warning;
						assert gbt_packet.data(127+11 downto 0+128)= x"00" & "000" 
							report "wrong BCID" 
							severity warning;
					end if;
				when 2 => 
					assert gbt_packet.data(47 downto 32)= x"0000" 
						report "wrong page counter" 	
						severity warning;
					--- eop 
					if gbt_packet.eop = '1' then
						cnt := 0;
					end if;
					-- done 
					if gbt_packet_done = '1' then
						assert gbt_packet.data(55 downto 48)= x"01"	
							report "no stop bit" 	
							severity failure;
						report "heartbeat close";
					else 
						report "heartbeat open"; 
					end if;
				when others => 
					-- error 
					cnt := 0;
					assert false 
						report "no eop - something wrong" 
						severity failure;
				end case;
		--else 
		
			end if;	-- gbt_packet.valid 
		end if;		-- sans gbt 		
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