-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: regional_control_tb.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: --
-- This module test the functionality of the regional control module
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for regional_control_tb
--=============================================================================
entity regional_control_tb is
end entity regional_control_tb;
--=============================================================================
-- architecture declaration
--============================================================================
architecture sim of regional_control_tb is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	constant g_WRITE_OUTPUT_TO_FILE		: integer:= 1;	-- Range 0~1 -- 1 = YES -- 0 = NO
	constant g_WRITE_COMPARE_TO_FILE	: integer:= 1;	-- Range 0~1 -- 1 = YES -- 0 = NO
	constant g_REGIONAL_ID				: integer:= 1;	-- Range 0~1 -- 1 = REGIONAL HIGH  -- 0 = REGIONAL LOW
	constant g_NUM_GBT_USED				: integer:= 1;	-- Range 1~16 -- GBT LINKS USED 
	constant g_FILE_IN					: string(27 downto 1) := "file_out/reg_decoder_01.txt";			-- Results from previous module
	constant g_FILE_OUT 				: string(34 downto 1) := "file_out/reg_control_status_01.txt";	-- Results analysis status 
	constant g_FILE_DATA_OUT			: string(27 downto 1) := "file_out/reg_control_01.txt";			-- Resutls used as input for the next module 
	
	-- ========================================================
	-- signal declarations of the design under test
	-- ========================================================
	-- clock signals 
	signal clk_240	: std_logic := '0';
	signal clk_40	: std_logic := '0';
	-- reset 
	signal reset_p : std_logic;
	-- activate 
	signal activate_sim : std_logic := '0';
	signal activate_gbt : std_logic := '0';
	signal activate_ttc : std_logic := '0';
	-- gbt data 
	signal gbt_data : std_logic_vector(g_NUM_GBT_USED*80-1 downto 0);
	signal gbt_valid: std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_sel: 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_ready:	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal gbt_en : 	std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	-- ttc 
	signal ttc_ready	: std_logic; 
	signal ttc_valid	: std_logic; 
	signal ttc_data	: std_logic_vector(199 downto 0);
	signal trg_rx		: t_mid_trginfo; -- (SOC,EOC,PHY,SOT,EOT)
	signal bcid_rx		: std_logic_vector(15 downto 0); 
	-- regional decoder 
	signal s_elink_frame_val : std_logic;
	signal s_elink_frame_data : std_logic_vector(39 downto 0);
	-- reg control
	signal reg_resume 	: std_logic;
	signal reg_pause		: std_logic;
	signal reg_full		: std_logic;
	signal reg_active		: std_logic;
	signal reg_val_o		: std_logic;
	signal reg_data_o		: std_logic_vector(39 downto 0);
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
	--============================================================
	-- clock generator 
	--============================================================
	clk: entity work.clk_gen
	generic map (g_NUM_GBT_USED => 1)
	port map (
	activate_ttc	=> activate_ttc,				--: in std_logic; -- ttc
	activate_sim	=> activate_sim,				--: in std_logic; -- sim  
	activate_gbt	=> activate_gbt,				--: in std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	--
	reset_p			=> reset_p,						--: in std_logic;
	--
	clk_40 			=>	clk_40,						--: out  std_logic;
	clk_100 			=>	open,							--: out  std_logic;
	clk_240 			=>	clk_240,						--: out  std_logic;
   --	
	gbt_valid		=>	gbt_valid,					--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel			=>	gbt_sel,						--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready		=> gbt_ready,					--: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	--
	ttc_valid		=> ttc_valid,					--: out std_logic;
	ttc_ready		=> ttc_ready					--: out std_logic	
	    );
	--============================================================
	-- read GBT data 
	--============================================================	 
	read_gbt: entity work.read_gbt_sim
	generic map (g_FILE_NAME => "file_in/sim_gbt_dataX0.txt")
	port map (
	activate_sim	=> activate_sim, 		--: in std_logic;
	activate_gbt	=> activate_gbt, 		--: in std_logic;
	clk_40			=> clk_40,				--: in std_logic; -- 40 MHz 
	data			=> gbt_data				--: out std_logic_vector(79 downto 0)
	    ); 
	-- gbt enable 
	gbt_en(0) <= gbt_ready(0) and gbt_sel(0);
	--============================================================
	-- read TTC data 
	--============================================================
	read_ttc: entity work.read_ttc_tb
	generic map (g_FILE_NAME  => "file_in/sim_ttc_pon.txt")
	port map (
	activate_sim 	=> activate_sim,			--: in std_logic;
	activate_ttc  	=> activate_ttc,			--: in std_logic;
	clk_40     		=> clk_40,					--: in std_logic; -- 40 MHz 
	data       		=> ttc_data					--: out std_logic_vector(199 downto 0)
	);
	--============================================================
	-- regional decoder 
	--============================================================
	regional_dec: entity work.regional_decoder
	port map (
	clk_240			=> clk_240, 						--: in std_logic;								     
	reset_p			=> reset_p, 						--: in std_logic;
	--
	elink_en_i		=> gbt_en(0),						--: in std_logic;								
	elink_valid_i	=> gbt_valid(0),					--: in std_logic;								
	elink_data_i	=> gbt_data(39+40*g_REGIONAL_ID downto 32+40*g_REGIONAL_ID),--: in std_logic_vector(7 downto 0);
	--
	elink_frame_val_o	=> s_elink_frame_val,	--: out std_logic;							
	elink_frame_data_o	=> s_elink_frame_data	--: out std_logic_vector(39 downto 0)	 
	 );  
	--============================================================
	-- DUT 
	--============================================================
	DUT: entity work.regional_control
	generic map ( g_REGIONAL_ID => g_REGIONAL_ID)
	port map (
	clk_240			=> clk_240,					--: in std_logic;								  
	reset_p			=> reset_p,					--: in std_logic;								
	reg_data_i		=>	s_elink_frame_data,	--: in std_logic_vector(39 downto 0);	
	reg_val_i 		=>	s_elink_frame_val,	--: in std_logic;								
	reg_full_i		=>	'0',						--: in std_logic;								
	reg_resume_i	=>	reg_resume,				--: in std_logic;								 
	ttc_bcid_i 		=>	bcid_rx,					--: in std_logic_vector(15 downto 0);		
	ttc_trigger_i	=> trg_rx,					--: in std_logic_vector(2 downto 0);		
	ttc_valid_i		=> ttc_valid,				--: in std_logic;								 
	reg_pause_o		=>	reg_pause,				--: out std_logic;							 
	reg_ID_o 		=> open,						--: out std_logic_vector(3 downto 0);		
	reg_full_o		=>	reg_full,				--: out std_logic;							 
	reg_active_o 	=>	reg_active,				--: out std_logic;							
	reg_val_o		=>	reg_val_o,				--: out std_logic;							 
	reg_data_o		=>	reg_data_o				--: out std_logic_vector(39 downto 0)	 
	 ); 
	--============================================================
	-- register for  TTC data 
	--============================================================
	p_ttc: process
	begin 
		wait until rising_edge(clk_240);
		if ttc_valid = '1' and ttc_ready = '1' and ttc_data(119) = '1' then  
			-- (SOC,EOC,PHY,SOT,EOT)
			trg_rx.soc <= ttc_data(9); -- soc
			trg_rx.eoc <= ttc_data(10);-- eoc
			trg_rx.phy <= ttc_data(4); -- phy
			trg_rx.sot <= ttc_data(7); -- sot
			trg_rx.eot <= ttc_data(8); -- eot
			-- BC 
			bcid_rx <= x"0" & ttc_data(43 downto 32);
		end if;
	end process;
	--============================================================
	-- resume the data acquisition
	--============================================================
	p_resume: process
	begin 
		wait until rising_edge(clk_240);		
		if reg_pause = '1' then 
			reg_resume <= '1';
		else 
			reg_resume <= '0';
		end if;
	end process;
	--============================================================
	-- stimulus 
	--============================================================
	p_stimulus: process
	begin 
		-- initial 
		wait for 0 ps;
		activate_sim <= '1';
		activate_ttc <= '0';
		activate_gbt <= '0';
		reset_p <= '1';
		wait for 47000 ps;
		reset_p <= '0';
		wait until rising_edge(clk_240);
		-- activate ttc readout 
		activate_ttc <= '1';
		-- activate gtb readout
		activate_gbt <= '1';
		-- fee sox 
		wait until reg_active = '1';
		report "regional card activated - sox successfully received - OK!!! ";
		-- ttc soc 
		wait until trg_rx.soc = '1';
		report "ttc continuous mode activated - soc received - OK!!! ";
		-- fee eox 
		wait until reg_active = '0';
		report "regional card desactivated - eox successfully received - OK!!! ";
		-- ttc eoc 
		wait until trg_rx.eoc = '1';
		report "ttc continuous mode desactivated - eoc received - OK!!! ";
		wait until falling_edge(clk_40);
		-- desactivate the gbt readout 
		activate_gbt <= '0';
		activate_ttc <= '0';
		activate_sim <= '0';
		assert false
			report"end of simulation"
			severity failure;
		wait;
	end process;
	--============================================================
	-- local card status  
	--============================================================
	p_status: process 
	begin 
		wait until rising_edge(clk_240);
		assert reg_full = '0' report " regional full" severity warning;
		wait until rising_edge(clk_240);
			if reg_val_o = '1' then  
			
				-- check the start bit and card type 
				assert reg_data_o(39 downto 38) = "10" 
					report "error in start bit & card type" 
					severity Failure;
				assert reg_data_o(39 downto 32) /= x"00" 
					report "error in format" 
					severity Failure;
					
				-- check trigger sox and eox 
				assert reg_data_o(31 downto 30) /= "11"  
					report "error in trigger" 
					severity Failure;
					
				-- check bunch crossing 
				assert reg_data_o(23 downto 20) = x"0" 
					report "error in bcid" 
					severity Failure;	
			end if;
	end process;
	--============================================================
	-- regional card checker  
	--============================================================
	p_checker: process
		-- constants 
		constant my_filename_in	: string(27 downto 1) := g_FILE_IN;
		constant my_filename_out: string(34 downto 1) := g_FILE_OUT;
		-- text files 
		file my_read_file : text;
		file my_write_file : text;
		-- variables 
		variable my_content: std_logic_vector(39 downto 0) := (others => '0');
		variable my_expected_data : std_logic_vector(39 downto 0) := (others => '0');
		variable my_write_line : line;
		variable my_read_line: line; 
		variable my_read_file_status: file_open_status;
		variable my_write_file_status: file_open_status;
		variable string_reg_dec : string (19 downto 1) := "REGIONAL DECODER = ";
		variable string_reg_ctrl: string (19 downto 1) := "REGIONAL CONTROL = ";
		variable string_not_ok: string (20 downto 1) := " check status /= OK!";
		variable string_ok: string (19 downto 1) := " check status = OK!";
		variable string_space : string (3 downto 1) := "   ";
	 
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
			if reg_val_o = '1' then 
				-- READ FROM FILE    
				readline (my_read_file, my_read_line); 
				hread (my_read_line, my_content);
				
				-- DEFINE EXPECTED DATA
				my_expected_data := my_content(39 downto 8) & std_logic_vector(to_unsigned(g_REGIONAL_ID,4)) & my_content(3 downto 0);
				
				-- COMPARE INTPUT Vs OUTPUT 
				if my_expected_data = reg_data_o then 
					report	string_reg_dec & hex_to_string(my_content) & string_space & string_reg_ctrl & hex_to_string(reg_data_o) & string_ok;
				else 
					report string_reg_dec & hex_to_string(my_content) & string_space & string_reg_ctrl & hex_to_string(reg_data_o) & string_not_ok;
				end if;
				
				-- WRITE COMPARE RESULTS TO FILE   
				if g_WRITE_COMPARE_TO_FILE /= 0 then 
					write(my_write_line, string_reg_dec);
					hwrite(my_write_line, my_content);
					write(my_write_line, string_space);
					write(my_write_line, string_reg_ctrl);
					hwrite(my_write_line, reg_data_o);
						if my_expected_data = reg_data_o then 
							write(my_write_line,string_ok);
						else 
							write(my_write_line, string_not_ok);
						end if;
					writeline(my_write_file, my_write_line);
				end if;

				-- ASSERT FAILURE
				assert my_expected_data = reg_data_o
					report "mismatched"
					severity failure; -- end simulation 
			end if;
		end loop;
		wait until rising_edge(clk_40); 
		-- CLOSE FILES --
		file_close (my_read_file);
		file_close (my_write_file);
	 
		-- REPORT --
		report my_filename_in & " closed with no errors. ";
		report my_filename_out & " closed with no errors. ";
		wait;
	end process;
	--============================================================
	-- write output to file  
	--============================================================
	WR_GEN: if g_WRITE_OUTPUT_TO_FILE = 1 generate 
		
		pw: entity work.write_reg_decoder_sim
		generic map (g_FILE_NAME => g_FILE_DATA_OUT)
		port map (
		clk_240			=> clk_240, 		--: in std_logic;
		activate_sim	=> activate_sim,	--: in std_logic;
		activate_gbt	=> activate_gbt,	--: in std_logic;
		elink_frame_val => reg_val_o,		--: in std_logic; 
		elink_frame_data=> reg_data_o		--: in std_logic_vector(39 downto 0)
	    );
	end generate;
	
end architecture;
--=============================================================================
-- architecture end
--=============================================================================