-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project   : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File      : packetizer.vhd
-- Author    : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No: 214349721
-- Company   : NRF iThemba LABS
-- Created   : 2020-10-12
-- Platform  : Quartus Pro 18.1
-- Standard  : VHDL'93'
-- Version   : 0.7
-------------------------------------------------------------------------------
-- last changes: 
-- <13-10-2020> This module has been completly redesigned
--		In this new version the rl_link module has been removed and incoprated here.
--              Futhermore an addition of pipeline registers are added to deal with
--              the timing viloated paths has been added. 
-- <27-11-2020> Reset the module before starting a new run
-- <11/12/2020> synchronize the timeframes 
-- <13/02/2021> add payload active to the output
------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
-- Description:
-- This module encodes the byte fragments transmitted by the elink modules
-- and gerates 256-bit packets which will then be fowarded to the transmitter module
-- The packets fowarded are generated from the upper and lower parts of the GBT link.

-- The size of the packets transfered is stored in a memory called payload (fifo). 
-- This is necessary to avoid sending packets from 2 diffrerent HBF at the same time. 
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
--Entity declaration for transmitter
--=============================================================================
entity packetizer is
	generic (g_NUM_HBFRAME_SYNC: integer; g_LINK_ID : integer);
	port (
	-------------------------------------------------------------------
	-- 240 MHz clock --
	clk_240         : in std_logic;
	-------------------------------------------------------------------
	-- reset --	
    reset_i         : in std_logic;
	-------------------------------------------------------------------		
	-- pulses --
	sox_pulse_i     : in std_logic;	
	sel_pulse_i     : in std_logic;		
	-------------------------------------------------------------------
    -- mid ttc mode --					 
	ttc_mode_i      : in t_mid_mode;					   								   
	-------------------------------------------------------------------
	-- mid gbt data -- 
	gbt_data_i      : in std_logic_vector(79 downto 0);	
	gbt_val_i       : in std_logic;		
	-------------------------------------------------------------------
	-- missing event counter
	missing_event_cnt_o : out std_logic_vector(11 downto 0);
	-------------------------------------------------------------------		
	-- packet info --
	packet_o        : out t_mid_pkt_array(1 downto 0);		
	packet_active_o : out std_logic_vector(9 downto 0);				
	packet_rdreq_i  : in std_logic_vector(1 downto 0);				
	-------------------------------------------------------------------
	-- payload info --					
	payload_o       : out t_mid_pload;
	payloadID_o     : out std_logic_vector(3 downto 0);
	payload_empty_o : out std_logic_vector(1 downto 0);				
	payload_rdreq_i : in std_logic_vector(1 downto 0)						
	-------------------------------------------------------------------
	     );  
