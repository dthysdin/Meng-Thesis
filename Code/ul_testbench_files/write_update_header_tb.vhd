-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_update_header_sim.vhd
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
--Entity declaration for write_update_header_sim
--=============================================================================
entity write_update_header_sim is
	generic (
   g_FILE_NAME : string(41 downto 1) := "file_out/link_xx/sim_update_header_x0.txt"
    );
	port (
	---------------------------------------------------------------------------
	clk_240			: in std_logic;
	activate_sim	: in std_logic;
	activate_gbt	: in std_logic;
	updated_info 	: in t_mid_ttcinfo;
	req_collect 	: in std_logic;
	ack_collect		: out std_logic
	---------------------------------------------------------------------------
	    );
end entity write_update_header_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_update_header_sim is

begin 
	p_uhwr : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable done : std_logic := '0';
	begin
		wait until rising_edge(clk_240);
		-- simulation active 
		-- gbt link up 
		if activate_sim = '1' and activate_gbt = '1' then
			-- collection requested 
			if req_collect /= done then
				write(my_line, string'("ORBIT = "));
				hwrite(my_line, updated_info.orbit);
				write(my_line, string'(" TTYPE = "));
				hwrite(my_line, updated_info.trg);
				write(my_line, string'(" BCID = "));
				hwrite(my_line, updated_info.bcid);
				writeline(my_file, my_line);
				-- acknoledge collection 
				ack_collect <= '1';
				done := '1';
			else 
			done := '0';
			end if;
		end if;
		ack_collect <= done;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================