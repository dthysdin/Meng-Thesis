-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_packetizer_sim.vhd
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
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for write_packetizer_sim
--=============================================================================
entity write_packetizer_sim is
	generic (
   g_FILE_NAME : string(41 downto 1) := "file_out/link_x0/sim_packet_sans_data.txt"
    );
	port (
	---------------------------------------------------------------------------
	clk_240			: in std_logic;
	activate_sim	: in std_logic;
	activate_gbt	: in std_logic;
	activate_ttc	: in std_logic;
	gbt_packet_done: in std_logic;	
	gbt_packet		: in t_mid_datapath 
	---------------------------------------------------------------------------
	    );
end entity write_packetizer_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_packetizer_sim is

begin 
	p_pckwr : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
	begin
		wait until rising_edge(clk_240);
		-- simulation active 
		-- gbt link up 
		-- ttc link up
		if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
			if gbt_packet.valid = '1'  then
				hwrite(my_line, gbt_packet.data);
				-- sop
				if gbt_packet.sop = '1'  then
				write(my_line, string'(" SOP"));
				else 
				write(my_line, string'("    "));
				end if;
				-- eop
				if gbt_packet.eop = '1'  then
				write(my_line, string'(" EOP"));
				else 
				write(my_line, string'("     "));
				end if;
				-- done
				if gbt_packet_done = '1'  then
				write(my_line, string'(" DONE"));
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================