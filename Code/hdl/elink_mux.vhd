-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File	     : elink_mux.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-27
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 2.0
-------------------------------------------------------------------------------
-- last changes
-- <30/06/2020> change signal names and decrease buffer sizes
-- <28/09/2020> add a pipeline on the state output to meet the timing requirements 
-- <13/10/2020> change the some part of the code to make it more compact
-- <04/12/2020> stop the DAQ for every heartbeat and EOx trigger
-- <05/12/2020> reset the module for every sox trigger
-- <11/12/2020> synchronize the heartbeat frames 
-- <13/02/2021> add active output port 
-------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to multiplex incoming data from 4 elink buffers
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for elink_mux
--=============================================================================
entity elink_mux is
	generic (g_REGIONAL_ID : integer := 0; g_NUM_HBFRAME_SYNC: integer := 256; g_LINK_ID : integer := 0);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240	      : in std_logic;					
	-------------------------------------------------------------------
	-- reset --  
	reset_i       : in std_logic;
	-------------------------------------------------------------------
	-- ttc pulse 
	sox_pulse_i   : in std_logic;	
	-- ttc mode
	ttc_mode_i    : in t_mid_mode;	
	-------------------------------------------------------------------
	-- packetizer info --
	packet_full_i : in std_logic;
	-------------------------------------------------------------------
	-- mid gbt elink data --						
	gbt_data_i    : in std_logic_vector(39 downto 0);		 
	gbt_val_i     : in std_logic;				
	-------------------------------------------------------------------	
    	-- e-link status  
	active_o      : out std_logic_vector(4 downto 0);
	crateID_o     : out std_logic_vector(3 downto 0);
	missing_cnt_o : out std_logic_vector(11 downto 0);
	-------------------------------------------------------------------
	-- muxtiplexer data info --
	mux_val_o     : out std_logic;
	mux_stop_o    : out std_logic;
	mux_data_o    : out std_logic_vector(7 downto 0)
	------------------------------------------------------------------------
	);  
end elink_mux;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of elink_mux is
	-- ========================================================
	-- type declarations
	-- ========================================================
	-- --------------------------------------------------
	-- SYMBOLIC ENCODED state machine: t_elink_mux_state
	-- --------------------------------------------------
	type t_elink_mux_state is (IDLE, 
                                   REG_READY, 
                                   DECODE_REG,
                                   LOC_READY, 
                                   MUX_LOC, 
                                   DECODE_LOC); 					
	signal state : t_elink_mux_state; 
        --
	type t_num_loc is range 0 to 3; -- number of local boards
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant MAX_REG_TIME   : integer := 6;
	constant MAX_LOC_TIME   : integer := 22;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_loc_tx_data    : std_logic_vector(175 downto 0);  -- local tx data + crateID (additional byte as per new requirement)
	signal s_loc_rx_data    : t_mid_loc_array(3 downto 0);	   -- local rx data
	signal s_loc_rx_val 	: std_logic_vector(3 downto 0);    -- local rx valid 
	signal s_loc_rdreq      : std_logic_vector(3 downto 0);    -- local request 
	signal s_locID          : integer range 0 to 3 := 0;	   -- local ID 
	signal s_loc_select     : std_logic_vector(3 downto 0) := x"0"; -- local board select 
	--
	signal s_reg_rdreq	    : std_logic;                   -- regional read
	signal s_reg_tx_data    : std_logic_vector(47 downto 0);   -- regional tx data + crateID (additional byte as per new requirement)
	signal s_reg_rx_val 	: std_logic;                       -- regional rx valid 
	signal s_reg_rx_Data    : std_logic_vector(39 downto 0);   -- regional rx data
	--
	signal s_active	        : std_logic_vector(4 downto 0);    -- active elinks
	signal s_inactive       : std_logic_vector(4 downto 0);    -- inactive elinks
	signal s_empty          : std_logic_vector(4 downto 0);    -- empty elink memories
	signal s_afull          : std_logic_vector(4 downto 0);    -- afull elink memories
	signal s_orb_pause      : std_logic_vector(4 downto 0);    -- orbit event pause
	signal s_eox_pause      : std_logic_vector(4 downto 0);    -- eox event pause
	signal s_crateID        : std_logic_vector(3 downto 0);    -- crate ID  
	signal s_crateID_val    : std_logic;                       -- crate ID valid 
	--
	signal s_temp_missing_cnt : t_mid_missing_cnt_array(4 downto 0);      -- temporary missing events counter 
	signal s_missing_cnt      : unsigned(11 downto 0) := (others => '0'); -- missing events counter 
	-- 
	signal s_mux_val        : std_logic;                       -- temporary mux valid
	signal s_mux_data       : std_logic_vector(7 downto 0);    -- temporary mux data
	
	-- data acquisittion 
	signal s_daq_stop       : std_logic;                       -- stop daq 
	signal s_daq_resume     : std_logic;                       -- resume daq 
	signal s_daq_valid      : std_logic := '0';                -- valid daq 
	--  
	signal s_index	        : integer range 0 to 21 := 0;      -- index counter  
	
