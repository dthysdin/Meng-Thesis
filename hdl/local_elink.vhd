-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : local_elink.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-24
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes 
-- <29-09-2020> remove unused libraries 
-- <13-10-2020> add pipeline to solve timing failing paths
--              update the loc_decoder port names
-- <28-11-2020> reset the module after sox from ttc and eox from fee
-- <13-02-2021> change the way to deal with overflow
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description: This module instantiates the local_zs and the local_sync  
-- modules. It stores the local data in a buffer and performs pipelining to solve the
-- failling paths errors 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
-- Specific package 
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for local_elink
--=============================================================================
entity local_elink is
	generic (g_LINK_ID : integer := 0; g_REGIONAL_ID : integer := 0; g_LOCAL_ID : integer := 0);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240        : in std_logic;				           
	-------------------------------------------------------------------
	-- avalon + auto reset --  
	reset_i        : in std_logic;
	-------------------------------------------------------------------
	-- data acquisition info --
	daq_enable_i : in std_logic;	
	daq_resume_i : in t_mid_daq_handshake;
	daq_pause_o  : out t_mid_daq_handshake;
	-------------------------------------------------------------------
	-- mid gbt elink data --	
	gbt_val_i      : in std_logic;								
	gbt_data_i     : in std_logic_vector(7 downto 0);										
	-------------------------------------------------------------------
	-- timing and trigger mode -- 		 										 
	ttc_mode_i     : in t_mid_mode;	
	-------------------------------------------------------------------
	-- mid sync  
	mid_sync_i : in std_logic_vector(11 downto 0);
	-------------------------------------------------------------------
	-- local card info -- 
	--< in 
	loc_rdreq_i    : in std_logic;
	--> out 	
	loc_val_o      : out std_logic;								 
	loc_data_o     : out std_logic_vector(167 downto 0);	
	loc_missing_o  : out std_logic_vector(11 downto 0); 
	loc_afull_o    : out std_logic;									 
	loc_empty_o    : out std_logic;								 								
	loc_active_o   : out std_logic;								 
	loc_inactive_o : out std_logic                         
	-------------------------------------------------------------------
	 );  
end local_elink;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of local_elink is					  
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- local fifo 168x128
	signal s_full	      : std_logic;
	signal s_empty	      : std_logic;
	signal s_usedw        : std_logic_vector(6 downto 0);
	signal s_loc_tx_data  : std_logic_vector(167 downto 0);
	signal s_loc_tx_val   : std_logic;
	signal s_loc_tx_preval: std_logic;
	-- loc pause 
	signal s_daq_pause    : t_mid_daq_handshake; 
	-- local status
	signal s_loc_active   : std_logic;
	signal s_loc_inactive : std_logic := '0';
	signal s_loc_overflow : std_logic;
	signal s_loc_missing  : std_logic_vector(11 downto 0);
	-- local data 
	signal s_loc_val    : std_logic;
	signal s_loc_data   : std_logic_vector(167 downto 0);
	-- local data rx
	signal s_loc_rx_val    : std_logic;
	signal s_loc_rx_data   : std_logic_vector(167 downto 0);

	-- stop reading fifo 
	signal s_stop_reading : std_logic;
	
