-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : regional_elink.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-24
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 2.0
-------------------------------------------------------------------------------
-- last change
-- <29-09-2020> remove unused libraries 
-- <13-10-2020> add pipeline to solve timing failing paths
--              update the loc_decoder port names
-- <28-11-2020> reset the module after sox from ttc 	
-- <13-02-2021> change the way to deal with overflow
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description: This module instantiates the regional_decoder and the regional_ctrl  
-- modules. It stores the regional data in a buffer and performs pipelining to solve the
-- timing errors 
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
--Entity declaration for regional_elink
--=============================================================================
entity regional_elink is
	generic ( g_REGIONAL_ID: integer; g_LINK_ID : integer);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240      : in std_logic;				           
	-------------------------------------------------------------------
	-- avalon + auto reset --  
	reset_i      : in std_logic;
	-------------------------------------------------------------------
    -- data acquisition info --
	daq_enable_i : in std_logic;	
	daq_resume_i : in t_mid_daq_handshake;
	daq_pause_o  : out t_mid_daq_handshake;
	-------------------------------------------------------------------
	-- mid gbt elink data --											
	gbt_val_i    : in std_logic;
	gbt_data_i   : in std_logic_vector(7 downto 0);									
	-------------------------------------------------------------------
    -- timing and trigger system mode -- 		 									 
	ttc_mode_i  : in t_mid_mode;
	-------------------------------------------------------------------
	-- mid sync
	mid_sync_i: in std_logic_vector(11 downto 0);
	-------------------------------------------------------------------
	-- regional card info --
	--< in 
	reg_rdreq_i       : in std_logic;								 													
	--> out		
	reg_val_o         : out std_logic;								
	reg_data_o        : out std_logic_vector(39 downto 0);
	reg_missing_o     : out std_logic_vector(11 downto 0);
	reg_afull_o       : out std_logic;
	reg_empty_o       : out std_logic;
	reg_active_o      : out std_logic;
	reg_inactive_o    : out std_logic;
	reg_crateID_o     : out std_logic_vector(3 downto 0);
	reg_crateID_val_o : out std_logic
	-------------------------------------------------------------------
	 );  
end regional_elink;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of regional_elink is					  
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- regional fifo 40x168
	signal s_full         : std_logic;
	signal s_empty        : std_logic;
	signal s_usedw        : std_logic_vector(6 downto 0);
	signal s_reg_tx_data  : std_logic_vector(39 downto 0);
	signal s_reg_tx_val   : std_logic;
	signal s_reg_tx_preval: std_logic;
	-- regional pause
	signal s_daq_pause    : t_mid_daq_handshake;
	-- regional status
	signal s_reg_active   : std_logic;
	signal s_reg_inactive : std_logic := '0';
	signal s_reg_overflow : std_logic;
	signal s_reg_missing  : std_logic_vector(11 downto 0);
    -- regional crate ID 
	signal s_reg_crateID     : std_logic_vector(3 downto 0);
	signal s_reg_crateID_val : std_logic;
	-- regional data 
	signal s_reg_val      : std_logic;
	signal s_reg_data     : std_logic_vector(39 downto 0);
	-- regional data rx
	signal s_reg_rx_val   : std_logic;
	signal s_reg_rx_data  : std_logic_vector(39 downto 0);
	
	-- stop reading fifo 
	signal s_stop_reading : std_logic;
	