--=============================================================================
-- architecture begin
--=============================================================================
begin
	--=============================================================================
	-- Begin of LOC_GEN
	-- This statement generates the port mapping of 4 local boards
	--=============================================================================
	LOC_GEN : for i in 0 to 3 generate		 
		--==============--
		-- LOCAL ELINKS --
		--==============--
		local_elink_inst: local_elink 
		generic map (g_NUM_HBFRAME_SYNC => g_NUM_HBFRAME_SYNC)
		port map ( 
		clk_240	       => clk_240,
		--
		reset_i	       => reset_i,
		--
		daq_stop_i     => s_daq_stop,
		daq_valid_i    => s_daq_valid,
      		daq_resume_i   => s_daq_resume,
		--
		orb_pause_o    => s_orb_pause(i),
      		eox_pause_o    => s_eox_pause(i),
		--
		gbt_data_i     => gbt_data_i(7+8*i downto 8*i),
		gbt_val_i      => gbt_val_i,
		--
		ttc_mode_i     => ttc_mode_i,		
		--
		loc_rdreq_i    => s_loc_rdreq(i),
		--
		loc_val_o      => s_loc_rx_val(i),
		loc_data_o     => s_loc_rx_data(i),
		loc_missing_o  => s_temp_missing_cnt(i),
		loc_afull_o    => s_afull(i),
		loc_empty_o    => s_empty(i),
		loc_active_o   => s_active(i),
		loc_inactive_o => s_inactive(i));
		
	end generate LOC_GEN;
	--=====================--
	-- REGIONAL ELINKS 	--
	--=====================--
	regional_elink_inst: regional_elink
	generic map (g_REGIONAL_ID => g_REGIONAL_ID, g_NUM_HBFRAME_SYNC => g_NUM_HBFRAME_SYNC, g_LINK_ID => g_LINK_ID)
	port map ( 
	clk_240	          => clk_240,
	--
	reset_i	          => reset_i,
	--
	daq_stop_i        => s_daq_stop,
	daq_valid_i       => s_daq_valid,
	daq_resume_i      => s_daq_resume,
	--
	orb_pause_o       => s_orb_pause(4),
	eox_pause_o       => s_eox_pause(4),
	--
	gbt_data_i        => gbt_data_i(39 downto 32),
	gbt_val_i         => gbt_val_i,
	--
	ttc_mode_i        => ttc_mode_i,
	--
	reg_rdreq_i       => s_reg_rdreq,
	--
	reg_val_o         => s_reg_rx_val,
	reg_data_o        => s_reg_rx_data,
	reg_afull_o       => s_afull(4),
	reg_empty_o       => s_empty(4),
	reg_active_o      => s_active(4),
	reg_inactive_o    => s_inactive(4),
	reg_missing_o     => s_temp_missing_cnt(4),
	reg_crateID_o     => s_crateID,
	reg_crateID_val_o => s_crateID_val);
	
	--=============================================================================
	-- Begin of p_valid_daq
	-- This process enables and disables the daq valid signal.
	-- This signal enables the collection of data from various e-links 
	-- This signal is "ON" after receiving the sox pulse from the TTC and "OFF"
	-- after receiving the the eox trigger from all 
	--=============================================================================
	p_valid_daq: process(clk_240)
	begin
	 if rising_edge(clk_240) then
	  if reset_i = '1' then
	   s_daq_valid <= '0'; -- initial
	  else 
	   -- run has started
	   if sox_pulse_i = '1' then 
            s_daq_valid <= '1'; -- 
	   -- run is finished 
           elsif s_daq_stop = '1' then 
            s_daq_valid <= '0'; 
	   end if;
	  end if;
	 end if;
	end process p_valid_daq;	
	--=============================================================================
	-- Begin of p_end_daq
	-- This process resumes and ends the DAQ.
	--=============================================================================
	p_end_daq: process(clk_240)
	begin
	 if rising_edge(clk_240) then
          -- default 
	  s_daq_resume <= '0';
	  s_daq_stop <= '0';
	  
	  -- valid DAQ 
	  if s_daq_valid = '1' and s_empty = "11111" and state = IDLE then
           if s_daq_resume /= '1' and s_daq_stop /= '1' then 
	    -- resume DAQ "timeframe frame completed"
	    if s_active = s_orb_pause and s_orb_pause /= "00000" then 
             s_daq_resume <= '1';
	    -- stop DAQ "run completed"
	    elsif s_active = s_inactive and s_eox_pause /= "00000" then 
	     s_daq_stop <= '1';
	    end if;
	   end if;
	  end if;
	 end if;
	end process p_end_daq;
	--=============================================================================
	-- Begin of p_locID
	-- This process assigns the local ID
	--=============================================================================
	p_locID: process(clk_240)
         -- declare variable 
         variable highest_locID : t_num_loc := 3;
	begin
         if rising_edge(clk_240) then
          -- look ahead local ID
          -- Notice that the variable is assigned multiple times. 
          -- However as the loop is executed in increasing order (0 to 3), the last (highest) assignment wins.
          -- This priority encoder is based on the status of empty and afull signals.

          if state = MUX_LOC then 
           if s_afull = x"0" then  
            for i in t_num_loc loop 
             if s_empty(i) /= '1' then
              highest_locID := i;
             end if;
            end loop;
           else 
            for i in t_num_loc loop 
             if s_sfull(i) = '1' then
              highest_locID := i;
             end if;
            end loop;
           end if;
           s_locID <= highest_locID; -- store the highest_locID 
          end if;
         end if;
        end process p_locID;	
	--=============================================================================
	-- Begin of p_read_loc
	-- This process assigns the local read request
	--=============================================================================

	p_read_loc: process(state, s_afull, s_empty)
	begin
         -- default 
         s_loc_rdreq <= x"0";

         if state = MUX_LOC then 
	  -- asynchronize read local
	  case s_afull(3 downto 0) is 
          -- priority encoder based on the empty signals
	  -- provided by each fifo
	  when x"0" => 
	   -- empty
	   if s_empty(3) /= '1' then 
	    s_loc_rdreq <= x"8";
	   elsif s_empty(2) /= '1' then
	    s_loc_rdreq <= x"4";
	   elsif s_empty(1) /= '1' then
	    s_loc_rdreq <= x"2"; 
	   elsif s_empty(0) /= '1' then
	    s_loc_rdreq <= x"1";
	   end if;
	  -- priority encoder based on the afull signals
	  -- provided by each fifo
          when others => 
	   -- afull
	   if s_afull(3) = '1' then 
		s_loc_rdreq <= x"8";
	   elsif s_afull(2) = '1' then
		s_loc_rdreq <= x"4";
	   elsif s_afull(1) = '1' then
		s_loc_rdreq <= x"2"; 
	   elsif s_afull(0) = '1' then
		s_loc_rdreq <= x"1";
	   end if;
          end case;
         end if;
	end process p_read_loc;

	-- Request regional data from fifo
	s_reg_rdreq <=  '1' when state = IDLE and packet_full_i /= '1' and s_empty(4) /= '1' and s_daq_valid = '1' and s_crateID_val = '1' else '0';
	--=============================================================================
	-- Begin of p_missing_cnt
	-- This process adds the number of events rejected from 4 elinks during the daq
	--=============================================================================
	p_missing_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_missing_cnt <= (others => '0');
	  else 
	   if s_missing_cnt /= x"FFF" then 
	    s_missing_cnt <= sum_Array12bit(s_temp_missing_cnt); -- call function <sum_Array12bit>
	   end if;
	  end if;
     end if;
	end process p_missing_cnt;
	--=============================================================================
	-- Begin of p_state
	-- This process contains a sequential state machine
	--=============================================================================
	p_state: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
      if reset_i = '1' then 
	   state <= IDLE;
      else 

	   -- case state --
       case state is
       --========
	   -- IDLE --
	   --========
	   when IDLE =>
	    -- valid DAQ
	    if packet_full_i /= '1' and  s_daq_valid = '1'then 
		 if s_crateID_val = '1' then 
	      if s_empty(4) /= '1' then
	       state <= REG_READY;	                 -- regional 
	      elsif s_empty(3 downto 0) /= x"F" then
	       state <= MUX_LOC;                     -- local 
	      end if;
		 end if;
	    end if;
	   --================
       -- REGIONAL READY --
	   --================
	   -- state "REG_READY"	
	   when REG_READY  => 
	    if s_reg_rx_val = '1' then 
	     state <= DECODE_REG;
        end if;
	   --===================
       -- DECODE REGIONAL --
	   --===================
	   -- state "DECODE_REG"	
	   when DECODE_REG =>
	    if s_index = 5 then
	     -- maximum regional index 
	     if s_empty(4) = '1' and s_empty(3 downto 0) /= x"F" then 
	      state <= MUX_LOC;		
	     else 
	      state <= IDLE;
	     end if;
	    end if;
	   --===================
	   -- MUTIPLEX LOCALS --
	   --===================
	   -- state "MUX_LOC"	
	   when MUX_LOC  =>
	    if s_empty(3 downto 0) /= x"F" then 
	     state <= LOC_READY;
	    else
	     state <= IDLE;
	    end if;
	   --==============
	   -- LOCAL READY --
	   --==============
	   -- state "LOC_READY"	
	   when LOC_READY  => 
	    if s_loc_rx_val /= x"0" then
	     state <= DECODE_LOC;
	    end if;
	   --================
	   -- DECODE LOCAL --
	   --================
	   -- state "DECODE_LOC"	
	   when DECODE_LOC => 
	    case s_index is 
	    when 5 => 
	     -------------
	     -- No strip --
	     -------------
	     -- fifth byte  
         if s_loc_select = x"0" then
	      -- no strip patterns 
	      if s_locID = 0 and s_afull(4) = '1' then 
	       state <= IDLE;
	      else
	       state <= MUX_LOC;
	      end if;
	     end if;		
	    when 9 => 
	     ---------------
	     -- 1 chamber --
	     ---------------
             -- nineth byte 
	     case s_loc_select is 
	     when x"1"|x"2"|x"4"|x"8" =>
	      -- change state
	      if s_locID = 0 and s_afull(4) = '1' then 
	       state <= IDLE;
	      else
	       state <= MUX_LOC;
	      end if;
	     when others => null;
	     end case;		
	    when 13 => 
	     ----------------
	     -- 2 chambers --
	     ----------------             
	     -- thirdteenth byte 
	     case s_loc_select  is 
	     when x"3"|x"5"|x"6"|x"9"|x"A"|x"C" =>
	      -- change state 
	      if s_locID = 0 and s_afull(4) = '1' then 
	       state <= IDLE;
	      else 
	       state <= MUX_LOC;
              end if;
	     when others => null;
	     end case;
        when 17 => 
	     ----------------
	     -- 3 chambers --
	     ----------------              
	     -- seventeenth byte 
	     case s_loc_select  is 
	     when x"7"|x"B"|x"E" =>
	      -- change state
	      if s_locID = 0 and s_afull(4) = '1' then 
	       state <= IDLE;
	      else 
	       state <= MUX_LOC;
	      end if;
	     when others => null;
	     end case;
	    when 21 => 
        -----------------
	    -- 4 chambers --
        ----------------            
	    -- twenty-first byte 
	     if s_locID = 0 and s_afull(4) = '1' then 
	      state <= IDLE;
	     else 
	      state <= MUX_LOC;
	     end if;	
         when others => null;
         end case;			
        when others =>
	    -- all the other states (not defined)
	    -- jump to save state (ERROR?!)
	    state <= IDLE;
	   end case;
	  end if;
 	 end if;
	end process p_state;
	--=============================================================================
	-- Begin of p_index 
	-- This process increments  and resets the index counter  
	-- This index is used to count the number of clock cycles spent on the 
	-- REG_DECODE and LOC_DECODE states. Each clock corresponds to 1 byte decoded
	-- It resets after reaching the maximum reg_time or loc_time
	--============================================================================= 
	p_index: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  if reset_i = '1' then
       s_index <= 0;
	  else 
	   -- DECODE REGIONAL --	
	   if state =  DECODE_REG then 
	    if s_index = MAX_REG_TIME-1 then 	 
	     s_index <= 0;           -- reset
	    else 	 
	     s_index <= s_index + 1; -- increment
	    end if;

       -- DECODE LOCALS --	
	   elsif state = DECODE_LOC then  		
	    if s_index = MAX_LOC_TIME-1 then 
	     s_index <= 0;           -- reset 
	    else  
	     s_index <= s_index + 1; -- increment 
	    end if;

	   -- OTHERS --
	   else  
	    s_index <= 0;
	   end if; -- state 
	  end if; -- reset
	 end if; -- clock
	end process p_index; 
	--=============================================================================
	-- Begin of p_txdata_reg
	-- This process stores local and regional data into registers  
	--=============================================================================
	p_txdata_reg: process(clk_240)
	begin
	 if rising_edge(clk_240) then
	  -- regional tx data register  
	  if s_reg_rx_val = '1' and state = REG_READY then 
	   s_reg_tx_data <= s_reg_rx_data & s_crateID & x"0";                                                                 
	  end if;

	  -- local tx data mux register (locID varies from 0 ~ 3) 
	  if s_loc_rx_val /= x"0" and state = LOC_READY then
	   s_loc_tx_data <= s_loc_rx_data(s_locID)(167 downto 128) & s_crateID & x"0" & s_loc_rx_data(s_locID)(127 downto 0);                     
	   s_loc_select <= s_loc_rx_data(s_locID)(131 downto 128);
	  end if;
	 end if;
	end process p_txdata_reg;
	--=============================================================================
	-- Begin of p_state_out
	-- This process contains the output logic of the state machine
	--=============================================================================
	p_state_out: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  -- default output --
	  s_mux_data	<= (others => '0');	
	  s_mux_val   <= '0';		
	  
	  -- mux 
	  case state is 
	  when DECODE_REG  =>
	   -- read byte fragments of the regional 
	   s_mux_data <= s_reg_tx_data(47-8*s_index downto 40-8*s_index);  
	   s_mux_val <= '1'; 
	
	  when DECODE_LOC => 		
	   -- read byte fragments of the extracted local
       s_mux_data <= s_loc_tx_data(175-s_index*8 downto 168-s_index*8); 
       s_mux_val <= '1'; 
	  when others => null;
	  end case; 
	 end if;
	end process p_state_out;

	-- output
	mux_val_o    <= s_mux_val;                      -- fee data byte valid 
	mux_data_o   <= s_mux_data;                     -- fee data byte 
	mux_stop_o   <= s_daq_resume or s_daq_stop;     -- update during timeframe transition or during the end of run
	 

	active_o     <= s_active;                       -- active cards 
	crateID_o    <= s_crateID;                      -- crate ID where data originated 
	missing_cnt_o <= std_logic_vector(s_missing_cnt);-- total number of event missing
	

end rtl;
--=============================================================================
-- architecture end
--=============================================================================