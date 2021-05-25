-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_ul_datapsth_sim.vhd
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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
--=============================================================================
--Entity declaration for write_ul_datapath_sim
--=============================================================================
entity write_ul_datapath_sim is
	generic (
   g_FILE_NAME    : string(25 downto 1) := "file_out/ul_datapathx.txt"
    );
	port (
	---------------------------------------------------------------------------
	activate_sim : in std_logic;
	activate_gbt : in std_logic;
	activate_ttc : in std_logic;
	--
	FCLK : in std_logic;
	FVAL : in std_logic;
	FSOP : in std_logic;
	FEOP : in std_logic; 
	FD	  : in std_logic_vector(255 downto 0)
	---------------------------------------------------------------------------
	    );
end entity write_ul_datapath_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_ul_datapath_sim is

begin 
	p_ul_datapath_sim : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable string_sop     : string ( 4 downto 1) :=" SOP";
		variable string_eop     : string ( 4 downto 1) :=" EOP";
		variable string_nop     : string ( 4 downto 1) :="    ";
	begin
		wait until rising_edge(FCLK);
		-- simulation active 
		-- gbt link up 
		-- ttc link up
		if activate_sim = '1' and activate_gbt = '1'  and activate_ttc = '1' then
			if (FVAL='1') then
				hwrite(my_line,FD);
				-- SOP -- 
				if (FSOP='1') then
					write(my_line,string_sop);
				else
					write(my_line,string_nop);
				end if;
				-- EOP --
				if (FEOP='1') then
					write(my_line, string_eop);
				else
					write(my_line,string_nop);
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================