begin 
	--==========================================--
	-- continuous and triggered operation modes --
	--==========================================--
	--==========--
	-- LOCAL ZS --
	--==========--
	local_zs_inst: local_zs
	generic map (g_LINK_ID => g_LINK_ID, g_REGIONAL_ID => g_REGIONAL_ID, g_LOCAL_ID => g_LOCAL_ID)
	port map (
	clk_240	         => clk_240,
	--
	reset_i          => reset_i,
	--
	loc_en_i         => daq_enable_i,
	loc_val_i        => gbt_val_i,
	loc_data_i       => gbt_data_i,
	--
	loc_val_o        => s_loc_val,
	loc_data_o       => s_loc_data);
	--============--
	-- LOCAL SYNC --
	--============--
	local_sync_inst: local_sync
	generic map (g_LOCAL_ID => g_LOCAL_ID)
	port map (
	clk_240	           => clk_240,
	--
	reset_i            => reset_i,
	--
	daq_enable_i       => daq_enable_i,
	daq_resume_i       => daq_resume_i,
	daq_pause_o        => s_daq_pause, 
	--
	ttc_mode_i         => ttc_mode_i,	
	--
	mid_sync_i         => mid_sync_i,
	--
	loc_val_i          => s_loc_val,
	loc_data_i         => s_loc_data,
	loc_full_i         => s_full,
	loc_inactive_i     => s_loc_inactive,
	--
	loc_val_o          => s_loc_rx_val,
	loc_data_o         => s_loc_rx_data,
	loc_missing_o      => s_loc_missing,
	loc_active_o       => s_loc_active,
	loc_overflow_o     => s_loc_overflow);
	--==================--
	-- LOCAL FIFO168x128 --
	--==================--
	fifo_168X128_inst:fifo_168x128
	port map (
	data	           => s_loc_rx_data,
	wrreq	           => s_loc_rx_val,
	rdreq	           => loc_rdreq_i,
	clock	           => clk_240,
	sclr	           => reset_i,
	q	               => s_loc_tx_data,
	full	           => s_full,	
	empty	           => s_empty,
	usedw              => s_usedw);
	--===========================================================================
	-- Begin of p_loc_pipe
	-- pipeline to overcome the latency of the fifo (2 clk cycles)
	--===========================================================================
	p_loc_pipe: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  -- pipeline 
	  s_loc_tx_preval <= loc_rdreq_i;   -- 1st stage 
	  s_loc_tx_val <= s_loc_tx_preval;  -- 2nd stage
	 end if;
	end process p_loc_pipe;
	--===========================================================================
	-- Begin of p_loc_inactive
	-- This process activates and desactivates the inactive signal 
	-- This signal is used to monitor the eox event 
	--===========================================================================
	p_loc_inactive: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then   
	   s_loc_inactive <= '0';  
	  else 
	   -- eox event   
	   if s_loc_tx_val = '1' and s_loc_tx_data(158) = '1' then  
	    s_loc_inactive <= '1';  -- local card inactive 
	   end if;  
	  end if; 
	 end if; 
	end process p_loc_inactive;
	--===========================================================================
	-- Begin of p_cnt_ovf
	-- This process counts the number of words pushed during overflow state.
	-- This is only used in case of emergency, during the timeframe transition 
	-- if the 168x64 fifo is full (overflow), keep sending data but monitor the
	-- number of packet push. Monitoring the event pushed, helps to not mix data
	-- from 2 different timeframes 
	--===========================================================================
	p_cnt_ovf: process(clk_240)
	variable ovf_inc  : unsigned(6 downto 0);                 -- overflow word counter 
	variable usedw_inc: unsigned(6 downto 0);                 -- used word ahead counter 
	variable read_wr  : std_logic_vector(1 downto 0) := "00"; -- read & write 
	begin 
	 if rising_edge(clk_240) then 
	  -- initial conditions 
	  s_stop_reading <= '0';

	  if reset_i = '1' then
	   ovf_inc := (others => '0');              -- reset overflow counter 
	   usedw_inc := (others => '0');            -- reset used word counter 
	  else

	   -- self-reset
	   if daq_resume_i.orb = '1' then
        ovf_inc := (others => '0');             -- initial condition
	    usedw_inc := (others => '0');           -- initial condition

	   -- overflow
	   elsif s_loc_overflow = '1' then 
	    read_wr := loc_rdreq_i & s_loc_rx_val; -- concatenate (read & write)  
	    case read_wr is 
        when "01" =>                           -- write
	     ovf_inc   := ovf_inc+1;               -- increment overflow counter  
	     usedw_inc := unsigned(s_usedw)+1;     -- fifo word increment ahead
	    when "10" =>                           -- read
	     usedw_inc := unsigned(s_usedw)-1;     -- fifo word decrement ahead     
	    when "11" =>                           -- read and write  
	     ovf_inc   := ovf_inc+1;               -- increment overflow counter           
         usedw_inc := unsigned(s_usedw);       -- copy fifo word counter 
        when others => null;
	    end case;
	    -- compare 
	    if ovf_inc = usedw_inc  then 
         s_stop_reading <= '1'; -- stop reading 
        end if;
	   end if;
	  end if;
	 end if;
	end process p_cnt_ovf; 
	
	-- output  
	daq_pause_o.orb   <= s_daq_pause.orb or s_loc_overflow;
	daq_pause_o.eox   <= s_daq_pause.eox;
	daq_pause_o.close <= s_daq_pause.close;

	loc_data_o     <= s_loc_tx_data;
	loc_val_o      <= s_loc_tx_val;
	loc_empty_o    <= s_stop_reading or s_empty;
	loc_afull_o    <= s_usedw(6) and not(s_empty);
	loc_active_o   <= s_loc_active;
	loc_inactive_o <= s_loc_inactive;
	loc_missing_o  <= s_loc_missing;

end rtl;
--=============================================================================
-- architecture end
--=============================================================================-