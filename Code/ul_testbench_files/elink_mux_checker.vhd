-------------------------------------------------------------------------------
-- File		: write_zs_datapath_sim.vhd
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
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration forelink_mux_checker_tb 
--=============================================================================
entity elink_mux_checker_tb is
	generic (
	g_REGIONAL_ID	: integer := 0;
	g_SELECT		: integer := 0;
	g_LOCAL_ID		: integer := 0;
	g_FILE_IN		: string(27 downto 1);  
	g_FILE_OUT		: string(32 downto 1)  
    );
	port (
	---------------------------------------------------------------------------
	clk_240 		: in std_logic;
	reset_p 		: in std_logic;
	activate_sim	: in std_logic;
	activate_ttc	: in std_logic;
	activate_gbt	: in std_logic;
	--
	elink_frame_val	: in std_logic;
	elink_frame_data: in std_logic_vector(167 downto 0)
	---------------------------------------------------------------------------
	    );
end entity elink_mux_checker_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of elink_mux_checker_tb is
	-- ========================================================
	-- function declarations 
	-- ========================================================
	-- convert binary to string 
	function bin_to_string (data: std_logic_vector) return string is
    variable bin_string : string (1 to data'length) := (others => NUL);
    variable counter : integer := 1;
	begin
        for i in data'range loop
			bin_string(counter) := std_logic'image(data((i)))(2);
			counter := counter + 1;
        end loop;
    return bin_string;
	end function;
	
	-- convert hexadecimal to string 
	function hex_to_string(data : std_logic_vector) return string is
	variable hex : string(1 to data'length/4) := (others => '0');
	variable selct : std_logic_vector(3 downto 0) := x"0";
	begin
		assert data'length mod 4 = 0
			report "hex_to_string only works if the data input is multiple by 4"
			severity failure;
			
		for i in hex'range loop 
			selct := data(3+4*(i-1) downto 0+4*(i-1));
			case selct  is 
			when x"0" => hex(hex'length+1-i) := '0'; 
			when x"1" => hex(hex'length+1-i) := '1';
			when x"2" => hex(hex'length+1-i) := '2';
			when x"3" => hex(hex'length+1-i) := '3'; 
			when x"4" => hex(hex'length+1-i) := '4';
			when x"5" => hex(hex'length+1-i) := '5';
			when x"6" => hex(hex'length+1-i) := '6'; 
			when x"7" => hex(hex'length+1-i) := '7';
			when x"8" => hex(hex'length+1-i) := '8';
			when x"9" => hex(hex'length+1-i) := '9'; 
			when x"A" => hex(hex'length+1-i) := 'A';
			when x"B" => hex(hex'length+1-i) := 'B';
			when x"C" => hex(hex'length+1-i) := 'C'; 
			when x"D" => hex(hex'length+1-i) := 'D';
			when x"E" => hex(hex'length+1-i) := 'E';
			when x"F" => hex(hex'length+1-i) := 'F';
			when others => hex(hex'length+1-i):= '-';
			end case;
		end loop;
		return hex;
	end function;
begin 
	checker : process 
		-- constants 
		constant my_filename_in	: string(27 downto 1) := g_FILE_IN;
		constant my_filename_out: string(32 downto 1) := g_FILE_OUT;
		-- text files 
		file my_read_file : text;
		file my_write_file: text;
		-- file status 
		variable my_read_line: line; 
		variable my_write_line: line; 
		variable my_read_file_status: file_open_status;
		variable my_write_file_status: file_open_status;
		-- content 
		variable my_loc_content: std_logic_vector(167 downto 0) := (others => '0');
		variable my_reg_content : std_logic_vector(39 downto 0) := (others => '0');
		variable my_regional_data : std_logic_vector(39 downto 0) := (others => '0');
		variable my_local_data : std_logic_vector(167 downto 0) := (others => '0');
		-- strings 
		variable string_reg_dec : string (16 downto 1) := "REGIONAL DECODER";
		variable string_loc_dec : string (13 downto 1) := "LOCAL DECODER";
		variable string_elink_mux: string (12 downto 1):= "ELINK MUX = ";
		variable string_not_ok: string(20 downto 1) := " check status /= OK!";
		variable string_error: string(9 downto 1 ) := " error!!!";
		variable string_ok: string (19 downto 1) := " check status = OK!";
		variable string_space : string (3 downto 1) := "   ";
		
		variable string_dash : string (134 downto 1) := "======================================================================================================================================";
		variable string_new_orbit: string(134 downto 1) := "-------------------------------------------------------NEW ORBIT----------------------------------------------------------------------";
	begin 
		-- OPEN  -- 
		file_open (my_read_file_status, my_read_file, my_filename_in, READ_MODE);
		file_open (my_write_file_status, my_write_file, my_filename_out, WRITE_MODE);
		
		-- REPORT FILE STATUS --  
		report my_filename_in & LF & HT & "file_open_status = " & file_open_status'image(my_read_file_status);
		assert my_read_file_status = OPEN_OK 
			report "file_open_status /= read_file_ok"
			severity FAILURE;    -- end simulation in case of error
			
		report my_filename_out & LF & HT & "file_open_status = " & file_open_status'image(my_write_file_status);
		assert my_write_file_status = OPEN_OK 
			report "file_open_status /= write_file_ok"
			severity FAILURE;    -- end simulation in case of error
				
		-- ENABLE --
		if activate_sim /= '1' then wait until activate_sim = '1'; end if; -- simulation activated 
		if activate_ttc /= '1' then wait until activate_ttc = '1'; end if; -- ttc pon data ready 
		if activate_gbt /= '1' then wait until activate_ttc = '1'; end if; -- gtb data ready
		
		-- READ/WRITE --
		while not ENDFILE (my_read_file) loop
			wait until rising_edge(clk_240);
			if elink_frame_val = '1' then 
			
				-- READ FROM SELECTED FILE 
				if g_SELECT /= 1 then
					-- LOCAL FRAME 
					if elink_frame_data(167 downto 166) = "11" and elink_frame_data(135 downto 132) = std_logic_vector(to_unsigned(g_LOCAL_ID,4)) then
					
						-- READ FROM FILE 
						readline (my_read_file, my_read_line); 
						hread (my_read_line, my_loc_content);
						
						-- DEFINE EXPECTED DATA
						my_local_data := my_loc_content;
						
						-- COMPARE INTPUT Vs OUTPUT
						if my_local_data = elink_frame_data then 
							report string_loc_dec & "(" & integer'image(to_integer(unsigned(elink_frame_data(135 downto 132))))& ") = " & hex_to_string(my_loc_content) & string_space & string_elink_mux & hex_to_string(elink_frame_data) & string_ok;
						else 
							report string_loc_dec & "(" & integer'image(to_integer(unsigned(elink_frame_data(135 downto 132))))& ") = " & hex_to_string(my_loc_content) & string_space & string_elink_mux & hex_to_string(elink_frame_data) & string_not_ok & string_error;
						end if;
						
						-- WRITE TO FILE
						-- sox 
						if elink_frame_data(152) = '1' then 
							write(my_write_line, string_dash);
							writeline(my_write_file, my_write_line);
							write(my_write_line, string_new_orbit);
							writeline(my_write_file, my_write_line);
							write(my_write_line, string_dash);
							writeline(my_write_file, my_write_line);
						end if;
						
						write(my_write_line, string_loc_dec);
						write(my_write_line, string'(" = "));
						hwrite(my_write_line, my_loc_content);
						write(my_write_line, string_space);
						write(my_write_line, string_elink_mux);
						hwrite(my_write_line, elink_frame_data);
							if my_local_data = elink_frame_data then 
								write(my_write_line,string_ok);
							else 
								write(my_write_line,string_not_ok);
								write(my_write_line, string_error);
							end if;
						writeline(my_write_file, my_write_line);
						
						assert my_local_data = elink_frame_data
							report "mismatched"
								severity failure; -- end simulation
								
						-- WRITE STOP 
						
					end if;
				
				else 
					-- REGIONAL FRAME 
					if elink_frame_data(167 downto 166) = "10" then
					
						-- READ FROM FILE 
						readline (my_read_file, my_read_line); 
						hread (my_read_line, my_reg_content);
						
						-- DEFINE EXPECTED DATA
						my_regional_data := my_reg_content(39 downto 8) & std_logic_vector(to_unsigned(g_REGIONAL_ID,4)) & my_reg_content(3 downto 0);
						
						-- COMPARE INTPUT Vs OUTPUT 
						if my_regional_data = elink_frame_data(167 downto 128) then 
							report string_reg_dec & "(" & integer'image(g_REGIONAL_ID)& ") = " & hex_to_string(my_reg_content) & string_space & string_elink_mux & hex_to_string(my_regional_data) & string_ok;
						else 
							report string_reg_dec & "(" & integer'image(g_REGIONAL_ID)& ") = " & hex_to_string(my_reg_content) & string_space & string_elink_mux & hex_to_string(my_regional_data) & string_not_ok & string_error;
						end if;
						
						-- WRITE TO FILE 
						-- sox 
						if elink_frame_data(152) = '1' then 
							write(my_write_line, string_dash);
							writeline(my_write_file, my_write_line);
							write(my_write_line, string_new_orbit);
							writeline(my_write_file, my_write_line);
							write(my_write_line, string_dash);
							writeline(my_write_file, my_write_line);
						end if;
						
						write(my_write_line, string_reg_dec);
						write(my_write_line, string'(" = "));
						hwrite(my_write_line, my_reg_content(39 downto 0));
						write(my_write_line, string_space);
						write(my_write_line, string_elink_mux);
						hwrite(my_write_line, elink_frame_data(167 downto 128));
							if my_regional_data = elink_frame_data(167 downto 128) then 
								write(my_write_line,string_ok);
							else 
								write(my_write_line,string_not_ok);
								write(my_write_line, string_error);
							end if;
						writeline(my_write_file, my_write_line);
						
						assert my_regional_data = elink_frame_data(167 downto 128)
							report "mismatched"
								severity note; -- end simulation
					end if;
				end if;
				
			end if;
		end loop;
		wait until rising_edge(clk_240); 
		file_close (my_read_file);
		file_close (my_write_file);
	 
		-- REPORT --
		report my_filename_in & " closed with no errors. ";
		report my_filename_out & " closed with no errors. ";
		wait;
	
    end process;

end architecture rtl;
--=============================================================================
-- architecture end
--=============================================================================