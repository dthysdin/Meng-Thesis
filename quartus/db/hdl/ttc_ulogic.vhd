-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : ttc_ulogic.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-30
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 2.0
-------------------------------------------------------------------------------
-- last changes 
-- <23-01-2022>
-- check the tfm and hbf counters 
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to control the user logic 
--------------------------------------------------------------------------------
-- Requirements: <no special requirements> 
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
--Entity declaration for ttc_ulogic
--=============================================================================
entity ttc_ulogic is
    port (
    -------------------------------------------------------------------
    -- 240 MHz clock --
    clk_240	     : in std_logic;
    -------------------------------------------------------------------
	-- mid --  	
    mid_reset_i : in std_logic;   
    mid_sync_i : in std_logic_vector(11 downto 0);
    ------------------------------------------------------------------
    -- sync reset --
    sync_reset_o  : out std_logic;
    -------------------------------------------------------------------
    -- ttc info -- 
    -- in 
    ttc_rxvalid_i : in std_logic;   
    ttc_rxready_i : in std_logic;
    ttc_rxd_i     : in std_logic_vector(199 downto 0);
    -- out
    ttc_data_o    : out t_mid_ttc;
    ttc_mode_o    : out t_mid_mode;
    ttc_pulse_o   : out t_mid_pulse;
    ttc_monitor_o : out std_logic_vector(31 downto 0)
    ------------------------------------------------------------------------
       );  
end ttc_ulogic;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of ttc_ulogic is
    -- ========================================================
    -- signal declarations
    -- ========================================================
    signal s_sync_reset : std_logic;
    -- timing & trigger control info pipeline 
    signal s_ttc_data  : t_mid_ttc;
    signal s_ttc_valid : std_logic;
    -- main trigger registers 
    signal s_is_sox : std_logic := '0';
    signal s_is_eox : std_logic := '0';
    -- pulses 
    signal s_pulse_hbt  : std_logic;     -- heartbeat pulse
    signal s_pulse_tfm  : std_logic;     -- timeframe pulse
    signal s_pulse_sox  : std_logic;     -- sox pulse 
    signal s_pulse_eox  : std_logic;     -- eox pulse 
    signal s_pulse_sel  : std_logic;     -- heartbeat sel pulse
    signal s_temp_pulse_sox : std_logic; -- temporary sox pulse
    signal s_temp_pulse_eox : std_logic; -- temporary eox pulse
    -- modes 
    signal s_continuous : std_logic := '0';
    signal s_triggered  : std_logic := '0';
    signal s_triggered_data : std_logic_vector(15 downto 0) := (others => '0');
    signal s_is_continuous  : std_logic := '0';
    signal s_is_triggered   : std_logic := '0';
    -- avalon trigger counters 
    signal s_heartbeat_cnt : unsigned(11 downto 0) := x"000"; 
    signal s_timeframe_cnt : unsigned(11 downto 0) := x"000";


