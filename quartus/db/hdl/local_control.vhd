-------------------------------------------------------------------------------
--  Cape Peninsula University of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : local_control.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-24
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes	
-- <29/09/2020> add output register
-- <13/10/2020> change the combitional fsm to sequencial
-- <28-11-2020> reset the module for every sox trigger
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to able to switch between the trigger mode and
-- the continuous mode.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
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
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for local_control
--=============================================================================
entity local_control is
	generic (g_LOCAL_ID : integer);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240	       : in std_logic;
	-------------------------------------------------------------------
	-- avalon + auto reset --
	reset_i        : in std_logic;
	-------------------------------------------------------------------
	-- data acquisition info --
	daq_enable_i   : in std_logic; 
	daq_resume_i   : in t_mid_daq_handshake;
	daq_pause_o    : out t_mid_daq_handshake;
	-------------------------------------------------------------------
	-- timing and trigger control mode --			 								
	ttc_mode_i     : in t_mid_mode;
	-------------------------------------------------------------------
	-- mid sync --	
	mid_sync_i     : in std_logic_vector(11 downto 0);
	-------------------------------------------------------------------
	-- timeframe config
	-------------------------------------------------------------------
	-- local card info --
	--< in 
	loc_val_i      : in std_logic;								
	loc_data_i     : in std_logic_vector(167 downto 0);	
	loc_full_i     : in std_logic;	
	loc_inactive_i : in std_logic;
	--> out 
	loc_val_o      : out std_logic;								
	loc_data_o     : out std_logic_vector(167 downto 0);
	loc_missing_o  : out std_logic_vector(11 downto 0);
	loc_active_o   : out std_logic;
	loc_overflow_o : out std_logic
	-------------------------------------------------------------------
	 );  
end local_control;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of local_control is
	-- =================================================
	-- SYMBOLIC ENCODED state machine: state_loc
	-- =================================================
	type t_loc_state is (IDLE,
                        START_RUN,
                        READY,
                        READOUT_MODE,
                        TRIGGER_MODE,
                        TRIGGER_MODE_FILTER, 
                        SEND, 
                        SEND_ORBIT,
                        SEND_EOX,
                        FINISH_RUN);
								
	signal state : t_loc_state := IDLE;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- local fifo 	
	signal s_loc_rdreq     : std_logic;
	signal s_loc_wrreq     : std_logic;
	signal s_loc_full      : std_logic;			
	signal s_loc_empty     : std_logic;	
	signal s_loc_rx_data   : std_logic_vector(167 downto 0);
	
	-- local fifo out tx pipelined 
	signal s_loc_tx_preval  : std_logic;
	signal s_loc_tx_val     : std_logic;
	signal s_loc_tx_ready   : std_logic;
	signal s_loc_tx_predata : std_logic_vector(167 downto 0):= (others => '0');
	signal s_loc_tx_data    : std_logic_vector(167 downto 0):= (others => '0');

	-- bcid 
	signal s_bcid_filter : std_logic;
	
	-- pause register '
	signal s_daq_pause   : t_mid_daq_handshake;
	
	-- temporary local register 
	signal s_temp_data  : std_logic_vector(167 downto 0);
	signal s_temp_val   : std_logic;
	
	-- readout mode 
	signal s_trg_mode   : std_logic := '0';	-- valid during FEE & TTC trigger mode 
	signal s_cont_mode  : std_logic := '0';	-- valid during FEE & TTC continuous mode 
	
	--
	signal s_active     : std_logic := '0';
	signal s_is_fee_eox : std_logic := '0';	-- valid after FEE EOx trigger 
	signal s_overflow   : std_logic := '0';	-- 

    signal s_fee_select : std_logic_vector(2 downto 0);                   -- FEE concatenation of (sox-orb-eox)
	signal s_fee_orbit_cnt : unsigned(11 downto 0) := (others => '0');    -- FEE orbit counter
	signal s_missing_cnt: unsigned(11 downto 0) := (others => '0');       -- FEE event missing counter

	-- ========================================================
	-- alias declarations
	-- ========================================================
	alias a_fee_sox	   : std_logic is s_loc_tx_data(159);		                         -- FEE sox 
	alias a_fee_eox	   : std_logic is s_loc_tx_data(158);		                         -- FEE eox 
	alias a_fee_physics: std_logic is s_loc_tx_data(154);		                         -- FEE physics trigger 
	alias a_fee_orbit  : std_logic is s_loc_tx_data(152);		                         -- FEE orbit
	alias a_fee_bc	   : std_logic_vector(15 downto 0) is s_loc_tx_data(151 downto 136); -- FEE bc
	
