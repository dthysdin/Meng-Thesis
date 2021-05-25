------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: gbt_ulogic_mux.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company	: NRF iThemba LABS
-- Created   	: 2020-06-27
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version	: 0.7
-------------------------------------------------------------------------------
-- last changes
-- <13/10/2020> The module name changed from zs_link to zs_mux 
--		Change combitional FSM to sequential 
--		Change the name of some signals
--		Change generic g_HALF_NUM_GBT_OUTPUT to g_HALF_NUM_GBT_USED
-- <21/02/2021> The module name changed from zs_mux to gbt_logic_mux
-------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
-- Description:
-- This module multiplexes diffetent heartbeat frame packets from different GBT links. 
-- This multiplexer has N (number of inputs) and one output. N is the generic 
-- g_HALF_NUM_GBT_USED, which corresponds to half of the GBT links used for 
-- the MID. 

-- Requirements: no specific requirements 
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for gbt_ulogic_mux
--=============================================================================
entity gbt_ulogic_mux is
	generic (g_DWRAPPER_ID : integer := 0; g_HALF_NUM_GBT_USED : integer := 1; g_NUM_HBFRAME_SYNC: integer := 1);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240		   : in std_logic;
	-------------------------------------------------------------------
	-- reset --	
	reset_i	       : in std_logic;										
	-------------------------------------------------------------------
	-- d-wrappers fifo full  --	
	afull_i 	   : in std_logic;	
	-------------------------------------------------------------------
	-- timing and trigger control info --		
	ttc_data_i     : in t_mid_ttc; 
	ttc_mode_i     : in t_mid_mode;
    ttc_pulse_i    : in t_mid_pulse;
	-------------------------------------------------------------------
	-- mid gbt raw data --	
	mid_rx_bus_i   : in t_mid_gbt_array(g_HALF_NUM_GBT_USED-1 downto 0);
	-------------------------------------------------------------------
	-- avalon
	av_cruid_config_i : in std_logic;	
	av_gbt_monit_o : out Array64bit(g_HALF_NUM_GBT_USED-1 downto 0);	
	av_dw_monit_o  : out std_logic_vector(31 downto 0);		
	-------------------------------------------------------------------
	-- d-wrapper datapath info --
	dw_datapath_o  : out t_mid_dw_datapath													 
	------------------------------------------------------------------------
				);  
end gbt_ulogic_mux;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of gbt_ulogic_mux is
	-- ===================================================
	-- SYMBOLIC ENCODED state machine: t_gbt_mux_state
	-- ===================================================
	type t_gbt_mux_state is (IDLE, 
	                         HDR_VAL,
							 ACCESS_RDY,
							 PUSH_GAP,
							 PUSH_RDH10,
							 PUSH_RDH32,
							 ACCESS_PLOAD,
							 PUSH_PLOAD);	

	signal state: t_gbt_mux_state := IDLE;
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant c_NULL : std_logic_vector(g_HALF_NUM_GBT_USED-1 downto 0) := (others => '0');
	constant c_MAX_PACKET   : unsigned(15 downto 0):= x"FFFF";               -- 65535 packets (2048 KB) 
	constant HEADER_VERSION : std_logic_vector(7 downto 0) := x"06";	     -- Version 6
	constant HEADER_SIZE 	: std_logic_vector(7 downto 0) := x"40";	     -- 64 bytes
	constant SYSTEM_ID	    : std_logic_vector(7 downto 0) := x"25";         -- MID detector (37)
	constant DETECTOR_FIELD	: std_logic_vector(31 downto 0):= x"0000A003";   -- detector field 
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal RDH : Array128bit (0 to 3); 	-- Raw data header
	
	-- rdh fields --												
	signal MEMORY_SIZE: std_logic_vector(15 downto 0);	-- memory size of the payload 
	signal OFFSET: std_logic_vector(15 downto 0);		-- offset of the payload 
	signal FEEID : std_logic_vector(15 downto 0);
    -- header 
	signal s_header       : t_mid_hdr;
	signal s_header_rdreq : std_logic;
	-- gbt access  
	signal s_gbt_access_req : std_logic_vector(g_HALF_NUM_GBT_USED-1 downto 0); 
	signal s_gbt_access_ack : std_logic_vector(g_HALF_NUM_GBT_USED-1 downto 0); 
    signal s_gbt_access_ena : std_logic_vector(g_HALF_NUM_GBT_USED-1 downto 0); 
	signal s_gbt_access_rdy : std_logic;
	-- gbt datapath  
	signal s_gbt_datapath_cnt : Array16bit(g_HALF_NUM_GBT_USED-1 downto 0);
	signal s_gbt_datapath     : t_mid_gbt_datapath_array(g_HALF_NUM_GBT_USED-1 downto 0);

    -- index ID
    signal s_indexID : integer range 0 to g_HALF_NUM_GBT_USED-1 := 0;
	
	-- d-wrapper flags 
	signal s_dw_close        : std_logic := '0';
	signal s_dw_total_cnt    : unsigned(15 downto 0);
	signal s_dw_page_cnt     : unsigned(15 downto 0);
	signal s_dw_packet_cnt   : unsigned(15 downto 0) := (others => '0');
    signal s_dw_fsm_monit    : std_logic_vector(7 downto 0);
	signal s_temp_dw_packet_cnt: std_logic_vector(15 downto 0);

	-- avalon gbt monitor 
	signal s_av_gbt_monit : Array64bit(g_HALF_NUM_GBT_USED-1 downto 0);

	-- d-wrapper datapath 
	signal s_dw_datapath     : t_mid_dw_datapath;
	signal s_dw_datapath_cnt : unsigned(15 downto 0) := (others => '0');

