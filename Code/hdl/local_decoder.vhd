-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : local_decoder.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-01-29
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes: 
-- <04-06-2020> Use variables instead of signals 
-- <29-09-2020> Additional comments 
-- <13-10-2020> Add signals 
--		Change the name of the state from state_loc to state
--		Change the name of the input port  from elink_bus_i to loc_data_i
--		Change the name of the output port from elink_bus_o to loc_data_o
--		Change the name of the output port from elink_en_o to loc_val_o
--		Additional comments
-- <13-11-2020> Improve the compactibility of the the trigger state
-- <05-12-2020> Only decode data within the timeframe (sox - eox)
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to perform the event identification.
-- This is achieved by identifying the start bit and the card type of the Local frame as 
-- well as the trigger types, the internal bunch crossing, the board ID and different chambers
-- belonging to the same event. 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Reference:
-- This code follows the requirements provided by Dr. Christophe Renard (MID FEE) 
-- For more information about the events formats of the MID readout electronics follow the link below
-- http://www-subatech.in2p3.fr/~electro/projets/alice/dimuon/trigger/upgrade/index.html
----------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
--=============================================================================
--Entity declaration for local_decoder
--=============================================================================
entity local_decoder is
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240	    : in std_logic;
	-------------------------------------------------------------------
	-- avalon + auto reset --  
	reset_i     : in std_logic;		                
	-------------------------------------------------------------------
	-- local card info -- 
	--< in 
	loc_en_i    : in std_logic;		               	                
	loc_data_i  : in std_logic_vector(7 downto 0);  
	--> out 
	loc_val_o   : out std_logic;		                 
	loc_data_o  : out std_logic_vector(167 downto 0)  
	-------------------------------------------------------------------
	 );  
end local_decoder;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of local_decoder is
	-- =================================================
	-- SYMBOLIC ENCODED state machine: state_loc
	-- =================================================
	type t_loc_state is (IDLE, 
                        TRG,
						IBC_1, 
                        IBC_2, 
                        DEC, 
                        STRIP);
								
	signal state : t_loc_state;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_checker: std_logic_vector(7 downto 0);
	signal s_loc_data: std_logic_vector(167 downto 0);
	signal s_loc_val : std_logic;
