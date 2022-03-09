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
--Entity declaration for read_gbt_sim
--=============================================================================
entity read_ttc_tb is
	generic (
   g_FILE_NAME    : string(30 downto 1) := "ul_input_files/sim_ttc_pon.txt" -- continous or trigggered
    );
	port (
	---------------------------------------------------------------------------
	activate_sim : in std_logic;
	activate_ttc: in std_logic;
	--
	clk_40 : in std_logic; -- 40 MHz 
	data: out std_logic_vector(199 downto 0)
	---------------------------------------------------------------------------
	    );
end entity read_ttc_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of read_ttc_tb is
begin 
	p_read_ttc: process
		constant my_filename: string(30 downto 1) := g_FILE_NAME; 
      file my_file : text;
      variable my_content: std_logic_vector(199 downto 0) := (others => '0');
      variable my_line: line; 
      variable my_file_status: file_open_status;
    begin
		-- OPEN -- 
		file_open (my_file_status, my_file, my_filename, READ_MODE);
		-- REPORT --  
      report my_filename & LF & HT & "file_open_status = " & file_open_status'image(my_file_status);
      assert my_file_status = OPEN_OK 
			report "file_open_status /= file_ok"
			severity FAILURE;    -- end simulation
		-- ENABLE --
		if activate_sim /= '1' then wait until activate_sim = '1'; end if;
		if activate_ttc /= '1' then wait until activate_ttc = '1'; end if;
		-- READ --
			while not ENDFILE (my_file) loop
				wait until rising_edge(clk_40); 
            readline (my_file, my_line); 
            hread (my_line, my_content);
            data <= my_content;
        end loop;
		wait until rising_edge(clk_40); 
		-- CLOSE --
      file_close (my_file);
		-- REPORT --
      report my_filename & " closed.";
		-- INITIAL --
		data <= (others => '0');
      wait;
    end process;
end architecture;
--=============================================================================
-- architecture end
--=============================================================================