end packetizer;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of packetizer is
	-- ========================================================
	-- constant declarations
	-- ======================================================== 
	constant NULL_DATA : std_logic_vector(255 downto 0) := (others => '0'); 
	constant MAX_BYTE  : integer := 31;                                     
	-- ========================================================
	-- type declarations
	-- ========================================================
	type t_i32_array is array (natural range <>) of integer range 0 to 31;
	type t_u16_array is array (natural range <>) of unsigned(15 downto 0);
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- elink mux info 
	signal s_mux_val  : std_logic_vector(1 downto 0);
	signal s_mux_stop : std_logic_vector(1 downto 0);
	signal s_mux_data : Array8bit(1 downto 0);
	signal s_crateID  : Array4bit(1 downto 0);
	signal s_active   : std_logic_vector(9 downto 0);
	signal s_missing_cnt: t_mid_missing_cnt_array(1 downto 0);
	signal s_missing_event_cnt: unsigned(11 downto 0) := (others => '0');

	-- temporary registers 
	signal s_temp_size_val : std_logic_vector(1 downto 0);
	signal s_temp_size     : Array16bit(1 downto 0);
	signal s_temp_val      : std_logic_vector(1 downto 0);
	signal s_temp_done     : std_logic_vector(1 downto 0);
	signal s_temp_stop     : std_logic_vector(1 downto 0) := "00";
	signal s_temp_data     : Array256bit(1 downto 0) := (others => (others => '0'));
	
	-- packet --
	-- rx fifo
	signal s_packet_empty    : std_logic_vector(1 downto 0); -- empty
	signal s_packet_wrreq    : std_logic_vector(1 downto 0); -- wrreq
	signal s_packet_rx_data  : Array256bit(1 downto 0);      -- data 
	-- tx fifo 
	signal s_packet_tx_data  : Array256bit(1 downto 0);	     -- data 
	signal s_packet_full     : std_logic_vector(1 downto 0); -- full 
	signal s_packet_tx_val   : std_logic_vector(1 downto 0); -- val 
	
	-- payload -- 
	-- rx fifo
	signal s_payload_empty   : std_logic_vector(1 downto 0); -- empty 
	signal s_payload_wrreq   : std_logic_vector(1 downto 0); -- wrreq
	signal s_payload_rx_data : Array16bit(1 downto 0);	     -- data 
	-- tx fifo
	signal s_payload_tx_data :  Array16bit(1 downto 0);	     -- data  
	signal s_payload_full    : std_logic_vector(1 downto 0); -- full
	signal s_payload_tx_val  : std_logic_vector(1 downto 0); -- val 
	
	-- pipeline payload registers 
	signal s_pipe_val    : std_logic;		                 -- val 
	signal s_pipe_predata:  Array16bit(1 downto 0);	         -- predata
	signal s_pipe_data   :  Array16bit(1 downto 0);	         -- data 
	