--=============================================================================
-- architecture begin
--============================================================================= 
begin
	-- checker 
    s_checker <= x"F0" and loc_data_i when state /= IDLE else x"00";
	--=============================================================================
	-- Begin of p_local
	-- This process identify the local data event frame 
	-- The size of the local event differs from 5 to 21 bytes
	-- The time required to collect the complete local event varies from 5 to 21 LHC 
	-- clock cycles (@40 Mhz) or from 30 to 126 CRU clock cycles (@240MHz)
	-- The local tracklet is 4-bit and it's used to identify the duration of the event.
	-- Each bit represents a single MID chamber, for each chamber fired, the duration of 
	-- the event is extended by 4 LHC clock cycle (4 bytes). 
	--=============================================================================
	p_local: process(clk_240)
	 -- Define variables 
	 variable format  : std_logic_vector(7 downto 0) := x"00";
	 variable trigger : std_logic_vector(7 downto 0) := x"00";
	 variable ibc     : std_logic_vector(15 downto 0):= x"0000";
	 variable position: std_logic_vector(3 downto 0) := x"0";
	 variable tracklet: std_logic_vector(3 downto 0) := x"0";
	 variable chambers: std_logic_vector(127 downto 0):= (others => '0');
	 variable index   : integer range 0 to 16:= 0;

	begin
	 if rising_edge(clk_240) then 
	  -- default  --
	  s_loc_val  <= '0';
	  s_loc_data <= (others => '0');
		
	  if reset_i = '1' then 
	   state <= idle;
	  else 
	   -- local decoder enable
	   if loc_en_i = '1' then 	   
	    case state is
	    --=======--
	    --  IDLE  --
	    --=======--	
	    -- state "idle"
	    when idle => 	
	     chambers := (others => '0'); -- reset strip patterns data
	     index := 0;                  -- reset index counter
	     format := loc_data_i;        -- copy status byte
		  
	     -- identify the start bit of the local frame (always '1') 
	     -- identify the card type of local frame (always '1')
	     if loc_data_i(7 downto 6) = "11" then
	      state <= trg;
	     else 
	      state <= idle;   
	     end if;	
	    --=====--  
	    -- TRG --
	    --=====--	
	    -- state "trg"
	    when trg => 
	     -- copy trigger byte
	     trigger := loc_data_i;  

	     -- sox trigger event
	     if loc_data_i(7) = '1' then 
		  if s_checker = x"80" then 
	       state <= ibc_1;          
		  else 
           state <= idle;            
		  end if;

		 -- eox trigger event
		 elsif loc_data_i(6) = '1' then
		  if s_checker = x"40"  then 
			state <= ibc_1;         
		  else 
			state <= idle;          
		  end if;

		 -- pause trigger event 
		 elsif loc_data_i(5) = '1' then
		   state <= idle;            

		 -- resume trigger event 
		 elsif loc_data_i(4) = '1' then
		  state <= idle;

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
	     ibc(15 downto 8) := loc_data_i;
		 -- check bcid data 
	     if s_checker = x"00" then 
		  state <= ibc_2;           
		 else  
	      state <= idle;             
	     end if;
	    --=======--
	    -- IBC_2 --
	    --=======--	
	    -- state "ibc_2"
	    when ibc_2 =>
	     -- internal bunch counter(2)
	     ibc(7 downto 0) := loc_data_i;		
	     state <= dec;	
        --=====--
	    -- DEC --
	    --=====--
	    -- state "dec"
	    when dec =>
         -- position of local in crate
	     position := loc_data_i(7 downto 4);
         -- tracklet of strip patterns	 
	     tracklet := loc_data_i(3 downto 0);	 
	     if tracklet = x"0" then
          -- local event with no strip patterns
	      s_loc_data <= format & trigger & ibc & position & tracklet & chambers;
	      s_loc_val <= '1'; 			
	      state <= idle; 
	     else
	      -- local event with strip patterns
	      state <= strip;
	     end if;
        --=======--
	    -- STRIP --
	    --=======--
	    -- state"strip" --
	    when strip => 
	     if index <= 15 then  
	      -- index counter will vary from 0 to 16 then reset
	      -- increment index counter
	      chambers(127 - 8*index downto 120 - 8*index) := loc_data_i;	
	      index := index + 1;												 
	     end if;

	     case tracklet is 
	     when x"1"|x"2"|x"4"|x"8" => 
	      -- 1 chamber
	      if index = 4 then 
	       s_loc_data <= format & trigger & ibc & position & tracklet & chambers;
	       s_loc_val <= '1'; 
	       state <= idle;
	      end if;
	     when x"3"|x"5"|x"6"|x"9"|x"A"|x"C" => 
	      -- 2 chambers 
	      if index = 8 then 
	       s_loc_data <= format & trigger & ibc & position & tracklet & chambers;
	       s_loc_val <= '1'; 
	       state <= idle;
	      end if;
	     when x"7"|x"B"|x"D"|x"E" => 
	      -- 3 chambers
	      if index = 12 then 
	       s_loc_data <= format & trigger & ibc & position & tracklet & chambers;
	       s_loc_val <= '1'; 
	       state <= idle;
	      end if;
	     when x"F" => 
	      -- 4 chambers 
	      if index = 16 then 
	       s_loc_data <= format & trigger & ibc & position & tracklet & chambers;
	       s_loc_val <= '1'; 
	       state <= idle;
	      end if;
	     when others => -- x"0" should not happen
	      -- jump to save state (ERROR?!)
	      state <= idle;
	     end case;
	    --==========--
	    -- OTHERS" --
	    --==========--	
	    -- state"others" 
	    when others => 	
	     -- jump to save state (ERROR?!)
	     state <= idle;
	    end case;
	   end if;	-- link up & data valid 
	  end if;	-- synchronous reset  
     end if;	-- synchronous clock
	end process p_local;
	
	-- output 
	loc_val_o <= s_loc_val;
	loc_data_o <= s_loc_data ;
	
end rtl;
--=============================================================================
-- architecture end
--=============================================================================