begin 
	--==========================================--
	-- continuous and triggered operation modes --
	--==========================================--
    -- DAQ is enabled between sox trigger from the LTU and the eox trigger from all active e-links
	-- MID e-link rx enable input is valid when the GBT link is connected and ready  
	-- MID e-link rx valid input is valid during 1 out 6 (240MHz) clock cycles
	--==============--
	-- REGIONAL ZS	--
	--==============--
	regional_zs_inst: regional_zs
	port map (
	clk_240        => clk_240,
	--
	reset_i        => reset_i,
	--
	reg_en_i       => daq_enable_i,
	reg_val_i      => gbt_val_i,
	reg_data_i     => gbt_data_i,
	--
	reg_val_o      => s_reg_val,
	reg_data_o     => s_reg_data);
	--==================--
	-- REGIONAL SYNC 	--
	--==================--
	regional_sync_inst: regional_sync
	generic map ( g_REGIONAL_ID => g_REGIONAL_ID, g_LINK_ID => g_LINK_ID)
	port map (
	clk_240           => clk_240,
	--
	reset_i           => reset_i,
	--
	daq_enable_i      => daq_enable_i,
	daq_resume_i      => daq_resume_i,
	daq_pause_o       => s_daq_pause, 
    --
	ttc_mode_i        => ttc_mode_i,
	--
	mid_sync_i        => mid_sync_i,	
	--
	reg_val_i         => s_reg_val,
	reg_data_i        => s_reg_data,
	reg_full_i        => s_full,
	reg_inactive_i    => s_reg_inactive,
	--
	reg_val_o         => s_reg_rx_val,
	reg_data_o        => s_reg_rx_data,
	reg_missing_o     => s_reg_missing,
	reg_active_o      => s_reg_active,
	reg_overflow_o    => s_reg_overflow,
	reg_crateID_o     => s_reg_crateID,
	reg_crateID_val_o => s_reg_crateID_val);
	--======================--
	-- REGIONAL FIFO_40x168 --
	--======================--
	fifo_40x128_inst: fifo_40x128
	port map (
	data           => s_reg_rx_data,
	wrreq          => s_reg_rx_val,
	rdreq          => reg_rdreq_i,
	clock          => clk_240,
	sclr           => reset_i,
	q              => s_reg_tx_data,
	full           => s_full,
	empty          => s_empty,
	usedw          => s_usedw); 
	--===========================================================================
	-- Begin of p_reg_pipe
	-- pipeline to overcome the latency of the fifo (2 clk cycles)
	--===========================================================================
	p_reg_pipe: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  -- pipeline 
	  s_reg_tx_preval <= reg_rdreq_i;   -- 1st stage 
	  s_reg_tx_val <= s_reg_tx_preval;  -- 2nd stage
	 end if;
	end process p_reg_pipe;
	--===========================================================================
	-- Begin of p_reg_inactive
	-- This process activates and desactivates the inactive signal 
	-- This signal is used to monitor the eox event 
	--===========================================================================
	p_reg_inactive: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  if reset_i = '1' then 
	   s_reg_inactive <= '0';   
	  else 
	   -- eox event  
	   if s_reg_tx_val = '1' and s_reg_tx_data(30) = '1' then 
	    s_reg_inactive <= '1';  -- local card inactive (end of run)
	   end if; 
	  end if; 
	 end if; 
	end process p_reg_inactive;
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
	   ovf_inc   := (others => '0');            -- reset overflow counter 
	   usedw_inc := (others => '0');            -- reset used word counter 
	  else
       
	   -- daq resume orbit 
	   if daq_resume_i.orb = '1' then
        ovf_inc   := (others => '0');           -- initial condition 
        usedw_inc := (others => '0');           -- initial condition

	   -- overflow  
	   elsif s_reg_overflow = '1' then
	    -- concatenate (read & write)
	    read_wr := reg_rdreq_i & s_reg_rx_val; 
	    case read_wr is 
         when "01" =>                          -- write
	      ovf_inc   := ovf_inc+1;              -- increment overflow counter
	      usedw_inc := unsigned(s_usedw)+1;    -- fifo word increment ahead
	     when "10" =>                          -- read 
	      usedw_inc := unsigned(s_usedw)-1;    -- fifo word decrement ahead
	     when "11" =>                          -- read and write
	      ovf_inc   := ovf_inc+1;              -- increment overflow counter 
	      usedw_inc := unsigned(s_usedw);      -- copy fifo word counter 
	     when others => null;
	    end case;

	    -- compare overflow cnt & used word counter
	    if ovf_inc = usedw_inc then 
         s_stop_reading <= '1';                -- stop reading data from fifo
        end if;
	   end if;
	  end if;
	 end if;
	end process p_cnt_ovf; 

	-- output data  
	daq_pause_o.orb   <= s_daq_pause.orb or s_reg_overflow;
	daq_pause_o.eox   <= s_daq_pause.eox;
	daq_pause_o.close <= s_daq_pause.close;


	reg_data_o     <= s_reg_tx_data;
	reg_val_o      <= s_reg_tx_val;
	reg_empty_o    <= s_stop_reading or s_empty;
	reg_afull_o    <= s_usedw(6) and not(s_empty);
	reg_active_o   <= s_reg_active;
	reg_inactive_o <= s_reg_inactive;
	reg_missing_o  <= s_reg_missing;
	reg_crateID_o  <= s_reg_crateID;
	reg_crateID_val_o  <= s_reg_crateID_val;

end rtl;
--===========================================================================--
-- architecture end
--============================================================================--