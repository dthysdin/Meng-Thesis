-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File	     : event_mux.vhd
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
-- <27/08/2021> add monitoring
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
--Entity declaration for event_mux
--=============================================================================
entity event_mux is
	generic (g_LINK_ID : integer; g_REGIONAL_ID : integer);
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
	eox_pulse_i   : in std_logic;
	sel_pulse_i   : in std_logic;
	tfm_pulse_i   : in std_logic;
	ttc_mode_i    : in t_mid_mode;	
	-------------------------------------------------------------------
	-- packetizer info --
	packet_full_i : in std_logic;
	-------------------------------------------------------------------
	-- mid sync --
	mid_sync_i    : in std_logic_vector(11 downto 0);
	-------------------------------------------------------------------
	-- mid gbt elink data --								 	
	gbt_val_i     : in std_logic;
	gbt_data_i    : in std_logic_vector(39 downto 0);			
	-------------------------------------------------------------------	
    -- monitoring info --
	elink_monitor_o : out t_mid_elink_monit;
	-------------------------------------------------------------------
	-- muxtiplexer data info --
	mux_val_o     : out std_logic;
	mux_stop_o    : out std_logic;
	mux_data_o    : out std_logic_vector(7 downto 0)
	------------------------------------------------------------------------
	);  
end event_mux;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of event_mux is
	-- ========================================================
	-- type declarations
	-- ========================================================
	-- --------------------------------------------------
	-- SYMBOLIC ENCODED state machine: t_event_mux_state
	-- --------------------------------------------------
	type t_event_mux_state is (IDLE, 
                               REG_READY, 
                               DECODE_REG,
                               LOC_READY, 
                               MUX_LOC, 
                               DECODE_LOC); 

	signal state : t_event_mux_state; 
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant MAX_REG_TIME   : integer := 6;
	constant MAX_LOC_TIME   : integer := 22;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_loc_tx_data    : std_logic_vector(175 downto 0);             -- local tx data + crateID (additional byte as per Diego's requirement)
	signal s_loc_rx_data    : t_mid_Array168bit(3 downto 0);	          -- local rx data
	signal s_loc_rx_val 	: std_logic_vector(3 downto 0);               -- local rx valid 
	signal s_loc_rdreq      : std_logic_vector(3 downto 0);               -- local request 
	signal s_locID          : integer range 0 to 3 := 0;	              -- local ID 
	signal s_loc_select     : std_logic_vector(3 downto 0) := x"0";       -- local board select 
	--
	signal s_reg_rdreq	    : std_logic;                                  -- regional read
	signal s_reg_tx_data    : std_logic_vector(47 downto 0);              -- regional tx data + crateID (additional byte as per Diego's requirement)
	signal s_reg_rx_val 	: std_logic;                                  -- regional rx valid 
	signal s_reg_rx_data    : std_logic_vector(39 downto 0);              -- regional rx data
	--

	signal s_active_sox     : std_logic_vector(4 downto 0);               -- active sox elinks 
	signal s_inactive_eox   : std_logic_vector(4 downto 0);               -- inactive elinks
	signal s_empty          : std_logic_vector(4 downto 0);               -- empty elink based on active_sox 
	signal s_afull          : std_logic_vector(4 downto 0);               -- afull elink based on active_sox 
	signal s_crateID        : std_logic_vector(3 downto 0);               -- crate ID   
	signal s_crateID_val    : std_logic;                                  -- crate ID valid
	--
	signal s_temp_missing_event_cnt : t_mid_Array12bit(4 downto 0);       -- temporary missing events counter 
	signal s_missing_event_cnt: unsigned(11 downto 0) := (others => '0'); -- missing events counter 
	-- 
	signal s_mux_val        : std_logic;                                  -- temporary mux valid
	signal s_mux_data       : std_logic_vector(7 downto 0);               -- temporary mux data
	
	-- data acquisittion 
	signal s_daq_enable     : std_logic := '0';                           -- daq enable 
	signal s_daq_pause      : t_mid_daq_handshake_array(4 downto 0);      -- daq pause 
	signal s_daq_resume     : t_mid_daq_handshake;                        -- daq resume  
	signal s_resuming       : t_mid_daq_handshake;                        -- daq is resuming  
	signal s_waiting        : std_logic;
	signal s_index	        : integer range 0 to 21 := 0;                 -- index counter  

	signal s_daq_resume_orb : std_logic;
	signal s_daq_resume_orb_delay : std_logic_vector(4 downto 0) := "00000";

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
		generic map (g_LINK_ID => g_LINK_ID, g_REGIONAL_ID => g_REGIONAL_ID, g_LOCAL_ID => i)
		port map ( 
		clk_240	           => clk_240,
		--
		reset_i	           => reset_i,
		--
		daq_enable_i       => s_daq_enable, 
		daq_resume_i       => s_daq_resume, 
		daq_pause_o        => s_daq_pause(i),
		--
		gbt_val_i          => gbt_val_i,
		gbt_data_i         => gbt_data_i(7+8*i downto 8*i),
		--
		mid_sync_i         => mid_sync_i,
		--
		ttc_mode_i         => ttc_mode_i,		
		--
		loc_rdreq_i        => s_loc_rdreq(i),
		--
		loc_val_o          => s_loc_rx_val(i),
		loc_data_o         => s_loc_rx_data(i),
		loc_afull_o        => s_afull(i),
		loc_empty_o        => s_empty(i),
		loc_active_o       => s_active_sox(i),
		loc_inactive_o     => s_inactive_eox(i),
		loc_missing_o      => s_temp_missing_event_cnt(i));
		
	end generate LOC_GEN;
	--=====================--
	-- REGIONAL ELINKS 	--
	--=====================--
	regional_elink_inst: regional_elink
	generic map ( g_LINK_ID => g_LINK_ID, g_REGIONAL_ID => g_REGIONAL_ID)
	port map ( 
	clk_240	           => clk_240,
	--
	reset_i	           => reset_i,
	--
	daq_enable_i       => s_daq_enable, 
	daq_resume_i       => s_daq_resume, 
	daq_pause_o        => s_daq_pause(4),
	--
	gbt_val_i          => gbt_val_i,
	gbt_data_i         => gbt_data_i(39 downto 32),
	--
	ttc_mode_i         => ttc_mode_i,
	--
	mid_sync_i         => mid_sync_i,
	--
	reg_rdreq_i        => s_reg_rdreq,
	--
	reg_val_o          => s_reg_rx_val,
	reg_data_o         => s_reg_rx_data,
	reg_afull_o        => s_afull(4),
	reg_empty_o        => s_empty(4),
	reg_active_o       => s_active_sox(4),
	reg_inactive_o     => s_inactive_eox(4),
	reg_missing_o      => s_temp_missing_event_cnt(4),
	reg_crateID_o      => s_crateID,
	reg_crateID_val_o  => s_crateID_val);
	
	--=============================================================================
	-- Begin of p_daq_enable
	-- This process enables and disables the daq valid signal.
	-- This signal enables the collection of data from various e-links 
	-- This signal is "ON" after receiving the sox pulse from the TTC and "OFF"
	-- after receiving the the eox trigger from all 
	--=============================================================================
	p_daq_enable: process(clk_240)
	begin
	 if rising_edge(clk_240) then
	  if reset_i = '1' then
	   s_daq_enable <= '0'; 
	  else 
	   -- sox pulse (run is starting)
	   if sox_pulse_i = '1' then 
        s_daq_enable <= '1'; 
       -- daq is close (run is ending)
       elsif s_daq_resume.close = '1' then 
        s_daq_enable <= '0'; 
	   end if;
	  end if;
	 end if;
	end process p_daq_enable;	
	--=============================================================================
	-- Begin of p_daq_orb
	-- This process resumes the data acquisition process.
	--=============================================================================
	p_daq_orb: process(clk_240)
	 variable v_pause_orb   : std_logic_vector(4 downto 0);

	begin

	 if rising_edge(clk_240) then
      -- default 
	  s_daq_resume_orb <= '0';

	  if reset_i = '1' then
       s_resuming.orb   <= '0';
	   v_pause_orb := (others => '0');
	  else 

	   -- pause encoder
	   for i in 0 to 4 loop 
	    v_pause_orb(i)   := s_daq_pause(i).orb;  
	   end loop;

       -- ### timeframe -- 
	   if tfm_pulse_i = '1'  then 
        s_resuming.orb <= '1';
	   -- sel pulse --
	   elsif sel_pulse_i = '1' then 
	    -- urgent release
	    if s_resuming.orb = '1' then 
		 s_daq_resume_orb <= '1';
		 s_resuming.orb <= '0';
		end if;
       -- wait for cards to resume 
       elsif s_resuming.orb = '1' then 
        if s_waiting = '1' and v_pause_orb = s_active_sox then
		  s_daq_resume_orb <= '1';
		  s_resuming.orb <= '0';  
		end if;
	   end if;
	  end if;
	 end if;
	end process p_daq_orb;

	-- waiting data state 
	s_waiting <= '1' when state = IDLE and s_daq_enable = '1' and s_empty = "11111" else '0';
	--=============================================================================
	-- Begin of p_shift_register
	-- This process 
	--=============================================================================
	p_shift_register: process(clk_240)
   begin 
	if rising_edge(clk_240) then
	 -- shift register <<<<
	 s_daq_resume_orb_delay <= s_daq_resume_orb_delay(3 downto 0) & s_daq_resume_orb; 
	 s_daq_resume.orb <= s_daq_resume_orb_delay(4);                       
	end if;
   end process p_shift_register;
    --=============================================================================
	-- Begin of p_daq_eox
	-- This process resumes the data acquisition process.
	--=============================================================================
	p_daq_eox: process(clk_240)
	 variable v_pause_eox   : std_logic_vector(4 downto 0);
	 variable v_pause_close : std_logic_vector(4 downto 0);

   begin

	if rising_edge(clk_240) then
	 -- default 
	 s_daq_resume.eox   <= '0';
	 s_daq_resume.close <= '0';

	 if reset_i = '1' then
	  s_resuming.eox   <= '0';
	  s_resuming.close <= '0';
	 else 

	  -- pause encoder
	  for i in 0 to 4 loop  
	   v_pause_eox(i)   := s_daq_pause(i).eox;
	   v_pause_close(i) := s_daq_pause(i).close;
	  end loop;

	  -- eox pulse -- 
	  if eox_pulse_i = '1' then 
	   s_resuming.eox <= '1';
	  -- wait for cards to resume 
	  elsif s_resuming.eox = '1' then 
	   if s_waiting = '1' and v_pause_eox = s_active_sox then 
		s_daq_resume.eox <= '1';
		s_resuming.eox <= '0';
		s_resuming.close <= '1';
	   end if;
	  -- wait for cards to close 
	  elsif s_resuming.close = '1' then
	   if s_waiting = '1' and v_pause_close = s_active_sox then 
		s_daq_resume.close <= '1';
		s_resuming.close <= '0';
	   end if;
	  end if;
	 end if;
	end if;
   end process p_daq_eox;
	--=============================================================================
	-- Begin of p_locID
	-- This process assigns the local ID
	--=============================================================================
	p_locID: process(clk_240)
	begin
        if rising_edge(clk_240) then
          -- look ahead local ID
          if state = MUX_LOC then 
		   if packet_full_i /= '1' then
            case s_afull(3 downto 0) is 
		     when x"0" => 
			  -- local buffer empty
			  if s_empty(3) /= '1' then 
			   s_locID <= 3;
			  elsif s_empty(2) /= '1' then
			   s_locID <= 2;
			  elsif s_empty(1) /= '1' then
			   s_locID <= 1; 
			  elsif s_empty(0) /= '1' then
			   s_locID <= 0;
			  end if;

			 when others => 
			  -- local buffers full
			  if s_afull(3) = '1' then 
			   s_locID <= 3;
			  elsif s_afull(2) = '1' then
			   s_locID <= 2;
			  elsif s_afull(1) = '1' then
			   s_locID <= 1; 
			  elsif s_afull(0) = '1' then
			   s_locID <= 0;
			  end if;
             end case;
			end if;
          end if;
        end if;
    end process p_locID;	
	--=============================================================================
	-- Begin of p_read_loc
	-- This process assigns the local read request
	--=============================================================================

	p_read_loc: process(state, s_afull, s_empty, packet_full_i)
	begin
     -- default 
     s_loc_rdreq <= x"0";

     if state = MUX_LOC then 
	  if packet_full_i /= '1' then
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
     end if;
	end process p_read_loc;

	-- Request regional data from fifo
	s_reg_rdreq <=  '1' when state = IDLE and packet_full_i /= '1'  and s_daq_enable = '1' and s_crateID_val = '1' and s_empty(4) /= '1' else '0';
	--=============================================================================
	-- Begin of p_missing_event_cnt
	-- This process adds the number of events rejected from 4 elinks during the daq
	--=============================================================================
	p_missing_event_cnt: process(clk_240)
	 variable sum_out : unsigned(11 downto 0);
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   -- initial condition
	   s_missing_event_cnt <= (others => '0');
	  else 
	   -- maximum counter
	   if s_missing_event_cnt /= x"FFF" then 
	    -- default 
	    sum_out := (others => '0');
	    -- add counters
        for i in s_temp_missing_event_cnt'reverse_range loop
         sum_out := sum_out + unsigned(s_temp_missing_event_cnt(i));
	    end loop;
	    -- result
	    s_missing_event_cnt <= sum_out;
	   end if;
	  end if;
     end if;
	end process p_missing_event_cnt;
	--=============================================================================
	-- Begin of p_state
	-- This process contains a sequential state machine
	--=============================================================================
    -- state fsm
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
	    if s_daq_enable = '1' then 
		 if packet_full_i /= '1' and s_crateID_val = '1' then 
	      if s_empty(4) /= '1' then
	       state <= REG_READY;	                -- regional 
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
	    if packet_full_i /= '1' then
		 if s_empty(3 downto 0) /= x"F" then 
	      state <= LOC_READY;
		 else 
		  state <= IDLE;
		 end if;
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
		-----------------
	    -- errors --
        ----------------		
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
	  
	  -- multiplexer 
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
	mux_val_o    <= s_mux_val;
	mux_data_o   <= s_mux_data;                           -- fee data byte 
	mux_stop_o   <= s_daq_resume.eox or s_daq_resume.orb; -- update  during the end of run
	
	elink_monitor_o.inactive_cards    <= s_inactive_eox;                           -- inactive cards (eox acknowledge)
	elink_monitor_o.active_cards      <= s_active_sox;                             -- active cards (sox acknowledge)
	elink_monitor_o.missing_event_cnt <= std_logic_vector(s_missing_event_cnt);    -- total number of event missing 
	elink_monitor_o.crateID           <= s_crateID;                                -- crate ID where the data originated  
	elink_monitor_o.pending_cards     <= '1' when s_empty /= "11111" else '0';     -- data pending in one of the card  buffers
	elink_monitor_o.daq_enable        <= s_daq_enable;         
	elink_monitor_o.fsm               <= x"0" when state = IDLE       else
	                                     x"1" when state = REG_READY  else 
								         x"2" when state = DECODE_REG else  
								         x"3" when state = LOC_READY  else 
								         x"4" when state = MUX_LOC    else 
								         x"5" when state = DECODE_LOC else 
								         x"f"; --  state corrumpted 


end rtl;
--=============================================================================
-- architecture end
--=============================================================================