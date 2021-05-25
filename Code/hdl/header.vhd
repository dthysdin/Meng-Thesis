-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : header.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-06-30
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes 
-- <12-10-2020> Additional pipeline 
-- <27-11-2020> Clear fifos for every sox from ttc
-- <18-12-2020> Send pulses for every heartbeat and eox triggers
-------------------------------------------------------------------------------
-- TODO:  Completed 
-- <nothing to do>
-------------------------------------------------------------------------------
-- Description:
-- The objective of the code below is to update the raw data header (RDH) found 
-- in the transmitter module.
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
--Entity declaration for header
--=============================================================================
entity header is
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240	       : in std_logic;
	-------------------------------------------------------------------
	-- reset --  	
	reset_i        : in std_logic;                  
	-------------------------------------------------------------------
	-- timing and trigger system --
	ttc_data_i     : in t_mid_ttc;
	-------------------------------------------------------------------
	-- trigger pulses --
	sox_pulse_i    : in std_logic;
	hbt_pulse_i    : in std_logic;
	eox_pulse_i    : in std_logic;
	-------------------------------------------------------------------
	-- header info --
	header_rdreq_i : in std_logic;
	header_o       : out t_mid_hdr
	--------------------------------------------------------------------
       );  
end header;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of header is
    -- ===================================================
	-- SYMBOLIC ENCODED state machine: t_state
	-- ===================================================	
	type t_state is (IDLE, 
		            REFRESH, 
		            UPDATE);
		 
    signal state : t_state := idle;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- header fifo  --
	signal s_data, s_rx_data : std_logic_vector(63 downto 0);
	signal s_data_val      : std_logic;
	signal s_full          : std_logic;
	signal s_empty         : std_logic;
	signal s_usedw         : std_logic_vector(2 downto 0);
    
	-- bunch crossing ID 
	signal s_bcid          : std_logic_vector(15 downto 0);

	-- pipeline tx  
	signal s_tx_data     : std_logic_vector(63 downto 0) := (others => '0');
	signal s_tx_predata  : std_logic_vector(63 downto 0) := (others => '0');
	signal s_tx_val      : std_logic;
	signal s_tx_preval   : std_logic := '0';
 
begin  
    --=============================================================================
	-- Begin of p_state
	-- This is a sequential state machine 
	--=============================================================================
	p_state: process(clk_240)
	begin 
	 if rising_edge(clk_240) then 
	  -- default --
	  s_data_val  <= '0';
	  s_data <= (others => '0');

	  if reset_i = '1' then 
       state <= IDLE;
	  else 
			
	   case state is 
	   --========--
	   --  IDLE   --
	   --========--
	   -- state"IDLE"
	   when IDLE => 
	    if s_full /= '1' then
	     -- sox 
	     if sox_pulse_i = '1' then  
	      state <= REFRESH;
		 -- eox or heartbeat
		 elsif hbt_pulse_i = '1' or eox_pulse_i = '1' then 
		  state <= UPDATE;
	     end if;
	    else
	     state <= IDLE;
	    end  if;
       --=========--
       -- REFRESH --
       --=========--
       -- state "REFRESH"
       when REFRESH => 
        -- check fifo clean 
        if s_empty = '1' then
         state <= UPDATE;
        end if; 
       --========--
       -- UPDATE --
       --========--
       -- state"UPDATE"
	   when UPDATE => 
	    s_data <= ttc_data_i.trg & ttc_data_i.orbit;
	    s_data_val <= '1';
	    s_bcid <= ttc_data_i.bcid;
	    state <= IDLE;
       --========--
       -- OTHERS --
       --========--
       -- state"OTHERS"
	   when others => 
	    state <= IDLE;
	   end case;
	  end if;
     end if;
	end process p_state;
	--=========================--
	-- UPDATED HEADER FIFO64x8 --
	-- MLAB memory type 
	-- look ahead rdreq mode
	--=========================--
	UHF64:fifo_64x8
	port map (
	data	  => s_data,
	wrreq	  => s_data_val,
	rdreq	  => header_rdreq_i,
	clock	  => clk_240,
	sclr	  => reset_i,
	q	      => s_rx_data,
	usedw	  => s_usedw,
	full	  => s_full,
	empty	  => s_empty
	);

	--===========================================================================
	-- Begin of p_txpipeline
	-- pipeline to overcome the latency of the fifo (2 clk cycles)
	--===========================================================================
	p_txpipeline: process(clk_240)
	begin 
     if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_tx_data <= (others => '0');
	  else 
	   s_tx_preval <= header_rdreq_i;  -- 1st stage
       s_tx_val <= s_tx_preval;   -- 2nd stage 
				
	   -- stage #1 
       if header_rdreq_i = '1' then 
	    s_tx_predata <= s_rx_data;
	   -- stage #2 
	   elsif s_tx_preval = '1' then 
	    s_tx_data <= s_tx_predata;
	   end if;
	  end if;
	 end if;
	end process p_txpipeline;
	-- header_counter 
	header_o.cnt       <= s_usedw;
	-- header ready
	header_o.ready      <= not (s_empty);
	-- header valid 
	header_o.valid      <= s_tx_val;
	-- header bcid 
	header_o.data.bcid  <= s_bcid;
	-- header trigger 
	header_o.data.trg   <= s_tx_data(63 downto 32);
	-- header orbit
	header_o.data.orbit <= s_tx_data(31 downto 0);

end rtl;
--=============================================================================
-- architecture end
--=============================================================================		