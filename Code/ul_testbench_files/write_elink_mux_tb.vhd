------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: write_elink_mux_tb.vhd
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
--Entity declaration for write_elink_mux_tb
--=============================================================================
entity write_elink_mux_tb is
	generic (
   g_FILE_NAME : string(25 downto 1) := "file_out/elink_mux_xx.txt"
    );
	port (
	---------------------------------------------------------------------------
	clk_240		: in std_logic;
	activate_sim: in std_logic;
	activate_gbt: in std_logic;
	activate_ttc: in std_logic;
	frame_val	: in std_logic;
	frame_stop: in std_logic;
	frame_data: in std_logic_vector(167 downto 0)
	---------------------------------------------------------------------------
	    );
end entity write_elink_mux_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of write_elink_mux_tb is
type t_int_vector is array (natural range <>) of integer; 
begin 
	p_wr_elink_mux : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable string_elink_mux: string (12 downto 1)	:= "ELINK MUX = ";
		variable string_gap : string(4 downto 1) := "    ";
		variable string_dash : string(54 downto 1) 	:= "======================================================";
		variable string_new_orbit: string(54 downto 1) := "----------------------LAST BYTE-----------------------";

		variable locID : integer := 0;
		variable loc_cnt : t_int_vector(3 downto 0) := (others => 0);
        
		variable regID : integer := 0;
		variable reg_cnt: integer := 0;

	begin
		wait until rising_edge(clk_240);
		if activate_sim = '1' and activate_gbt = '1' and activate_ttc = '1'then 
		 -- simulation active 
		 -- gbt link up 
		 if frame_val = '1' then
		  write(my_line, string_elink_mux);
		  hwrite(my_line, frame_data);

		  if frame_data(167 downto 166) = "11" and frame_data(152) = '1' then
		   -- local 
		   locID := to_integer(unsigned(frame_data(135 downto 132)));

		    for i in 0 to 3 loop 
			 if i = locID then 
			  loc_cnt(i) := loc_cnt(i)+1;
			  write(my_line, string_gap);
		      write(my_line, string'("local ID(" & integer'image(locID) & ") HB = " & integer'image(loc_cnt(i))));
			 end if;
			end loop;
          
		  elsif frame_data(167 downto 166) = "10" and frame_data(152) = '1' then 
           -- regional 
		   regID := to_integer(unsigned(frame_data(135 downto 132)));
		   reg_cnt := reg_cnt+1;

		   write(my_line, string_gap);
		   write(my_line, string'("regional ID(" & integer'image(regID) & ") HB = " & integer'image(reg_cnt)));
		  end if;
		  write(my_line, string_gap);
		  write(my_line, now);
		  writeline(my_file, my_line);
		end if;
		 -- stop
		 if frame_stop = '1' then
		  write(my_line, string_dash);
		  writeline(my_file, my_line);
		  write(my_line, string_new_orbit);
		  writeline(my_file, my_line);
		  write(my_line, string_dash);
		  writeline(my_file, my_line);
		 end if;
		end if;
	end process p_wr_elink_mux;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================