-- File	     : gbt_ulogic_select.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-01-30
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes	 
-- <23/09/2020> change the combitional process to sequencial 
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code is to select the number of gbt links used in this project
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Reference:
----------------------------------------------------------------------------------
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
--Entity declaration for gbt_ulogic_select
--=============================================================================
entity gbt_ulogic_select is
	generic ( g_NUM_GBT_INPUT: integer := 24; g_NUM_GBT_OUTPUT : natural := 16); 
	port (
	-------------------------------------------------------------------
	gbt_rx_ready_i	: in std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	gbt_rx_bus_i	: in t_cru_gbt_array(g_NUM_GBT_INPUT-1 downto 0);
	mid_rx_bus_o	: out t_mid_gbt_array(g_NUM_GBT_OUTPUT-1 downto 0)
	-------------------------------------------------------------------
	 );  
end gbt_ulogic_select;
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of gbt_ulogic_select is
--=============================================================================
-- architecture begin
--=============================================================================
begin 
	-- EPN#0
	-- Input  = gbt_rx_bus_i(11 downto 0)
	-- Output = mid_rx_bus_o(7 downto 0)
	--=================================================================================================================================================================
	-- Link ID   GBT Mode Tx/Rx   Loopback   GBT MUX        Datapath Mode   Datapath   RX freq(MHz)   TX freq(MHz)   Status   Optical power(uW)   System ID   FEE ID 
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- 0         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       417.8               0x0         0x0    
	-- 1         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       385.3               0x0         0x0    
	-- 2         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       275.4               0x0         0x0    
	-- 3         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       413.7               0x0         0x0    
	-- 4         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       359.6               0x0         0x0    
	-- 5         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       372.0               0x0         0x0    
	-- 6         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       392.9               0x0         0x0    
	-- 7         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       377.0               0x0         0x0    
	-- 8         GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.65         240.47         DOWN     0.0                 0x0         0x0    
	-- 9         GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.58         240.47         DOWN     0.0                 0x0         0x0    
	-- 10        GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.48         240.47         DOWN     0.0                 0x0         0x0    
	-- 11        GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   198.44         240.47         DOWN     0.0                 0x0         0x0    
	--=================================================================================================================================================================

	-- EPN#1
	-- Input  = gbt_rx_bus_i(23 downto 12)
	-- Output = mid_rx_bus_o(15 downto 8)
	--=================================================================================================================================================================
	-- Link ID   GBT Mode Tx/Rx   Loopback   GBT MUX        Datapath Mode   Datapath   RX freq(MHz)   TX freq(MHz)   Status   Optical power(uW)   System ID   FEE ID 
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- 0         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       417.8               0x0         0x0    
	-- 1         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       385.3               0x0         0x0    
	-- 2         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       275.4               0x0         0x0    
	-- 3         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       413.7               0x0         0x0    
	-- 4         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       359.6               0x0         0x0    
	-- 5         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       372.0               0x0         0x0    
	-- 6         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       392.9               0x0         0x0    
	-- 7         GBT/GBT          None       TTC:MIDTRG     Streaming       Enabled    240.47         240.47         UP       377.0               0x0         0x0    
	-- 8         GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.65         240.47         DOWN     0.0                 0x0         0x0    
	-- 9         GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.58         240.47         DOWN     0.0                 0x0         0x0    
	-- 10        GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   240.48         240.47         DOWN     0.0                 0x0         0x0    
	-- 11        GBT/GBT          None       TTC:MIDTRG     Streaming       Disabled   198.44         240.47         DOWN     0.0                 0x0         0x0    
	--=================================================================================================================================================================


	--=============================================================================
	-- Begin of p_link_slct
	-- This process contains the gbt link signals used in this project.
	--=============================================================================
	p_link_slct:process (gbt_rx_bus_i,gbt_rx_ready_i)
	begin 

	 -- EPN#0 
	 for i in 0 to g_NUM_GBT_OUTPUT/2-1 loop
	  mid_rx_bus_o(i).en    <= gbt_rx_bus_i(i).is_data_sel and gbt_rx_ready_i(i);
	  mid_rx_bus_o(i).valid <= gbt_rx_bus_i(i).data_valid;
	  mid_rx_bus_o(i).data  <= gbt_rx_bus_i(i).data(79 downto 0);
     end loop;

     -- EPN#1
	 for i in g_NUM_GBT_OUTPUT/2 to g_NUM_GBT_OUTPUT-1 loop
	  mid_rx_bus_o(i).en    <= gbt_rx_bus_i(i+4).is_data_sel and gbt_rx_ready_i(i+4);
	  mid_rx_bus_o(i).valid <= gbt_rx_bus_i(i+4).data_valid;
	  mid_rx_bus_o(i).data  <= gbt_rx_bus_i(i+4).data(79 downto 0);
	 end loop;
	end process;
end rtl;
--=============================================================================
-- architecture end
--=============================================================================