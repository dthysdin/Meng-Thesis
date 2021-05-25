-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project    : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File       : regional_control.vhd
-- Author     : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No : 214349721
-- Company    : NRF iThemba LABS
-- Created    : 2020-06-24
-- Platform   : Quartus Pro 18.1
-- Standard   : VHDL'93'
-- Version    : 0.7
-------------------------------------------------------------------------------
-- last changes 
-- <29/09/2020> add output register
-- <13/10/2020> change the combitional fsm to sequencial 
-- <28-11-2020> reset the module after sox from ttc 
-- <18-12-2020> deal with the buffer overflow 
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to able to adjust between the trigger mode and
-- the continuous mode.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for regional_control
--=============================================================================
entity regional_control is
	generic (g_REGIONAL_ID: integer; g_NUM_HBFRAME_SYNC: integer; g_LINK_ID : integer);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240	       : in std_logic;
	-------------------------------------------------------------------
	-- avalon + auto reset --
	reset_i	       : in std_logic;							 
	-------------------------------------------------------------------
    -- data acquisition info --
	daq_valid_i    : in std_logic; 
	daq_resume_i   : in std_logic;
	daq_stop_i     : in std_logic;
    --
	orb_pause_o    : out std_logic;
	eox_pause_o    : out std_logic;
	-------------------------------------------------------------------
    -- timing and trigger control mode --		 								
	ttc_mode_i     : in t_mid_mode;
	-------------------------------------------------------------------
	-- regional card info --
	--< in 
	reg_val_i      : in std_logic;								 
	reg_data_i     : in std_logic_vector(39 downto 0);		 
	reg_full_i     : in std_logic;								
	reg_inactive_i : in std_logic;							
	--> out		
	reg_val_o         : out std_logic;								
	reg_data_o        : out std_logic_vector(39 downto 0);
	reg_missing_o     : out std_logic_vector(11 downto 0);	 							 
	reg_active_o      : out std_logic;
	reg_overflow_o    : out std_logic;
	reg_crateID_o     : out std_logic_vector(3 downto 0);
	reg_crateID_val_o : out std_logic
	-------------------------------------------------------------------
	 );  
end regional_control;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of regional_control is
	-- =================================================
	-- SYMBOLIC ENCODED state machine: state_reg
	-- =================================================
	type t_reg_state is (IDLE,
	                    START_RUN,
                        READY,
                        READOUT_MODE, 
                        TRIGGER_MODE, 
                        TRIGGER_MODE_FILTER, 
                        SEND,
                        SEND_ORBIT,
                        SEND_EOX,		
                        FINISH_RUN);
								
	signal state : t_reg_state := IDLE;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- regional fifo
	signal s_reg_rd        : std_logic;	
	signal s_reg_rdreq     : std_logic;
	signal s_reg_wrreq     : std_logic;
	signal s_reg_full      : std_logic;			
	signal s_reg_empty     : std_logic;	
	signal s_reg_rx_data   : std_logic_vector(39 downto 0);
	
	-- regional fifo out tx pipeline 
	signal s_reg_tx_preval : std_logic;
	signal s_reg_tx_val    : std_logic;
	signal s_reg_tx_ready  : std_logic;
	signal s_reg_tx_predata: std_logic_vector(39 downto 0):= (others => '0');
	signal s_reg_tx_data   : std_logic_vector(39 downto 0):= (others => '0');
	
	-- pause D-FFs 
	signal s_orb_pause   : std_logic;
	signal s_eox_pause   : std_logic;
	
	-- temporary register
	signal s_temp_val    : std_logic;                      
	signal s_temp_data   : std_logic_vector(39 downto 0);  
	
	-- bcid 			
	signal s_bcid_filter : std_logic;
	
	-- readout mode 
	signal s_trg_mode   : std_logic := '0'; -- valid during FEE & TTC trigger mode 
	signal s_cont_mode  : std_logic := '0'; -- valid during FEE & TTC continuous mode 
	
	-- 
	signal s_active     : std_logic := '0';
	signal s_is_fee_eox : std_logic := '0'; -- valid after FEE EOx trigger
	signal s_overflow   : std_logic := '0'; -- valid after emergency release 

	signal s_fee_select : std_logic_vector(2 downto 0);                   -- FEE concatenation of (sox-orb-eox)
	signal s_fee_orbit_cnt : unsigned(11 downto 0) := (others => '0');    -- FEE orbit counter 
	signal s_missing_cnt : unsigned(11 downto 0) := (others => '0');      -- FEE missing events counter
	
	-- crate and custom IDs
	signal s_customID    : std_logic_vector(3 downto 0);                  -- customised crate ID  
	signal s_crateID     : std_logic_vector(3 downto 0) := x"0";          -- original crate ID 
	signal s_crateID_val : std_logic := '0';                              -- original crate ID valid
	-- ========================================================
	-- alias declarations
	-- ========================================================
	alias a_fee_sox    : std_logic is s_reg_tx_data(31);	    -- FEE sox 
	alias a_fee_eox    : std_logic is s_reg_tx_data(30);	    -- FEE eox 
	alias a_fee_physics: std_logic is s_reg_tx_data(26);	    -- FEE physics trigger 
	alias a_fee_orbit  : std_logic is s_reg_tx_data(24);	    -- FEE orbit
	alias a_fee_bc     : std_logic_vector(15 downto 0) is s_reg_tx_data(23 downto 8); -- FEE bc
	