begin 

    -- valid trigger & timing info
     s_ttc_valid <= ttc_rxd_i(119) and ttc_rxvalid_i and ttc_rxready_i;
    --=============================================================================
    -- Begin of p_ttc_data
    -- This process contains the trigger information register 
    --=============================================================================
    p_ttc_data: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      if s_ttc_valid = '1' then 
       s_ttc_data.orbit <= ttc_rxd_i(79 downto 48);
       s_ttc_data.bcid  <= x"0" & ttc_rxd_i(43 downto 32);
       s_ttc_data.trg	<= ttc_rxd_i(31 downto 0); 
      end if;
     end if; 
    end process p_ttc_data;
    --=============================================================================
    -- Begin of p_trg
    -- This process contains the sox and eox trigger registers 
    --=============================================================================
    p_trg: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      if mid_reset_i = '1' then 
       s_is_sox <= '0';
       s_is_eox <= '0';
      else
       if s_ttc_valid = '1' then 
        -- sox trigger 
        if ttc_rxd_i(7) = '1' or ttc_rxd_i(9) = '1' then  
         s_is_sox <= '1';     -- store sox 
         s_is_eox <= '0';     -- reset eox 
        -- eox trigger 
        elsif ttc_rxd_i(8) = '1' or ttc_rxd_i(10) = '1' then 
         s_is_sox <= '0';     -- reset sox
         s_is_eox <= '1';     -- store eox
        end if;
       end if;
      end if;
     end if; 
    end process p_trg;
    --=============================================================================
    -- Begin of p_mode
    -- This process determines the type of running modes based on the ttc information
    --=============================================================================
    p_mode: process(clk_240)
    begin 
     if rising_edge(clk_240) then 
      if mid_reset_i = '1' then 
       s_continuous <= '0';
       s_triggered <= '0';
       s_triggered_data <= (others => '0');
      else 
       if s_ttc_valid = '1' then 

        -- continuous (soc-eoc) 
        if ttc_rxd_i(9) = '1' then 
         s_continuous <= '1';
        elsif ttc_rxd_i(10) = '1' then 
         s_continuous <= '0';
        -- triggered (sot-eot) 
        elsif ttc_rxd_i(7) = '1' then 
         s_triggered <= '1';
        elsif ttc_rxd_i(8) = '1' then 
         s_triggered <= '0';
        end if;
        
        -- data in triggered mode (physics trigger)
        if ttc_rxd_i(4) = '1' and s_triggered = '1' then 
         s_triggered_data <= x"0" & ttc_rxd_i(43 downto 32);
        end if;
       end if;
      end if;
     end if;
    end process p_mode;
    --============================================================================
    -- Begin of p_ismode
    -- This process stores the the readout mode transmitted from the LTU
    -- This process is used for monitoring purposes
    --=============================================================================
    p_ismode: process(clk_240)
    begin
     if rising_edge(clk_240) then 
      if mid_reset_i = '1' then 
       s_is_continuous <= '0';
       s_is_triggered  <= '0';
      else 
       if s_continuous = '1' then 
        s_is_continuous <= '1';
        s_is_triggered  <= '0';
       elsif s_triggered = '1' then 
        s_is_continuous <= '0';
        s_is_triggered  <= '1';
       end if;
      end if;
     end if;
    end process p_ismode;
    --=============================================================================
    -- Begin of p_ttc_pulse
    -- This process generates eox and heartbeat pulses  
    --=============================================================================
    p_ttc_pulse: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      -- default 
      s_pulse_hbt  <= '0';
      s_temp_pulse_eox  <= '0';
      s_temp_pulse_sox  <= '0';

      if s_ttc_valid = '1' then 
       -- pulse sox
       if ttc_rxd_i(7) = '1' or ttc_rxd_i(9) = '1' then 
        s_temp_pulse_sox <= '1';   
       -- pulse eox
       elsif ttc_rxd_i(8) = '1' or ttc_rxd_i(10) = '1' then 
        s_temp_pulse_eox <= '1'; 
       -- pulse heaertbeat   
       elsif ttc_rxd_i(0) = '1' and ttc_rxd_i(1) = '1' and s_is_sox = '1' then
        s_pulse_hbt <= '1';  
       end if;
      end if;
     end if; 
    end process p_ttc_pulse;
    --=============================================================================
    -- Begin of p_sync_reset
    -- This process contains the trigger information register 
    --=============================================================================
    p_sync_reset: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      -- avalon mid reset 
      if mid_reset_i = '1' then 
       s_sync_reset <= '1';
      -- sox pulse reset
      elsif s_ttc_valid = '1' then 
       if ttc_rxd_i(7) = '1' or ttc_rxd_i(9) = '1' then 
        s_sync_reset <= '1';
       end if;
      -- remain low  
      else 
       s_sync_reset <= '0';
      end if;
     end if; 
    end process p_sync_reset;
    --=============================================================================
    -- Begin of p_ttc_counters
    -- This process contains avalon trigger counters to monitor the ttc information
    --=============================================================================
    p_ttc_counters: process(clk_240)
     variable temp_cnt : unsigned(11 downto 0) := x"001";
    begin 
     if rising_edge(clk_240) then

      -- synchronuous reset 
      if s_sync_reset = '1' then
        s_heartbeat_cnt <= x"000"; 
        temp_cnt        := x"000";
        s_timeframe_cnt <= x"000";
      else 
       -- initialization (sox pulse) 
       if s_pulse_sox = '1' then 
        s_heartbeat_cnt <= x"001"; 
        temp_cnt        := x"001";
        s_timeframe_cnt <= x"000";
        
       -- heartbeat trigger pulse  
       elsif s_pulse_hbt = '1' then

        -- heartbeat counter
        if s_heartbeat_cnt = unsigned(mid_sync_i) then  
         s_heartbeat_cnt <= x"001";                       -- reinitialize heartbeat counter                                                                         
        else 
         s_heartbeat_cnt <= s_heartbeat_cnt+1;             -- increment heartbeat counter
        end if;

        -- timeframe counter                                                  
        if s_timeframe_cnt = unsigned(mid_sync_i) then 
         s_timeframe_cnt <= x"000";                       -- reinitialize TF counter 
         temp_cnt        := x"001";                       -- reinitialize temp counter
        elsif temp_cnt = unsigned(mid_sync_i) then   
         s_timeframe_cnt <= s_timeframe_cnt+1;            -- increment TF counter
         temp_cnt := x"001";                              -- reinitialize heartbeat counter 
        else 
         temp_cnt := temp_cnt+1;                          -- increment heartbeat counter
        end if;
        
       end if;
      end if; 
     end if; 
    end process p_ttc_counters;
    --=============================================================================
    -- Begin of p_sox_pulse
    -- This process generates the sox pulse 
    -- This pulse is used to start the MID data acquisition 
    --=============================================================================
    p_sox_pulse: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      s_pulse_sox <= s_temp_pulse_sox;
      s_pulse_eox <= s_temp_pulse_eox;
     end if; 
    end process p_sox_pulse;
    --=============================================================================
    -- Begin of p_sel_pulse
    -- This process generates the heartbeat sel pulse
    -- This pulse is used to collect heartbeat frame data
    --=============================================================================
    p_sel_pulse: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      -- initial condition
      s_pulse_sel  <= '0';
      s_pulse_tfm  <= '0';
      -- heartbeat trigger 
      if s_pulse_hbt = '1' then 
       if s_heartbeat_cnt /= unsigned(mid_sync_i) then 
        s_pulse_sel <= '1';   -- sel pulse on
       elsif s_heartbeat_cnt = unsigned(mid_sync_i) then 
        s_pulse_tfm <= '1';
       end if;
      end if;
     end if; 
    end process p_sel_pulse;

    -- output 
    ttc_monitor_o(31 downto 28) <= s_is_sox & "00" & s_is_eox;              -- sox & eox received flags 
    ttc_monitor_o(27 downto 24) <= s_is_continuous & "00" & s_is_triggered; -- continuous & triggered mode flags
    ttc_monitor_o(23 downto 12) <= std_logic_vector(s_timeframe_cnt);       -- number of timeframes received during the run 
    ttc_monitor_o(11 downto 0)  <= std_logic_vector(s_heartbeat_cnt);       -- number of heartbeat received during the timeframe


    ttc_pulse_o.sox <= s_pulse_sox;
    ttc_pulse_o.hbt <= s_pulse_hbt;
    ttc_pulse_o.tfm <= s_pulse_tfm;
    ttc_pulse_o.eox <= s_pulse_eox;
    ttc_pulse_o.sel <= s_pulse_sel;

    ttc_mode_o.continuous <= s_continuous;
    ttc_mode_o.triggered  <= s_triggered;
    ttc_mode_o.triggered_data <= s_triggered_data;

    ttc_data_o.orbit <= s_ttc_data.orbit;
    ttc_data_o.bcid  <= s_ttc_data.bcid;
    ttc_data_o.trg   <= s_ttc_data.trg;

    sync_reset_o <= s_sync_reset;
    
end rtl;
--=============================================================================
-- architecture end
--=============================================================================		
