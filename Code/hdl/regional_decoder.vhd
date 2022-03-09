-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : regional_decoder.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-01-30
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes	: 
-- <23-06-2020> Use variables instead of signals 
-- <29-09-2020> Additional comments 
-- <13-13-2020> Add signals 
--		Change the name of the state from state_reg to state
--		Change the name of the input port  from elink_bus_i to reg_data_i
--		Change the name of the output port from elink_bus_o to reg_data_o
--		Change the name of the output port from elink_en_o to reg_val_o
--		Additional comments
-- <13-11-2020> Improve the compactibility of the the trigger state
-- <05-12-2020> Only decode data within a timeframe (sox - eox)
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to perform the event identification.
-- This is achieved by identifying the start bit and the card type of the Regional frame as 
-- well as the trigger types, the internal bunch crossing, 
-- the crate ID and different local cards belonging to the same event.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Reference:
-- This code follows the requirements provided by Dr. Christophe Renard (MID FEE engineer) 
-- For more information about the event formats of the MID readout electronics follow the link below
-- http://www-subatech.in2p3.fr/~electro/projets/alice/dimuon/trigger/upgrade/index.html
----------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
--=============================================================================
--Entity declaration for regional_decoder
--=============================================================================
entity regional_decoder is
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240      : in std_logic;
	-------------------------------------------------------------------
	-- avalon + auto reset --  
	reset_i      : in std_logic;		                
	-------------------------------------------------------------------
	-- reg card info -- 
	--< in 
	reg_en_i     : in std_logic;	
	reg_val_i    : in std_logic;	       	      
	reg_data_i   : in std_logic_vector(7 downto 0);    
	--> out
	reg_val_o    : out std_logic;                      
	reg_data_o   : out std_logic_vector(39 downto 0)  
	-------------------------------------------------------------------
	 );  
end regional_decoder;
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of regional_decoder is
	-- =================================================
	-- SYMBOLIC ENCODED state machine: state_reg
	-- =================================================
	type t_reg_state is (IDLE, 
                        TRG, 
                        IBC_1, 
                        IBC_2, 
                        DEC);	
								
	signal state : t_reg_state;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_reg_data: std_logic_vector(39 downto 0);
	signal s_reg_val : std_logic;
--=============================================================================
-- architecture begin
--=============================================================================
begin
	--=============================================================================
	-- Begin of p_regional
	-- The size of the regional event is 5 bytes
	-- The time required to collect the complete regional event is 5 LHC clock cycles
	-- (@40 Mhz) or 30 CRU clock cycles (@240MHz)
	--=============================================================================
	p_regional: process(clk_240)
	-- Define variables 
	variable checker  : std_logic_vector(7 downto 0) := x"00";
	variable format   : std_logic_vector(7 downto 0) := x"00";
	variable trigger  : std_logic_vector(7 downto 0) := x"00";
	variable ibc      : std_logic_vector(15 downto 0):= x"0000";
	variable position : std_logic_vector(3 downto 0) := x"0";
	variable tracklet : std_logic_vector(3 downto 0) := x"0";
	
	begin 
	 if rising_edge (clk_240) then
	  -- default --
	  s_reg_val <= '0';
	  s_reg_data <= (others => '0');
			
	  if reset_i = '1' then 
	   state <= idle;
	  else  
	   -- regional decoder enable    
	   if reg_en_i = '1' then 
	    if reg_val_i = '1' then 
	    case state is
	    --=======--
	    --  IDLE --
	    --=======--	
	    -- state "idle"
	    when idle => 
	     format  := reg_data_i;	          -- status byte
		 checker := x"C0" and reg_data_i; -- valid event checker  

		 -- check regional start bit('1') & card type('0')
	     if checker = x"80" then
	      state <= trg;
	     else 
	      state <= idle;   
	     end if;
        --======--
        -- TRG  --
        --======--	
	    -- state "trg"
	    when trg => 
		 -- copy trigger byte
	     trigger := reg_data_i; 
		 checker := x"F0" and reg_data_i; -- valid trigger checker  

	     -- sox trigger event
	     if reg_data_i(7) = '1' then 
		  if checker = x"80" then 
	       state <= ibc_1;           
		  else 
           state <= idle;             
		  end if;

		 -- eox trigger event
		 elsif reg_data_i(6) = '1' then
		  if checker = x"40"  then 
			state <= ibc_1;        
		  else 
			state <= idle;           
		  end if;

		 -- other trigger           
	     else
	      state <= ibc_1;            
	     end if;
	    --=======--
	    -- IBC_1 --
	    --=======--	
	    -- state "ibc_1"
	    when ibc_1 => 
         -- copy internal bunch counter(1)
	     ibc(15 downto 8) := reg_data_i;  -- internal bunch counter#1 
		 checker := x"F0" and reg_data_i;   -- check ibc1 byte 

	     if checker = x"00" then 
		  state <= ibc_2;           
		 else  
	      state <= idle;             
	     end if;
	    --========--
        -- IBC_2  --
	    --========--	
	    -- state "ibc_2"
	    when ibc_2 =>		
         ibc(7 downto 0) := reg_data_i;	 -- internal bunch counter#2
         state <= dec;
	    --======--
	    --  DEC --
	    --======--
	    -- state "dec"
        when dec =>	
	     position := reg_data_i(7 downto 4); -- position of local in crate
	     tracklet := reg_data_i(3 downto 0); -- patterns tracklet 	 		
	     s_reg_data <= format & trigger & ibc & position & tracklet;
	     s_reg_val <= '1';
	     state <= idle; 
	    --==========--
	    -- OTHERS" --
	    --==========--	
	    -- all the other states (not defined)
	    when others => 
	     -- jump to save state (ERROR?!)
	     state <= idle;					 
	    end case;
		end if; -- gtb data valid
	   end if;  -- daq valid (TTC trigger received after reset) 
      end if;   -- synchronous reset   
	 end if;    -- synchronous clock
	end process p_regional;
	
	-- output frame 
	reg_val_o <= s_reg_val;
	reg_data_o <= s_reg_data;
	
end rtl;
--=============================================================================
-- architecture end
--=============================================================================