begin 
	--=========================================================--
	-- fifo for regional card informations  40 bit x 64 words
	-- MLAB memory type (look ahead read mode)
	-- rdreq is used as read acknowledge  
	--========================================================--
	s_reg_wrreq <= reg_val_i and(not s_reg_full);                          -- valid data when fifo not busy
	s_reg_rdreq <= s_reg_rd and (not s_reg_empty);                         -- ack data when fifo not empty 
	s_reg_rd <= '1' when state = START_RUN and reg_full_i /= '1' else '0'; -- extract data from fifo 

	fifo_40x64_inst: fifo_40x64
	port map (
	data	=> reg_data_i,
	wrreq	=> s_reg_wrreq,
	rdreq	=> s_reg_rdreq,
	clock	=> clk_240,
	sclr	=> reset_i,
	q       => s_reg_rx_data,
	full	=> s_reg_full,
	empty	=> s_reg_empty);
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
	    if reg_val_i = '1' and s_reg_full = '1' then
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
	p_reg_pipe: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
      -- pipeline 
      s_reg_tx_preval <= s_reg_rdreq;     -- 1st stage
      s_reg_tx_val    <= s_reg_tx_preval; -- 2nd stage
	  s_reg_tx_ready  <= s_reg_tx_val;    -- 3rd stage 

	  if reset_i = '1' then 
       s_reg_tx_data <= (others => '0');
	  elsif s_reg_rdreq = '1' then 
	   s_reg_tx_predata <= s_reg_rx_data; -- copy fifo data 
      elsif s_reg_tx_val = '1' then 
	   s_reg_tx_data <= s_reg_tx_predata; -- copy pilpelined fifo data 
      end if;
	 end if;
	end process p_reg_pipe;
	
	-- concatenate sox, orbit and eox 
	s_fee_select <= a_fee_sox & a_fee_orbit & a_fee_eox;
							
	-- bunch crossing ID filter 
	s_bcid_filter <= '1' when (unsigned(a_fee_bc) = unsigned(ttc_mode_i.triggered_data)) and state /= IDLE else 
	                 '1' when (unsigned(a_fee_bc)+1 = unsigned(ttc_mode_i.triggered_data)) and state /= IDLE else
	                 '1' when (unsigned(a_fee_bc)-1 = unsigned(ttc_mode_i.triggered_data)) and state /= IDLE else '0';
	--=============================================================================
	-- Begin of p_fee_eox
	-- This process stores the (EOx) from the FEE
	--=============================================================================
	p_fee_eox: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then  
	   s_is_fee_eox <= '0';
	  else 
	   -- fee "eox"
	   if a_fee_eox = '1' then
	    s_is_fee_eox <= '1';  
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
	   -- Trigger mode --	 
	   if  ttc_mode_i.triggered = '1' and a_fee_sox = '1' then 
	    s_trg_mode <= '1'; 			-- active 	
	   elsif s_trg_mode = '1' and s_is_fee_eox = '1' then	
	    s_trg_mode <= '0'; 			-- desactive  
	   end if; 
		  
       -- Continuous mode -- 
	   if ttc_mode_i.continuous = '1' and a_fee_sox = '1' then 
	    s_cont_mode <= '1'; 			-- active 	
	   elsif s_cont_mode = '1' and s_is_fee_eox = '1' then 
	    s_cont_mode <= '0'; 			-- desactive  
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
	   s_fee_orbit_cnt <= x"001"; -- initial orbit counter value
	  else 
	   -- default 
	   s_temp_val <= '0';
	   s_temp_data <= (others => '0');
		
       s_orb_pause <= '0';
       s_eox_pause <= '0';
		
	   -- case begin  --
	   case state is 
	   --========--
	   --  IDLE  --
	   --========--
	   -- state"IDLE"
	   when IDLE =>  
	    if daq_valid_i = '1' then
	     state <= START_RUN;	
	    end if;
	   --===========--
	   -- START_RUN --
	   --===========--
       -- state"START_RUN"
       when START_RUN => 
	    -- fee data available 
	    if s_reg_empty = '0' and reg_full_i = '0' then 
	     state <= READY;
	    end if;
	   --=======--
	   -- READY --
	   --=======--
	   -- state"READY"
	   when READY =>
	    -- fee data ready  
	    if s_reg_tx_ready = '1' then
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
	     when "001"|"011" =>   -- eox   
	      state <= SEND_EOX; 
         when "010" =>         -- orbit
          state <= SEND_ORBIT;
         when others =>        -- sox and others
          -- send data 
          s_temp_val <= '1';
	      s_temp_data <= s_reg_tx_data(39 downto 8) & s_customID & s_reg_tx_data(3 downto 0);
	      state <= START_RUN; 
	     end case;
       --============--
	   -- SEND_ORBIT --
	   --============--
	   -- state "SEND_ORBIT"
       when SEND_ORBIT =>
	    if s_fee_orbit_cnt = to_unsigned(g_NUM_HBFRAME_SYNC, s_fee_orbit_cnt'length) then  -- default (256 orbit)
	     -- resume daq
	     if daq_resume_i = '1' or s_reg_full = '1' then
		  s_temp_val <= '1';                                                                   -- temp valid 
		  s_temp_data <= s_reg_tx_data(39 downto 8) & s_customID & s_reg_tx_data(3 downto 0);  -- temp data 
		  s_fee_orbit_cnt <= x"001";                                                           -- initial condition
		  state <= START_RUN;  
	     else 
		  s_orb_pause <= '1';                                                                  -- request resune 
	     end if;

	    else 
	     -- send data 
	     s_fee_orbit_cnt <= s_fee_orbit_cnt+1;                                                -- increment fee orbit counter 
	     s_temp_val <= '1';
	     s_temp_data <= s_reg_tx_data(39 downto 8) & s_customID & s_reg_tx_data(3 downto 0);
	     state <= START_RUN;
	    end if;
       --==========--
	   -- SEND_EOX --
	   --==========--
	   -- state "SEND_EOX"
       when SEND_EOX => 
	    if daq_resume_i = '1' and s_overflow /= '1' then
		 -- send data 
		 s_temp_val <= '1';
		 s_temp_data <= s_reg_tx_data(39 downto 8) & s_customID & s_reg_tx_data(3 downto 0);	 
		 state <= FINISH_RUN;
	    else 
		 s_orb_pause <= '1';   -- request daq_resume                                                                
	    end if;
	   --============--
	   -- FINISH_RUN --
	   --============--
	   -- state "FINISH_RUN" 
	   when FINISH_RUN =>
	    -- stop daq	
	    if daq_stop_i = '1' then 
	     state <= IDLE;
	    elsif reg_inactive_i = '1' then 
	     s_eox_pause <= '1';  -- request daq_stop
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
	-- Begin of p_overflow
	-- This process enables and disables the overflow 
	--==============================================================================
	p_overflow: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then  
	   s_overflow <= '0'; 
	  else 
       if daq_resume_i = '1' then 
        s_overflow <= '0';  
       elsif state = SEND_ORBIT and s_fee_orbit_cnt = to_unsigned(g_NUM_HBFRAME_SYNC, s_fee_orbit_cnt'length) then
		-- timeframe bondary and memory full 
		if s_reg_full = '1' then 
         s_overflow <= '1'; 
		end if;
       end if;
	  end if;
	 end if;
	end process p_overflow;
	-- custom ID     
	-- custom#9 reads Loc#12-15 & Regional_ID#1
	-- custom#1 reads Loc#4-7   & Regional_ID#1 
	s_customIDH_gen: if g_REGIONAL_ID = 1 generate  
	s_customID <= x"9" when (g_LINK_ID mod 2) = 1 else x"1"; 
	end generate;
	-- custom#8 reads Loc#8-11  & Regional_ID#0
	-- custom#0 reads Loc#0-3   & Regional_ID#0
	s_customIDL_gen: if g_REGIONAL_ID /= 1 generate   
	s_customID <= x"8" when (g_LINK_ID mod 2) = 1 else x"0";
	end generate;
	--=============================================================================
	-- Begin of p_crate_ID
	-- This process stores the fee crate ID   
	--==============================================================================
	p_crate_ID: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
       s_crateID_val <= '0';
	  else 
	   -- store regional crate ID 
	   if state = READY and s_reg_tx_ready = '1' then 
	    s_crateID <= s_reg_tx_data(7 downto 4);
		s_crateID_val <= '1';
	   end if;
	  end if;
	 end if;
	end process p_crate_ID;
	--=============================================================================
	-- Begin of p_active 
	-- This process enables and disables the temporary active D-FF
	--==============================================================================
	p_active: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_active <= '0';
	  else 
	   if a_fee_sox = '1' then 
        s_active <= '1';  
       elsif daq_stop_i = '1' then 
        s_active <= '0';  
       end if;
	  end if;
	 end if;
	end process p_active;
	
	-- output 
	orb_pause_o <= s_orb_pause;
	eox_pause_o <= s_eox_pause;

	reg_val_o         <= s_temp_val;
	reg_data_o        <= s_temp_data;
	reg_missing_o     <= std_logic_vector(s_missing_cnt);
	reg_active_o      <= s_active;
	reg_overflow_o    <= s_overflow;
	reg_crateID_o     <= s_crateID;
	reg_crateID_val_o <= s_crateID_val;
		
end rtl;
--=============================================================================
-- architecture end
--=============================================================================