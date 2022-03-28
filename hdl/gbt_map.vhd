-- File	     : gbt_map.vhd
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
--Entity declaration for gbt_map
--=============================================================================
entity gbt_map is
	generic ( g_NUM_GBT_INPUT: integer := 24; g_NUM_GBT_OUTPUT : natural := 16); 
	port (
	-------------------------------------------------------------------
	clk_240	        : in std_logic;
	gbt_rx_ready_i	: in std_logic_vector(g_NUM_GBT_INPUT-1 downto 0);
	gbt_rx_bus_i	: in t_cru_gbt_array(g_NUM_GBT_INPUT-1 downto 0);
	mid_mapping_i   : in std_logic_vector(4*g_NUM_GBT_OUTPUT-1 downto 0);  
	mid_rx_bus_o	: out t_mid_gbt_array(g_NUM_GBT_OUTPUT-1 downto 0)
	-------------------------------------------------------------------
	 );  
end gbt_map;
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of gbt_map is
--=============================================================================
-- architecture begin                                         
--=============================================================================   
                                                                                  

begin 

	--=============================================================================
	-- Begin of p_mid_mapping
	-- This process contains the gbt link signals used in this project.
	-- select active fibers: either default mapping (below), or "spare" fibre (8,9,10)
	--=============================================================================
	p_mid_mapping:process (clk_240)
	 variable epn0 : Array4bit(g_NUM_GBT_OUTPUT/2-1 downto 0) := (others => (others =>'0')); -- default 
	 variable epn1 : Array4bit(g_NUM_GBT_OUTPUT/2-1 downto 0) := (others => (others =>'0')); -- default
	 begin
	   if rising_edge(clk_240) then 
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
		 --====================================================================================================================================================================================
		 -- Link ID			EPN ID 			CRU ID			REGISTER			CURRENT MAPPING			SPARE LINK 8			SPARE LINK 9			SPARE LINK 10			SPARE LINK 11			
		 --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		 -- 0 				0				0				0xc8000C			0x0000_0000				0x0000_0001				0x0000_0002				0x0000_0003				0x0000_0004			            
		 -- 1				0				0				0xc8000C			0x0000_0000				0x0000_0010				0x0000_0020				0x0000_0030				0x0000_0040               
		 -- 2				0				0				0xc8000C			0x0000_0000				0x0000_0100				0x0000_0200             0x0000_0300             0x0000_0400
		 -- 3				0				0				0xc8000C			0x0000_0000				0x0000_1000				0x0000_2000             0x0000_3000             0x0000_4000  
		 -- 4				0				0				0xc8000C			0x0000_0000				0x0001_0000				0x0002_0000             0x0003_0000             0x0004_0000 
		 -- 5				0				0				0xc8000C			0x0000_0000				0x0010_0000             0x0020_0000				0x0030_0000             0x0040_0000
		 -- 6				0				0				0xc8000C			0x0000_0000				0x0100_0000				0x0200_0000             0x0300_0000             0x0400_0000 
		 -- 7				0				0				0xc8000C			0x0000_0000				0x1000_0000				0x2000_0000             0x3000_0000             0x4000_0000             
		 --===================================================================================================================================================================================
		 for i in 0 to g_NUM_GBT_OUTPUT/2-1 loop
		   -- output i <= choose input among i,8,9,10
		   epn0(i) := mid_mapping_i(4*i+3 downto 4*i);

		   case epn0(i) is
			 when x"1" =>
			   mid_rx_bus_o(i).en    <= gbt_rx_bus_i(8).is_data_sel and gbt_rx_ready_i(8);
			   mid_rx_bus_o(i).valid <= gbt_rx_bus_i(8).data_valid;
			   mid_rx_bus_o(i).data  <= gbt_rx_bus_i(8).data(79 downto 0);
			 when x"2" =>
			   mid_rx_bus_o(i).en    <= gbt_rx_bus_i(9).is_data_sel and gbt_rx_ready_i(9);
			   mid_rx_bus_o(i).valid <= gbt_rx_bus_i(9).data_valid;
			   mid_rx_bus_o(i).data  <= gbt_rx_bus_i(9).data(79 downto 0);
			 when x"3" =>
			   mid_rx_bus_o(i).en    <= gbt_rx_bus_i(10).is_data_sel and gbt_rx_ready_i(10);
			   mid_rx_bus_o(i).valid <= gbt_rx_bus_i(10).data_valid;
			   mid_rx_bus_o(i).data  <= gbt_rx_bus_i(10).data(79 downto 0);
			 when x"4" =>
			   mid_rx_bus_o(i).en    <= gbt_rx_bus_i(11).is_data_sel and gbt_rx_ready_i(11);
			   mid_rx_bus_o(i).valid <= gbt_rx_bus_i(11).data_valid;
			   mid_rx_bus_o(i).data  <= gbt_rx_bus_i(11).data(79 downto 0);
			 when others => 
			   mid_rx_bus_o(i).en    <= gbt_rx_bus_i(i).is_data_sel and gbt_rx_ready_i(i);
			   mid_rx_bus_o(i).valid <= gbt_rx_bus_i(i).data_valid;
			   mid_rx_bus_o(i).data  <= gbt_rx_bus_i(i).data(79 downto 0);     
		   end case;       
		 end loop;
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
		 --=====================================================================================================================================================================================
		 -- Link ID			EPN ID 			CRU ID			REGISTER			CURRENT MAPPING			SPARE LINK 8			SPARE LINK 9			SPARE LINK 10			SPARE LINK 11			
		 --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		 -- 0 				1				0				0xc80010			0x0000_0000				0x0000_0001				0x0000_0002				0x0000_0003				0x0000_0004			            
		 -- 1				1				0				0xc80010			0x0000_0000				0x0000_0010				0x0000_0020				0x0000_0030				0x0000_0040               
		 -- 2				1				0				0xc80010			0x0000_0000				0x0000_0100				0x0000_0200             0x0000_0300             0x0000_0400
		 -- 3				1				0				0xc80010			0x0000_0000				0x0000_1000				0x0000_2000             0x0000_3000             0x0000_4000  
		 -- 4				1				0				0xc80010			0x0000_0000				0x0001_0000				0x0002_0000             0x0003_0000             0x0004_0000 
		 -- 5				1				0				0xc80010			0x0000_0000				0x0010_0000             0x0020_0000				0x0030_0000             0x0040_0000
		 -- 6				1				0				0xc80010			0x0000_0000				0x0100_0000				0x0200_0000             0x0300_0000             0x0400_0000 
		 -- 7				1				0				0xc80010			0x0000_0000				0x1000_0000				0x2000_0000             0x3000_0000             0x4000_0000             
		 --===================================================================================================================================================================================
		 for i in 0 to g_NUM_GBT_OUTPUT/2-1 loop
		   -- output g_NUM_GBT_OUTPUT/2 + i <= choose input among g_NUM_GBT_INPUT/2+i,+8,+9,+10
		   epn1(i) := mid_mapping_i(2*g_NUM_GBT_OUTPUT+4*i+3  downto 2*g_NUM_GBT_OUTPUT+4*i); 

		   case epn1(i) is
			 when x"1" =>
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).en    <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+8).is_data_sel and gbt_rx_ready_i(g_NUM_GBT_INPUT/2+8);
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).valid <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+8).data_valid;
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).data  <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+8).data(79 downto 0);
			 when x"2" =>
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).en    <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+9).is_data_sel and gbt_rx_ready_i(g_NUM_GBT_INPUT/2+9);
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).valid <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+9).data_valid;
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).data  <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+9).data(79 downto 0);
			 when x"3" =>
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).en    <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+10).is_data_sel and gbt_rx_ready_i(g_NUM_GBT_INPUT/2+10);
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).valid <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+10).data_valid;
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).data  <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+10).data(79 downto 0);
			 when x"4" =>
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).en    <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+11).is_data_sel and gbt_rx_ready_i(g_NUM_GBT_INPUT/2+11);
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).valid <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+11).data_valid;
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).data  <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+11).data(79 downto 0);
			 when others =>
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).en    <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+i).is_data_sel and gbt_rx_ready_i(g_NUM_GBT_INPUT/2+i);
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).valid <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+i).data_valid;
			   mid_rx_bus_o(g_NUM_GBT_OUTPUT/2+i).data  <= gbt_rx_bus_i(g_NUM_GBT_INPUT/2+i).data(79 downto 0);
		   end case;
		 end loop;
	   end if;
	end process p_mid_mapping;   
end rtl;
--=============================================================================
-- architecture end
--=============================================================================