begin 
	--================================================--
	-- fifo for local card informations  168 bit x 64 words
	-- MLAB memory type (look ahead read mode)
	-- rdreq is used as read acknoledge 
	--=================================================--
	s_loc_wrreq <= loc_val_i and(not s_loc_full);                                       -- valid data when fifo not busy
	fifo_168x64_inst:fifo_168x64
	port map (
	data		=> loc_data_i,
	wrreq		=> s_loc_wrreq,
	rdreq		=> s_loc_rdreq,
	clock		=> clk_240,
	sclr		=> reset_i,
	q           => s_loc_rx_data,
	full		=> s_loc_full,
	empty		=> s_loc_empty);
	--=============================================================================
	-- Begin of p_fee_missing
	-- This process counts the number of events missing during the daq
	--=============================================================================
	p_fee_missing: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	  s_missing_cnt <= (others => '0');
	  else 
	   if s_missing_cnt /= x"FFF" then 
	    if loc_val_i = '1' and s_loc_full = '1' then
		 s_missing_cnt <= s_missing_cnt+1;
	    end if;
	   end if;
	  end if;
     end if;
	end process p_fee_missing;
	--===========================================================================
	-- Begin of p_loc_pipe
	-- pipeline to overcome the latency of the fifo (3 clk cycles)
	--===========================================================================
	-- extract the local word from the fifo
	s_loc_rdreq <= '1' when state = START_RUN and loc_full_i /= '1' and s_loc_empty /= '1' else '0'; 

	p_loc_pipe: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
      -- 3 stage pipeline 
      s_loc_tx_preval <= s_loc_rdreq;     -- 1st stage (local read_request becomes local preval)
      s_loc_tx_val    <= s_loc_tx_preval; -- 2nd stage (local preval beconmes local valid)
	  s_loc_tx_ready  <= s_loc_tx_val;    -- 3rd stage (local valid becomes local ready)
	 end if;
	end process p_loc_pipe;
	--===========================================================================
	-- Begin of p_loc_pipe_data
	-- pipeline data transfer to overcome the latency of the fifo (3 clk cycles)
	--===========================================================================
	p_loc_pipe_data: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_loc_tx_data <= (others => '0');
	  else 
	   -- local read_request
	   if s_loc_rdreq = '1' then 
	    s_loc_tx_predata <= s_loc_rx_data; -- fifo data 
	   -- local valid
	   elsif s_loc_tx_val = '1' then 
	    s_loc_tx_data <= s_loc_tx_predata; -- pipelined fifo data 
	   end if;
	  end if;
	 end if;
	end process p_loc_pipe_data;
	
	-- concatenate sox, orbit and eox 
	s_fee_select <= a_fee_sox & a_fee_orbit & a_fee_eox;
						  					
	-- bunch crossing ID filter 
	s_bcid_filter <= '1' when (unsigned(a_fee_bc) = unsigned(ttc_mode_i.triggered_data)) and  state /= IDLE else 
                     '1' when (unsigned(a_fee_bc)+1 = unsigned(ttc_mode_i.triggered_data)) and state /= IDLE else
                     '1' when (unsigned(a_fee_bc)-1 = unsigned(ttc_mode_i.triggered_data)) and state /= IDLE else '0';					
	--=============================================================================
	-- Begin of p_fee_eox
	-- This process stores the(EOx) from the FEE
	--=============================================================================
	p_fee_eox: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_is_fee_eox <= '0';
	  else 
	   -- fee eox event 
	   if a_fee_eox = '1' then
	    s_is_fee_eox <= '1'; 
	   -- fee sox event 
       elsif a_fee_sox = '1' then
	    s_is_fee_eox <= '0';
	   end if;
	  end if;
     end if;
	end process p_fee_eox;
	--==============================================================================
	-- Begin of p_readout_mode 
	-- This process selects the readout mode operation of the card
	--==============================================================================
	p_readout_mode: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_trg_mode <= '0';
	   s_cont_mode <= '0';
	  else 

	   -- Continuous mode -- 
	   if ttc_mode_i.continuous = '1' and a_fee_sox = '1' then 
	    s_cont_mode <= '1'; 		       -- active 	
	   elsif s_cont_mode = '1' and s_is_fee_eox = '1' then 
	    s_cont_mode <= '0'; 		       -- desactive  
		
       -- Trigger mode --	 
	   elsif ttc_mode_i.triggered = '1' and a_fee_sox = '1' then 
	    s_trg_mode <= '1'; 			-- active 	
	   elsif s_trg_mode = '1' and s_is_fee_eox = '1' then	
	    s_trg_mode <= '0'; 			-- desactive  
	   end if;

	  end if;	
	 end if;
	end process p_readout_mode;
	--=============================================================================
	-- Begin of p_state
	-- This process is a sequential state machine 
	--=============================================================================
	p_state: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then
	   state <= IDLE;             -- initial state 
	  else
	   -- default 
	   s_temp_val <= '0';
	   s_temp_data <= (others => '0');

	   s_daq_pause.orb   <= '0';
       s_daq_pause.eox   <= '0';
	   s_daq_pause.close <= '0';
	 
	   -- case begin  --
	   case state is 
	   --========--
	   --  IDLE  --
	   --========--
	   -- state"IDLE"
	   when IDLE => 
	    -- daq enable 	
	    if daq_enable_i = '1' then
	     state <= START_RUN; 
	    end if;		
	   --===========--
	   -- START_RUN --
	   --===========--
	   -- state"START_RUN"
	   when START_RUN => 
	    -- data available 
		if loc_full_i /= '1' then 
		 if s_loc_empty /= '1' then 
	      state <= READY;
		 end if;
	    end if;
	   --=======--
	   -- READY --
	   --=======--
	   -- state"READY"
	   when READY =>
	    -- data ready 		
	    if s_loc_tx_ready = '1' then -- 3 clock cycles later after state: "start_run"
	     state <= READOUT_MODE;
	    end if;
	   --================--
	   --  READOUT_MODE  --
	   --================--
	   -- state "READOUT_MODE" 
	   when READOUT_MODE =>
	    -- triggered mode --
        if s_trg_mode = '1'  then
	     state <= TRIGGER_MODE;	
	    -- continous mode 
	    elsif s_cont_mode = '1' then 
	     state <= SEND;
	    -- no readout mode selected
	    else  	
		 state <= START_RUN;		
	    end if;
	   --================--
	   --  TRIGGER_MODE  --
	   --================--
	   -- state "TRIGGER_MODE" 
	   when TRIGGER_MODE =>
	    -- sox, eox and orbit trigger from fee
	    if s_fee_select /= "000" then 
	     state <= SEND;
	    -- physics trigger from fee 
        elsif a_fee_physics = '1' then																			 
	     state <= TRIGGER_MODE_FILTER;
        -- reject other triggers from fee
	    else 
	     state <= START_RUN;																
	    end if;
	   --=======================--
	   --  TRIGGER_MODE_FILTER  --
	   --=======================--
	   -- state "TRIGGER_MODE"
	   when TRIGGER_MODE_FILTER => 
	    -- successfull
	    if s_bcid_filter = '1' then
	     state <= SEND;
	    -- unsuccessfull 
	    else 
	     state <= START_RUN;																 
	    end if;
	   --======--
	   -- SEND --
	   --======--
	   -- state "SEND"
	   when SEND =>
	    case s_fee_select is
	    when "001"|"011" => -- eox   
	     state <= SEND_EOX; 
	    when "010" =>       -- orbit 
         state <= SEND_ORBIT;
        when others => 	    -- sox and others
         -- send data 
         s_temp_val <= '1';
         s_temp_data <= s_loc_tx_data;
	     state <= START_RUN; 
	    end case;
	   --============--
	   -- SEND_ORBIT --
	   --============--
	   -- state "SEND_ORBIT"
	   when SEND_ORBIT =>
	    -- timeframe has been reached 
		if s_fee_orbit_cnt = unsigned(mid_sync_i) then  
		 -- daq resume orbit / fifo full
         if daq_resume_i.orb = '1' or s_loc_full = '1' then
		  -- send data (orbit event)
		  s_temp_val <= '1';                               -- temp valid 
          s_temp_data <= s_loc_tx_data;                    -- temp data 
		  state <= START_RUN;
		 else 
		  s_daq_pause.orb <= '1';
		 end if;
        
		-- timeframe limit has nor been reached yet
		else 
		 -- send data (orbit event) 
		 s_temp_val <= '1';
         s_temp_data <= s_loc_tx_data;
		 state <= START_RUN;
		end if;
       --==========--
	   -- SEND_EOX --
	   --==========--
	   -- state "SEND_EOX"
	   when SEND_EOX =>
	    -- daq resume eox 
		if daq_resume_i.eox = '1' then
		 -- send data (eox event) 
         s_temp_val <= '1';
         s_temp_data <= s_loc_tx_data;	 
	     state <= FINISH_RUN;
		else 
		 s_daq_pause.eox <= '1';                           -- request daq resume eox 
		end if;
	   --============--
	   -- FINISH_RUN --
	   --============--
	   -- state "FINISH_RUN"
	   when FINISH_RUN => 
	    -- daq resume close (eox event has reached the 256x256 fifo)
	    if daq_resume_i.close = '1' then 
	     state <= IDLE;
		-- inactive cards (eox event has left the local_elink fifo)
	    elsif loc_inactive_i = '1' then 
		 s_daq_pause.close <= '1';                         -- request daq resume eox
	    end if;
	   --========--
	   -- OTHERS --
	   --========--
	   -- state"others"
	   when others => 
	    state <= IDLE;
	   end case;
	  end if;
	 end if;
	end process p_state;
	--=============================================================================
	-- Begin of p_fee_orbit_cnt
	-- This process enables and disables the overflow 
	--==============================================================================
	p_fee_orbit_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then  
	   s_fee_orbit_cnt <= x"001"; 
	  else 
	   -- daq resume orbit 
       if daq_resume_i.orb = '1' then 
	    s_fee_orbit_cnt <= x"001"; 
       elsif state = SEND_ORBIT then
	    -- timeframe limit  
	    if s_fee_orbit_cnt /= unsigned(mid_sync_i) then
		 s_fee_orbit_cnt <= s_fee_orbit_cnt+1;              
		end if;
       end if;
	  end if;
	 end if;
	end process p_fee_orbit_cnt;		
	--=============================================================================
	-- Begin of p_overflow
	-- This process enables and disables the overflow 
	--==============================================================================
	p_overflow: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then  
	   s_overflow <= '0'; 
	  else 
	   -- daq resume orbit 
       if daq_resume_i.orb = '1' then 
        s_overflow <= '0'; 
       elsif state = SEND_ORBIT then
	    -- timeframe reached 
	    if s_fee_orbit_cnt = unsigned(mid_sync_i) then
		 if s_loc_full = '1' then 
          s_overflow <= '1'; 
		 end if;
		end if;
       end if;
	  end if;
	 end if;
	end process p_overflow;	
	--=============================================================================
	-- Begin of p_active 
	-- This process enables and disables the active signal 
	-- The active signal is enabled after receiving the FEE sox trigger and disabled after 
	-- receiving the daq_resume.close signal 
	--==============================================================================
	p_active: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then  
	   s_active <= '0';
	  else
	   -- fee sox event 
	   if a_fee_sox = '1' then 
	    s_active <= '1'; -- enable active flag 
	   -- daq resume close  
	   elsif daq_resume_i.close = '1' then 
	    s_active <= '0'; -- disable active flag 
	   end if;
	  end if;
	 end if;
	end process p_active;
	
	-- output 
	daq_pause_o.orb   <= s_daq_pause.orb;
	daq_pause_o.eox   <= s_daq_pause.eox;
	daq_pause_o.close <= s_daq_pause.close;

	loc_val_o      <= s_temp_val;
	loc_data_o     <= s_temp_data;
	loc_missing_o  <= std_logic_vector(s_missing_cnt);
	loc_active_o   <= s_active;
    loc_overflow_o <= s_overflow;
	

	p_write_cnt : process
	file my_file : text open write_mode is "ul_input_files/sim_loc_rx.txt";
	variable my_line  : line;
	variable my_count : integer := 0;
	variable my_select: std_logic_vector(1 downto 0) := "00";
    begin

	my_select := s_loc_wrreq &  s_loc_rdreq;
	
	wait until rising_edge(clk_240);

	 case my_select is 
	 when "01" =>
	 	my_count := my_count -1;
		write(my_line, my_count);
		writeline(my_file, my_line);
	 when "10" => 
	 	my_count := my_count +1;
	 	write(my_line, my_count);
		writeline(my_file, my_line);
	 when others => my_count := my_count;
	 end case;

end process p_write_cnt;

end rtl;
--=============================================================================
-- architecture end
--=============================================================================