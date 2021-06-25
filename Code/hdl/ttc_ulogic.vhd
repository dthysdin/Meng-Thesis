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
-- <21-02-2021> 
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
    generic (g_NUM_HBFRAME: integer; g_NUM_HBFRAME_SYNC: integer);
    port (
    -------------------------------------------------------------------
    -- 240 MHz clock --
    clk_240	   : in std_logic;
    -------------------------------------------------------------------
	-- resets --  	
    hard_reset   : in std_logic; 
    soft_reset   : out std_logic;  
    -------------------------------------------------------------------
    -- trigger monitor register  -- 
    av_trg_monit_o : out std_logic_vector(31 downto 0);
    -------------------------------------------------------------------
    -- ttc info -- 
    ttc_rxd_i      : in std_logic_vector(199 downto 0);
    ttc_rxvalid_i  : in std_logic;   
    ttc_rxready_i  : in std_logic;  
    ttc_data_o     : out t_mid_ttc;
    ttc_mode_o     : out t_mid_mode;
    ttc_pulse_o    : out t_mid_pulse 
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
    -- timing & trigger control info pipeline 
    signal s_ttc_data  : t_mid_ttc;
    signal s_ttc_valid : std_logic;
    
    -- main trigger registers 
    signal s_is_sox : std_logic := '0';
    signal s_is_eox : std_logic := '0';

    -- pulses 
    signal s_pulse_init : std_logic;
    signal s_pulse_hbt  : std_logic; 
    signal s_pulse_sox  : std_logic;
    signal s_pulse_eox  : std_logic;
    signal s_pulse_sel  : std_logic;

    -- modes 
    signal s_continuous : std_logic := '0';
    signal s_triggered  : std_logic := '0';
    signal s_triggered_data : std_logic_vector(15 downto 0) := (others => '0');
	
    -- avalon trigger counters 
    signal s_hbframe_cnt : unsigned(11 downto 0) := x"000"; 
    signal s_tframe_cnt  : unsigned(11 downto 0) := x"000";


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
       -- timing and trigger info
       s_ttc_data.orbit <= ttc_rxd_i(79 downto 48);
       s_ttc_data.bcid  <= x"0" & ttc_rxd_i(43 downto 32);
       s_ttc_data.trg	<= ttc_rxd_i(31 downto 0); 
      end if;
     end if; 
    end process p_ttc_data;
    --=============================================================================
    -- Begin of p_ttc_pulse
    -- This process contains the trigger information register 
    --=============================================================================
    p_ttc_pulse: process(clk_240)
    begin 
     if rising_edge(clk_240) then
      -- default 
      s_pulse_init <= '0';
      s_pulse_hbt  <= '0';
      s_pulse_eox  <= '0';

      if hard_reset = '1' then 
       s_is_sox <= '0';
       s_is_eox <= '0';
      else
       if s_ttc_valid = '1' then 
        -- init pulse
        if ttc_rxd_i(7) = '1' or ttc_rxd_i(9) = '1' then 
         s_pulse_init <= '1';
         s_is_sox <= '1';
         s_is_eox <= '0';

        -- eox pulse 
        elsif ttc_rxd_i(8) = '1' or ttc_rxd_i(10) = '1' then 
         s_pulse_eox <= '1';
         s_is_sox <= '0';
         s_is_eox <= '1';
        
        -- heartbeat pulse 
        elsif ttc_rxd_i(0) = '1' and ttc_rxd_i(1) = '1' and s_is_sox = '1' then
         s_pulse_hbt <= '1';
        end if;
       end if;
      end if;
     end if; 
    end process p_ttc_pulse;
    --=============================================================================
    -- Begin of p_mode
    -- This process 
    --=============================================================================
    p_mode: process(clk_240)
    begin 
     if rising_edge(clk_240) then 
      if hard_reset = '1' then 
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
        end if;

        -- triggered (sot-eot) 
        if ttc_rxd_i(7) = '1' then 
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
    --=============================================================================
    -- Begin of p_ttc_counters
    -- This process contains avalon trigger counters to monitor the ttc information
    --=============================================================================
    p_ttc_counters: process(clk_240)
     variable temp_cnt : unsigned(11 downto 0) := x"001";
    begin 
     if rising_edge(clk_240) then
      -- default
      s_pulse_sel <= '0';
      s_pulse_sox <= '0';

      if hard_reset = '1' then
       -- hard reset 
       temp_cnt      := (others => '0');
       s_hbframe_cnt <= (others => '0'); 
       s_tframe_cnt  <= (others => '0');

      else 
       -- initialization pulse
       if s_pulse_init = '1' then 
        temp_cnt      := x"001";
        s_hbframe_cnt <= x"001"; 
        s_tframe_cnt  <= x"000";
        s_pulse_sox   <= '1';

       -- heartbeat trigger pulse  
       elsif s_pulse_hbt = '1' then 
        -- heartbeat counter 
        if s_hbframe_cnt = to_unsigned(g_NUM_HBFRAME_SYNC, s_hbframe_cnt'length) then  
         s_hbframe_cnt <= x"001";                  -- reinitialize HBF counter & automatically collect data                                                                         
        else 
         s_hbframe_cnt <= s_hbframe_cnt+1;         -- increment HBF counter
         s_pulse_sel <= '1';                       -- send a pulse & force the collection of data
        end if;

        -- timeframe counter                                                  
        if s_tframe_cnt = to_unsigned(g_NUM_HBFRAME, s_tframe_cnt'length) then 
         s_tframe_cnt <= x"000";                   -- reinitialize TF counter 
         temp_cnt := x"001";                       -- reinitialize temporary counter
        elsif temp_cnt = to_unsigned(g_NUM_HBFRAME, temp_cnt'length) then  
         temp_cnt := x"001";                       -- reinitialize temporary counter  
         s_tframe_cnt <= s_tframe_cnt+1;           -- increment TF counter
        else 
         temp_cnt := temp_cnt+1;                   -- increment temporary counter
        end if;
       end if;
      end if; 
     end if; 
    end process p_ttc_counters;

    -- avalon trigger info 
    av_trg_monit_o(31 downto 24) <= s_is_sox & "000000" & s_is_eox;  -- sox & eox received flags 
    av_trg_monit_o(23 downto 12) <= std_logic_vector(s_tframe_cnt);  -- number of timeframes received during the run 
    av_trg_monit_o(11 downto 0)  <= std_logic_vector(s_hbframe_cnt); -- number of heartbeat received during the timeframe

    -- ttc pulses
    ttc_pulse_o.sox <= s_pulse_sox;
    ttc_pulse_o.hbt <= s_pulse_hbt;
    ttc_pulse_o.sel <= s_pulse_sel;
    ttc_pulse_o.eox <= s_pulse_eox;

    -- ttc mode 
    ttc_mode_o.continuous <= s_continuous;
    ttc_mode_o.triggered  <= s_triggered;
    ttc_mode_o.triggered_data <= s_triggered_data;

    -- timing and trigger info
    ttc_data_o.orbit <= s_ttc_data.orbit;
    ttc_data_o.bcid  <= s_ttc_data.bcid;
    ttc_data_o.trg   <= s_ttc_data.trg;

    -- pulse initialization 
    soft_reset <= s_pulse_init;
    
end rtl;
--=============================================================================
-- architecture end
--=============================================================================		