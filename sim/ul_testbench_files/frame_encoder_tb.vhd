-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	  : Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		  : elink_mux_decoder_tb.vhd
-- Author	  : Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No : 214349721
-- Company	  : NRF iThemba LABS
-- Created    : 2020-01-29
-- Platform   : Quartus Pro 18.1
-- Standard	  : VHDL'93'
-- Version	  : 0.3
-------------------------------------------------------------------------------

-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
--=============================================================================
--Entity declaration for encoder_tb
--=============================================================================
entity frame_encoder_tb is
	port (
	-------------------------------------------------------------------
	clk_240				: in std_logic;							-- TTC clock bus       
	reset_p				: in std_logic;							-- reset  
	--
	mux_val_i			: in std_logic;							-- valid 
	mux_data_i			: in std_logic_vector(7 downto 0);		-- data 
	--
	frame_val_o	: out std_logic;						        -- valid
	frame_data_o	: out std_logic_vector(167 downto 0)	    -- data 
	-------------------------------------------------------------------
	 );  
end frame_encoder_tb;	
--=============================================================================
-- architecture declaration
--=============================================================================
architecture rtl of frame_encoder_tb is
	-- =================================================
	-- SYMBOLIC ENCODED state machine: state_loc
	-- =================================================
	type t_mux_state is (	IDLE, 
							TRG, 
							IBC_1, 
							IBC_2, 
							DEC, 
							STRIP);
								
	signal state : t_mux_state;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_frame_data: std_logic_vector(167 downto 0);
	signal s_frame_val : std_logic;
--=============================================================================
-- architecture begin
--============================================================================= 
begin
	--=============================================================================
	-- Begin of p_encoder
	--=============================================================================
	p_encoder: process(clk_240)
		-- Define variables 
		variable format:	std_logic_vector(7 downto 0) 	:= x"00";
		variable trigger:	std_logic_vector(7 downto 0) 	:= x"00";
		variable ibc:		std_logic_vector(15 downto 0)	:= x"0000";
		variable position:	std_logic_vector(3 downto 0) 	:= x"0";
		variable tracklet:	std_logic_vector(3 downto 0) 	:= x"0";
		variable chambers:	std_logic_vector(127 downto 0):= (others => '0');
		variable index:		integer := 0;
	begin
		if rising_edge(clk_240) then 
		
			-- default  --
			s_frame_val  <= '0';
		
			if reset_p = '1' then 
				-- reset to default --
				state <= idle;
			else 
				-- mux byte valid --- 
				if mux_val_i = '1' then 	   
					case state is
					--=======--
					--  IDLE  --
					--=======--	
					-- state "idle"
					when idle => 
					-- empty the chambers	-- no strip patterns data
					chambers := (others => '0');
					-- reset index counter 
					index := 0;

					-- identify the card type
					-- local card 
					if mux_data_i(7 downto 6) = "11" then
					format	:= mux_data_i;	
					state <= trg;
					-- regional card 
					elsif mux_data_i(7 downto 6) = "10" then 
					format	:= mux_data_i;	
					state <= trg;
					else 
					state <= idle;   
					end if;
					--======--
					--  TRG  --
					--======--	
					-- state "trg"
					when trg => 
					-- sox and eox cant be together  !!!warning 
					if mux_data_i(7 downto 6) = "11" then 
					state <= idle; 
					else
					trigger := mux_data_i;	-- trigger types
					state <= ibc_1; 
					end if;
					--=======--
					-- IBC_1 --
					--=======--	
					-- state "ibc_1"
					when ibc_1 => 
					ibc(15 downto 8) := mux_data_i;	-- internal bunch counter(1)
					-- last 4 significant bits of the ibc are always 0 !!! warning
					if mux_data_i(7 downto 4) /= x"0" then 
					 state <= idle;
					else 
					 state <= ibc_2;
					end if;
					--=======--
					-- IBC_2 --
					--=======--	
					-- state "ibc_2"
					when ibc_2 =>
					ibc(7 downto 0) := mux_data_i;		-- internal bunch counter(2)
					state <= dec;	
					--=====--
					-- DEC --
					--=====--
					-- state "dec"
					when dec =>
					position := mux_data_i(7 downto 4);	-- position of local in crate 
					tracklet := mux_data_i(3 downto 0);	-- patterns tracklet 
					-- regional event 
					if format(7 downto 6) = "10" then 
	                 s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
					 s_frame_val <= '1'; 
					 state <= idle;
					-- local event 
					elsif format(7 downto 6) = "11" and tracklet = x"0" then 
	                 s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
					 s_frame_val <= '1'; 
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
						 chambers(127 - 8*index downto 120 - 8*index) := mux_data_i;	
						 index := index + 1;												 
						end if;

						case tracklet is 
						when x"1"|x"2"|x"4"|x"8" => 
							-- 1 chamber
							if index = 4 then 
			                  s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
							  s_frame_val <= '1'; 
							  state <= idle;
							end if;
						when x"3"|x"5"|x"6"|x"9"|x"A"|x"C" => 
							-- 2 chambers 
							if index = 8 then 
			                 s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
							 s_frame_val <= '1'; 
							 state <= idle;
							end if;
						when x"7"|x"B"|x"D"|x"E" => 
							-- 3 chambers
							if index = 12 then 
			                 s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
							 s_frame_val <= '1'; 
							 state <= idle;
							end if;
						when x"F" => 
							-- 4 chambers 
							if index = 16 then 
			                 s_frame_data <= format & trigger & ibc & position & tracklet & chambers;
							 s_frame_val <= '1'; 
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
	end process p_encoder;
	
	-- output frame 
	frame_val_o <= s_frame_val;
	frame_data_o <= s_frame_data;
	
end rtl;
--=============================================================================
-- architecture end
--=============================================================================