begin
	--==============================================================================
	-- Begin of GBT_LOGIC_GEN
	-- This statement generates half of the zs packets contain in this project.
	-- The number of interation depends on the value allocated to the g_HALF_NUM_GBT_USED
	-- The g_LINK_ID depends on the interation ID 
	--===============================================================================
	GBT_LOGIC_GEN : for i in 0 to g_HALF_NUM_GBT_USED-1 generate
	    s_gbt_access_ena(i) <= mid_rx_bus_i(i).en;
		--============--
		-- GBT_ULOGIC --
		--============--
		gbt_ulogic_inst: gbt_ulogic
		generic map (g_LINK_ID => i, g_NUM_HBFRAME_SYNC => g_NUM_HBFRAME_SYNC)
		port map (
		clk_240		        => clk_240,                   
		reset_i	            => reset_i,			
	    ttc_mode_i	        => ttc_mode_i,
	    ttc_sox_pulse_i     => ttc_pulse_i.sox,
		ttc_sel_pulse_i     => ttc_pulse_i.sel,
		dw_packet_cnt_i     => s_temp_dw_packet_cnt,
		header_rdreq_i      => s_header_rdreq,
		mid_rx_bus_i	    => mid_rx_bus_i(i),
		av_gbt_monit_o      => s_av_gbt_monit(i),
		gbt_access_ack_i	=> s_gbt_access_ack(i),
		gbt_access_req_o 	=> s_gbt_access_req(i),
		gbt_datapath_o	    => s_gbt_datapath(i),
		gbt_datapath_cnt_o  => s_gbt_datapath_cnt(i));  
	end generate GBT_LOGIC_GEN;
	--========--
	-- HEADER --
	--========--
	header_inst: header
	port map (
	clk_240         => clk_240,
	reset_i	        => reset_i,
	ttc_data_i      => ttc_data_i,
	hbt_pulse_i     => ttc_pulse_i.hbt,
	sox_pulse_i     => ttc_pulse_i.sox,
	eox_pulse_i     => ttc_pulse_i.eox,
	header_o        => s_header,
	header_rdreq_i  => s_header_rdreq); 
	---------
	-- RDH --
	---------
	-- RDH0
	RDH(0)(7 downto 0)      <= HEADER_VERSION;			                      -- hdr version
	RDH(0)(15 downto 8) 	<= HEADER_SIZE;    			                      -- header size
	RDH(0)(31 downto 16) 	<= FEEID;	                                      -- feeID 
	RDH(0)(39 downto 32) 	<= x"00";					                      -- priority bit 
	RDH(0)(47 downto 40) 	<= SYSTEM_ID;        		                      -- system id 
	RDH(0)(63 downto 48) 	<= x"0000";					                      -- reserved 
	RDH(0)(79 downto 64) 	<= OFFSET; 					                      -- offset -- default 8KB 0x2000
	RDH(0)(95 downto 80) 	<= MEMORY_SIZE;				                      -- memory size -- default 8KB 0x2000
	RDH(0)(103 downto 96)	<= std_logic_vector(to_unsigned(15,8));			  -- link_ID -- default datapath link#15 (0x0F)
	RDH(0)(111 downto 104)	<= x"00";					                      -- packet counter
	RDH(0)(123 downto 112)	<= x"000";					                      -- cruid
	RDH(0)(127 downto 124)	<= std_logic_vector(to_unsigned(g_DWRAPPER_ID,4));-- CRU end point ID
	--RDH1 
	RDH(1)(11 downto 0) 	<= s_header.data.bcid(11 downto 0);	              -- bcid
	RDH(1)(31 downto 12) 	<= s_header.data.bcid(15 downto 12) & x"0000";    -- reserved
	RDH(1)(63 downto 32) 	<= s_header.data.orbit;        		              -- orbit  
	RDH(1)(127 downto 64)	<= (others => '0');				                  -- reserved
	--RDH2
	RDH(2)(31 downto 0) 	<= s_header.data.trg; 				              -- trigger types 
	RDH(2)(47 downto 32) 	<= std_logic_vector(s_dw_page_cnt);			      -- page counter
	RDH(2)(55 downto 48) 	<= x"01" when s_dw_close = '1' else x"00";		  -- stop bit 
	RDH(2)(127 downto 56)	<= (others => '0');				                  -- reserved
	-- RDH3 
	RDH(3)(31 downto 0)  	<= DETECTOR_FIELD;				                  -- detector field
	RDH(3)(47 downto 32)	<= x"0000";					                      -- par bit
	RDH(3)(127 downto 32) 	<= (others => '0');        	                      -- reserved

	-- define MEMORY SIZE								
	MEMORY_SIZE <= std_logic_vector(to_unsigned(((to_integer(s_dw_total_cnt)+2)*(256))/(8),16)) when state = PUSH_RDH10 and s_dw_total_cnt < x"0100" else x"2000";
	-- define OFFSET				
	OFFSET <= std_logic_vector(to_unsigned(((to_integer(s_dw_total_cnt)+2)*(256))/(8),16))when state = PUSH_RDH10 and s_dw_total_cnt < x"0100" else x"2000"; 

    -- define FEEID 

	-- DW#1 - CRUID#1 ==> FEEID = 3
	-- DW#1 - CRUID#0 ==> FEEID = 1
    DW1_gen: if g_DWRAPPER_ID = 1 generate 
     FEEID <= std_logic_vector(to_unsigned(3,16)) when av_cruid_config_i = '1' else std_logic_vector(to_unsigned(1,16));  
	end generate DW1_gen;

	-- DW#0 - CRUID#1 ==> FEEID = 2
	-- DW#0 - CRUID#0 ==> FEEID = 0
	DW0_gen: if g_DWRAPPER_ID /= 1 generate 
	 FEEID <= std_logic_vector(to_unsigned(2,16)) when av_cruid_config_i = '1' else std_logic_vector(to_unsigned(0,16)); 
	end generate DW0_gen;

	s_header_rdreq  <= '1' when state = IDLE and afull_i = '0' and s_header.ready = '1' else '0';     -- request update header 
    s_temp_dw_packet_cnt <= std_logic_vector(s_dw_packet_cnt);
	--=============================================================================
	-- Begin of p_state
	-- This process is a sequential state machine 
	--=============================================================================
	p_state: process(clk_240)
	 variable index : integer range 0 to g_HALF_NUM_GBT_USED-1 := 0;
	begin
	 if rising_edge(clk_240) then 
	  -- default output -- 
	  s_dw_datapath.sop   <= '0';              -- dwrapper datapath sop
	  s_dw_datapath.eop   <= '0';              -- dwrapper datapath eop
	  s_gbt_access_ack    <= (others => '0');  -- gbt access acknowlwdge

	  if reset_i = '1' then 
	   state <= IDLE;
	   s_dw_close <= '0';
	   index := 0;
	  else 	
	   -- case fsm --
	   case state is 
	   --========
	   -- IDLE -- 
	   --========
	   -- state"idle"
	   when IDLE => 
	    if afull_i = '0' then
		 if s_header.ready = '1' then  
		  state <= HDR_VAL;           	               
		 end if;  
	    end if;
	   --=========--
	   -- HDR_VAL -- 
	   --=========--
	   -- state "HDR_VAL"
	   when HDR_VAL => 
	    if s_header.valid = '1' then
		 state <= ACCESS_RDY;
	    end if;
	   --============--
	   -- ACCESS_RDY -- 
	   --============--
	   -- state "ACCESS_RDY"
	   when ACCESS_RDY => 
	    if s_gbt_access_rdy = '1' then  
	     state <= PUSH_GAP; 
	    end if;
	   --==========--
	   -- PUSH_GAP -- 
	   --==========--
	   -- state "PUSH_GAP"
	   when PUSH_GAP => 
	    state <= PUSH_RDH10;
	   --============--
	   -- PUSH_RDH10 -- 
	   --============--
	   -- state "SEND_RDH10"
	   when PUSH_RDH10 => 
	    s_dw_datapath.sop <= '1';					 
	    state <= PUSH_RDH32;
	   --============--
	   -- PUSH_RDH32 -- 
	   --============--
       -- state "PUSH_RDH32"
	   when PUSH_RDH32 => 
	    -- one or more packets available 
        -- push payload 
	    if s_dw_total_cnt > x"0000" then    
	     state <= ACCESS_PLOAD;  

		-- zero packets available  
		-- push last RDH32(close) + stop bit
	    elsif s_dw_close = '1' then
	     s_dw_datapath.eop <= '1';
	     s_dw_close <= '0'; 
	     state <= IDLE;

		-- zero packets available 
		-- push RDH32(open) 
		-- enable stop bit next RDH32(close)
	    else 
		 s_dw_datapath.eop <= '1';
		 s_dw_close <= '1';
	     state <= PUSH_GAP;
	    end if;
	   --==============--
	   -- ACCESS_PLOAD -- 
	   --==============--
	   when ACCESS_PLOAD => 
	    if s_gbt_access_req /= c_NULL then
		 -- access requested from the gtb link 
	     if s_gbt_access_req(index) = '1' then
	      s_gbt_access_ack(index) <= '1';         -- access acknowledged           
	      s_indexID <= index;                     -- index ID
		  state <= PUSH_PLOAD;
         -- error in access req data
	     elsif index = g_HALF_NUM_GBT_USED-1 then 
	      index := 0;                             -- self reset index
		 -- no request access
	     else  
	      index := index + 1;                     -- increment index counter
	     end if;
		else 
		 index := 0;                           
		 state <= IDLE;
	    end if;
	   --============--
	   -- PUSH_PLOAD -- 
	   --============--
	   -- state "PUSH_PLOAD"
	   when PUSH_PLOAD =>
		-- maximum packet [8KB = 256 packets]
	    if s_dw_packet_cnt = x"0100" then
		 s_dw_datapath.eop <= '1';	 
	     state <= PUSH_GAP;

		-- no more data 
		elsif s_gbt_datapath(s_indexID).done = '1' then 
		 if s_dw_total_cnt = x"0000" then
		  s_dw_datapath.eop <= '1';	  
		  s_dw_close <= '1';
		  state <= PUSH_GAP;
		 else 
		  state <= ACCESS_PLOAD;
		 end if;
	    end if;
       --=========--
	   -- ORTHERS -- 
	   --=========--
	   when others => 
	    -- all the other states (not defined)
        -- jump to save state (ERROR?!)
	    state <= idle;
	   end case;
	  end if;
	 end if;	
	end process p_state;
	--===============================================================================
	-- Begin of p_dw_total_cnt 
	-- This process countains the total number of packets data pushed during a HBF
	--===============================================================================
	p_dw_total_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	   s_dw_total_cnt <= sum_Array16bit(s_gbt_datapath_cnt);  -- call function <sum_Array16bit>
	 end if;
	end process p_dw_total_cnt;
    --=============================================================================
	-- Begin of p_state_out 
	-- This process transmits the data output of the sequential state machine
	--=============================================================================
	p_state_out: process(clk_240)
	 variable select_out : std_logic_vector(g_HALF_NUM_GBT_USED-1 downto 0);
    begin 
	 if rising_edge(clk_240) then 
	   
	  -- default dwrapper datapath out --
	  s_dw_datapath.valid  <= '0';            			           			 
	  s_dw_datapath.data <= (others => '0');
	 
	  -- concatenate 
	  for i in 0 to g_HALF_NUM_GBT_USED-1  loop
	   select_out(i) := s_gbt_datapath(i).valid;
      end loop;

	  case state is				 
	   when PUSH_RDH10 => 
	    -- RDH2 & RDH1 
	    s_dw_datapath.data <= RDH(1)& RDH(0);                   -- header#10
	    s_dw_datapath.valid <= '1';
	   when PUSH_RDH32 => 
	    -- RDH3 & RDH2 
	    s_dw_datapath.data <= RDH(3)& RDH(2);                   -- header#32
	    s_dw_datapath.valid <= '1';
	   when PUSH_PLOAD => 
	    -- PLOAD 
	    if select_out /= c_NULL then 
	     s_dw_datapath.data  <= s_gbt_datapath(s_indexID).data;   -- gbt#x HBF data
	     s_dw_datapath.valid <= s_gbt_datapath(s_indexID).valid;  -- gbt#x HBF data
	    end if;
	   when others => null;
	  end case;
	 end if;
    end process p_state_out;
	--=============================================================================
	-- Begin of p_dw_page_cnt  
	-- This process counts the number of page countained within a heartbeat frame 
	--=============================================================================
	p_dw_page_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
      if state = IDLE then   
	   s_dw_page_cnt <= (others => '0');                           -- reset page counter 
	  elsif state = PUSH_RDH32 then 
	   s_dw_page_cnt <= s_dw_page_cnt+1;                           -- increment page counter for every RDH
	  end if;
	 end if; 
	end process p_dw_page_cnt;
	--=============================================================================
	-- Begin of p_dw_packet_cnt  
	-- This process counts the number of packet pushed during a heartbeat frame
	-- including the RDH. The counter is reset after reaching 256 packets 
	--=============================================================================
	p_dw_packet_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  if reset_i = '1' then
	   s_dw_packet_cnt <= (others => '0');
	  else 
	   -- initialization
	   if state = PUSH_RDH32 then
	    s_dw_packet_cnt  <= x"0003";
	   -- increment	
	   elsif state = PUSH_PLOAD then
        s_dw_packet_cnt <= s_dw_packet_cnt + 1;
	   end if;
	  end if; 
	 end if;
	end process p_dw_packet_cnt;  
	--=============================================================================
	-- Begin of p_pkt_cnt
	-- This process is used to count the number of packet transmitted to the dwrapper
	--=============================================================================
	p_pkt_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_dw_datapath_cnt <= (others => '0');
	  else
	   if s_dw_datapath_cnt = c_MAX_PACKET then 
		s_dw_datapath_cnt <= (others => '0');          -- reset
	   elsif s_dw_datapath.valid = '1' then
		s_dw_datapath_cnt <= s_dw_datapath_cnt+1;      -- increment
	   end if;
	  end if;
	 end if;
	end process p_pkt_cnt;

	-- gbt access ready 
	s_gbt_access_rdy <= '1' when s_gbt_access_req = s_gbt_access_ena else '0';

	-- FSM status 
	s_dw_fsm_monit <= x"00" when state = IDLE         else -- 0000_0000
			          x"01" when state = HDR_VAL      else -- 0000_0001
			          x"02" when state = ACCESS_RDY   else -- 0000_0010
			          x"04" when state = PUSH_GAP     else -- 0000_0100
			          x"08" when state = PUSH_RDH10   else -- 0000_1000
			          x"10" when state = PUSH_RDH32   else -- 0001_0000 
				      x"20" when state = ACCESS_PLOAD else -- 0010_0000 
				      x"40" when state = PUSH_PLOAD   else -- 0100_0000 
					  x"FF";                               -- 1111_1111 --> error !!!

	-- avalon gbt monitor
	av_gbt_monit_o   <= s_av_gbt_monit;
	-- avalon packet monitor
	av_dw_monit_o   <= std_logic_vector(s_dw_datapath_cnt) & x"0" & "0" & s_header.cnt & s_dw_fsm_monit; 
	-- datapath output
	dw_datapath_o.sop   <= s_dw_datapath.sop;
	dw_datapath_o.eop   <= s_dw_datapath.eop;
	dw_datapath_o.data  <= s_dw_datapath.data;
	dw_datapath_o.valid <= s_dw_datapath.valid;

end rtl;
--===========================================================================--
-- architecture end
--============================================================================--