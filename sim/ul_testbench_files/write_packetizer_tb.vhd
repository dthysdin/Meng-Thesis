-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_packetizer.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: --
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
--=============================================================================
--Entity declaration for write_packetizer_tb
--=============================================================================
entity write_packetizer_tb is
	generic (
   g_FILE_NAME : string(17 downto 1) := "packetizer_x0.txt"
    );
	port (
	---------------------------------------------------------------------------
	clk_240			: in std_logic;
	activate_sim	: in std_logic;
	activate_gbt	: in std_logic;
	elink_trigger	: in std_logic_vector(2 downto 0);
	packet_crateID	: in  std_logic_vector(3 downto 0);	
	packet_ready	: in std_logic;				 
	packet_val		: in std_logic;						
	packet_size		: in std_logic_vector(15 downto 0);	 
	packet_data		: in std_logic_vector(255 downto 0)
	---------------------------------------------------------------------------
	    );
end entity write_packetizer_tb ;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_packetizer_tb is

begin 
	p_emuxwr : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable skip : std_logic := '0';
		variable v_size : integer := 0; 
		variable v_total_size : integer := 0;
	
	begin
		wait until rising_edge(clk_240);
		-- simulation active 
		-- gbt link up 
		if activate_sim = '1' and activate_gbt = '1' then
			-- valid data 
			if packet_val = '1' then
				hwrite(my_line, packet_data);
				writeline(my_file, my_line);
			end if;
			-- data size 
			if packet_ready = '1' then 
				v_size := to_integer(unsigned(packet_size));
				v_total_size := v_total_size + v_size;
				-- sox 
				if elink_trigger(2) = '1'  then
					if skip = '1' then 
						write(my_line, string'(" CLOSE(HB)(EOX) "));
						write(my_line, string'("PACKET SIZE = "));
						write(my_line, v_size);
						write(my_line, string'(" --- NEXT NEW RUN(SOX) "));
						skip := '0';
					else
						write(my_line, string'(" (SOX) "));
						write(my_line, string'("PACKET SIZE = "));
						write(my_line, v_size);
						write(my_line, string'(" --- NEXT OPEN(HB)(SOX) "));
					end if;
				elsif elink_trigger(1) = '1' then 
					write(my_line, string'(" CLOSE(HB)(EOX) "));
					write(my_line, string'("PACKET SIZE = "));
					write(my_line, v_size);
					write(my_line, string'(" --- NEXT OPEN(HB)(SOX) "));
					skip := '1';
				else 
					write(my_line, string'(" CLOSE(HB) (EOX) "));
					write(my_line, string'("PACKET SIZE = "));
					write(my_line, v_size);
					write(my_line, string'(" --- NEXT OPEN (HB) "));
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================