-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_reg_decoder_tb.vhd
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
--Entity declaration for write_reg_decoder_tb
--=============================================================================
entity write_reg_decoder_sim is
	generic (
   g_FILE_NAME : string(27 downto 1) := "file_out/reg_decoder_00.txt" );
	port (
	---------------------------------------------------------------------------
	clk_240		: in std_logic;
	activate_sim: in std_logic;
	activate_gbt: in std_logic;
	elink_frame_val: in std_logic; 
	elink_frame_data: in std_logic_vector(39 downto 0)
	---------------------------------------------------------------------------
	    );
end entity write_reg_decoder_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_reg_decoder_sim is

begin 
	p_reg_decoder_sim : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable string_sox     : string (13 downto 1) :=" START OF RUN";
		variable string_eox     : string (11 downto 1) :=" END OF RUN";
		variable string_hb     	: string (10 downto 1) :=" HEARTBEAT";
		variable string_no     	: string (11 downto 1) :="    TRG No.";
		variable hb_cnt 			: natural := 0;
		
	begin
		wait until rising_edge(clk_240);
		if activate_sim = '1' and activate_gbt = '1' then 
		-- simulation active 
		-- gbt link up 
			if elink_frame_val = '1' then
				hwrite(my_line, elink_frame_data);
				-- sox 
				if elink_frame_data(31) = '1' then
				hb_cnt := hb_cnt + 1;
				write(my_line,string_sox);
				write(my_line,string_no);
				write(my_line,hb_cnt);
				-- eox 
				elsif elink_frame_data(30) = '1' then
				hb_cnt := hb_cnt + 1;
				write(my_line,string_eox);
				write(my_line,string_no);
				write(my_line,hb_cnt);
				else 
					-- heartbeat --
					if elink_frame_data(24) = '1' then
					hb_cnt := hb_cnt + 1;
					write(my_line, string_hb);
					write(my_line,string_no);
					write(my_line,hb_cnt);
					end if;
				end if;
				writeline(my_file, my_line);
			end if;
		end if;
	end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================