begin 
	--=============================================================================
	-- Begin of ELINK_MUX_GEN
	-- This statement generates the elink_mux twice
	--=============================================================================
	ELINK_MUX_GEN : for i in 0 to 1 generate
		--===========--
		-- ELINK_MUX --
		--===========--
		elink_mux_inst: elink_mux
		generic map (g_REGIONAL_ID => i, g_NUM_HBFRAME_SYNC => g_NUM_HBFRAME_SYNC, g_LINK_ID => g_LINK_ID)
		port map (
		clk_240	       => clk_240,  
		--		
		reset_i	       => reset_i,
		--
		sox_pulse_i    => sox_pulse_i,
		ttc_mode_i     => ttc_mode_i,						
		--	
		packet_full_i  => s_packet_full(i),
		--
		gbt_data_i     => gbt_data_i(39+40*i downto i*40),
		gbt_val_i      => gbt_val_i,
		-- 
		active_o       => s_active(4+i*5 downto 0+i*5),
		crateID_o      => s_crateID(i),
		missing_cnt_o  => s_missing_cnt(i),
		--
		mux_val_o      => s_mux_val(i),
		mux_stop_o     => s_mux_stop(i),
		mux_data_o     => s_mux_data(i));  
		--========================--
		-- PACKETIZER PACKET_FIFO --
		--========================--
		fifo_256x256_inst: fifo_256x256
		port map (
		data	       => s_packet_rx_data(i),
		wrreq	       => s_packet_wrreq(i),
		rdreq	       => packet_rdreq_i(i),
		clock	       => clk_240,
		sclr	       => reset_i,
		q              => s_packet_tx_data(i),
		full	       => s_packet_full(i),
		empty	       => s_packet_empty(i));
		--==============================--
		-- PACKETIZER PAYLOAD_SIZE_FIFO -- 
		-- MLAB memory type (look ahead read mode)
	    -- rdreq is used as read acknoledge 
		--==============================--
		fifo_16x8_inst: fifo_16x8
		port map (
		data           => s_payload_rx_data(i),
		wrreq	       => s_payload_wrreq(i),
		rdreq          => payload_rdreq_i(i),
		clock	       => clk_240,
		sclr           => reset_i,
		q              => s_payload_tx_data(i),
		full           => s_payload_full(i),
		empty          => s_payload_empty(i));
	end generate ELINK_MUX_GEN;
    --=============================================================================
	-- Begin of p_missing_event_cnt
	-- This process adds the number of events rejected during the daq
	--=============================================================================
	p_missing_event_cnt: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
	   s_missing_event_cnt <= (others => '0');
	  else 
	   if s_missing_event_cnt /= x"FFF" then 
	    s_missing_event_cnt <= sum_Array12bit(s_missing_cnt);
	   end if;
	  end if;
     end if;
	end process p_missing_event_cnt;
	--=============================================================================
	-- Begin of p_temp_stop
	-- This process stops the aquisition of byte data once the a hearbeat frame or
	-- a time frame have been collected from all active e-links
	--=============================================================================
	p_temp_stop: process(clk_240)
	begin
	 if rising_edge(clk_240) then
      if reset_i = '1' then 
	   s_temp_stop <= "00"; 
	  else 
	   for i in 0 to 1 loop    
		if s_mux_stop(i) = '1' or sel_pulse_i = '1' then          -- collect FEE heartbeat frame
		 s_temp_stop(i) <= '1';                                   -- stop daq 
		elsif s_mux_val(i) = '0' and s_temp_stop(i) = '1' then
		 s_temp_stop(i) <= '0';                                   -- initial value 
		end if;
	   end loop;
	  end if;
     end if;
	end process p_temp_stop;
	--=============================================================================
	-- Begin of p_byte_mux
	-- This process stores data byte in a variable and generates 256-bit packets
	-- It also allows the payload fifo to know when to store data in memory. 
	--=============================================================================
	p_byte_mux: process(clk_240)
     variable index : t_i32_array(1 downto 0) := (others => 0);
	begin
	 if rising_edge(clk_240) then
	  -- default --
	  s_temp_val <= "00";   -- temporary valid 
	  s_temp_done <= "00";  -- temporary done
	  
	  if reset_i = '1' then
	   index(1 downto 0) := (others => 0); 
	  else 
	   for i in 0 to 1 loop
        -- valid mux byte --	 
	    if s_mux_val(i) = '1' then 
	     s_temp_data(i)(7+8*index(i) downto 8*index(i)) <= s_mux_data(i); -- collect 8-bit data 
         if index(i) = MAX_BYTE then 
		  -- max (256-bit)
	      s_temp_val(i) <= '1';
          index(i) := 0;
	     else 
	      index(i) := index(i) + 1;                                                  
         end if;

	    -- stop mux byte --
	    elsif s_temp_stop(i) = '1' then
	     if index(i) /= 0 then
		  -- stop before reaching 256-bit 
	      s_temp_data(i)(255 downto 8*index(i)) <= NULL_DATA(255 downto 8*index(i)); -- fill remaining space with zeros       
          s_temp_val(i)  <= '1'; 
	      s_temp_done(i) <= '1';
	      index(i) := 0;
	     else  
		  -- stop after reaching 256-bit 
	      s_temp_done(i) <= '1';
	     end if;
	    end if;
       end loop; 
      end if;
	 end if; 
	end process p_byte_mux;
	
	-- packet write request 
	s_packet_wrreq(0) <= s_temp_val(0) and (not s_packet_full(0));
	s_packet_wrreq(1) <= s_temp_val(1) and (not s_packet_full(1));
	-- copy packet data to fifo 
	s_packet_rx_data(0) <= s_temp_data(0);
	s_packet_rx_data(1) <= s_temp_data(1);

	--=============================================================================
	-- Begin of p_pushed
	-- This process counts the number of packet pushed to the packet memory 
	-- and store this the number of packet pushed in the payload load memoy.
	--=============================================================================
	p_pushed: process(clk_240)
	 variable selct : Array2bit(1 downto 0) :=(others => "00");
	 variable u_pushed: t_u16_array(1 downto 0) :=(others => x"0000");
	begin
	 if rising_edge(clk_240) then
	  if reset_i = '1' then 
       u_pushed(1 downto 0) :=(others => x"0000");
	  else 
	   -- default 
	   s_temp_size <= (others => x"0000");
	   s_temp_size_val <= "00";
			
	   for i in 0 to 1 loop
	   -- concatenate val & done 
	   selct(i) := s_temp_val(i) & s_temp_done(i);
		
	   -- muxtiplexer 
	   case selct(i) is 
        when "10" => 
         -- packet valid 
         u_pushed(i) := u_pushed(i) + 1; -- increment
	    when "01" =>
	     -- last packet pushed 	
	     s_temp_size(i) <= std_logic_vector(u_pushed(i)); -- push 
	     s_temp_size_val(i) <= '1';
	     u_pushed(i) := x"0000";
	    when "11" => 
         -- last packet valid 
         -- last packet pushed 
	     s_temp_size(i) <= std_logic_vector(u_pushed(i)+1); -- increment & push
	     s_temp_size_val(i) <= '1';
	     u_pushed(i) := x"0000";
	    when others => null;
	    end case;
	   end loop;
      end if;
	 end if;
	end process p_pushed;
	
	-- payload write request  
	s_payload_wrreq(0) <= s_temp_size_val(0) and (not s_payload_full(0));
	s_payload_wrreq(1) <= s_temp_size_val(1) and (not s_payload_full(1));
	
	-- copy payload rx data to fifo
	s_payload_rx_data(0)<= s_temp_size(0);
	s_payload_rx_data(1)<= s_temp_size(1);
	
	--===========================================================================
	-- Begin of p_pipe_mux
	-- This process multiplex the payload transmitted from the higher and lower
	--===========================================================================
	p_pipe_mux: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  -- default --
	  s_pipe_val <= '0';
	  s_pipe_data <= (others =>(others => '0'));
	  
	  for i in 0 to 1 loop 
	   -- copy data from the payload tx fifo
	   if payload_rdreq_i(i) = '1' then 
	    s_pipe_predata(i) <= s_payload_tx_data(i);   
	   end if;
	   -- payload available after 1 clk delay
	   s_payload_tx_val(i) <= payload_rdreq_i(i);    
	  end loop;
			
	  -- mux --
	  case s_payload_tx_val is	
	  when "01" => 
	   s_pipe_data(0) <= s_pipe_predata(0);
	   s_pipe_val <= '1';	

	  when "10" =>
	   s_pipe_data(1) <= s_pipe_predata(1);
	   s_pipe_val <= '1';	

	  when "11" =>
	   s_pipe_data(1) <= s_pipe_predata(1);
	   s_pipe_data(0) <= s_pipe_predata(0);
	   s_pipe_val <= '1';
	  when others => null;
	  end case;	
	 end if;
	end process p_pipe_mux;
	--===========================================================================
	-- Begin of p_pipe_mux
	-- This process multiplex the payload transmitted from the higher and lower
	--===========================================================================
	p_packet_val: process(clk_240)
	begin 
	 if rising_edge(clk_240) then
	  s_packet_tx_val <= packet_rdreq_i; -- packet data available after 1 clk 
     end if;
	end process p_packet_val;

	-- output missing events counter 
	missing_event_cnt_o <= std_logic_vector(s_missing_event_cnt);

    -- output packet 
	packet_active_o <= s_active; 
	gen_packet: for i in 0 to 1 generate 
    	packet_o(i).valid <= s_packet_tx_val(i);
		packet_o(i).ready <= not (s_packet_empty(i));
		packet_o(i).data  <= s_packet_tx_data(i);
	end generate;
	
	-- output payload 
	payload_o.data(0)  <= s_pipe_data(0);
	payload_o.data(1)  <= s_pipe_data(1);
	payload_o.valid    <= s_pipe_val;                   
	payload_o.ready    <= not (s_payload_empty(0) or s_payload_empty(1));  
	payloadID_o        <= s_crateID(0) or s_crateID(1);                             
	payload_empty_o    <= s_payload_empty;

end rtl;
--===========================================================================--
-- architecture end
--============================================================================--