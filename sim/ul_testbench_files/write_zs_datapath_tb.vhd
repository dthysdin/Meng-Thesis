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
-- Altera library 
library altera_mf;
use altera_mf.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for write_zs_datapath_sim
--=============================================================================
entity write_zs_datapath_sim is
	generic (
   g_FILE_NAME    : string(17 downto 1) := "zs_datapathX.txt"
    );
	port (
	---------------------------------------------------------------------------
	reset_p : in std_logic;
	active_sim : in std_logic;
	--
	clk : in std_logic;
	datapath : in t_mid_datapath
	---------------------------------------------------------------------------
	    );
end entity write_zs_datapath_sim;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of write_zs_datapath_sim is

begin 
	p_zs_datapath_sim : process
		file my_file : text open write_mode is g_FILE_NAME;
		variable my_line  : line;
		variable packet_size256 : natural;
	
	begin
		wait until rising_edge(clk_240);
			-- VALID -- 
			if s_datapath.valid ='1' then
				-- SOP --
				if s_datapath.sop ='1' then
					write(my_line,string'("## SOP ##"));
					writeline(my_file, my_line);
					packet_size256:= 0;
				end if;
			
				-- RDH1 & RDH0 --
				if packet_size256=0 then
					-- CRUid
					write(my_line,string'("CRUid=0x"));			
					hwrite(my_line,datapath.data(123 downto 112));
					-- PacketCounter 
					write(my_line,string'(" PKTCnt=0x"));			
					hwrite(my_line,datapath.data(111 downto 104));
					-- LinkID 
					write(my_line,string'(" Linkid=0x"));				
					hwrite(my_line,datapath.data(103 downto 96));
					-- MemorySize
					write(my_line,string'(" MEMSIZE=0x"));	
					hwrite(my_line,datapath.data(95 downto 80));
					-- OffsetNewPacket
					write(my_line,string'(" OFFPKT=0x"));
					hwrite(my_line,datapath.data(79 downto 64));
					-- SystemID
					write(my_line,string'(" SYSID=0x"));
					hwrite(my_line,datapath.data(47 downto 40));
					-- Priority bit
					write(my_line,string'(" PRIO=0x"));
					hwrite(my_line,datapath.data(39 downto 32));
					-- FEEid
					write(my_line,string'(" FEEID=0x"));
					hwrite(my_line,datapath.data(31 downto 16));
					-- HeaderSize
					write(my_line,string'(" HDRSIZE=0x"));
					hwrite(my_line,datapath.data(15 downto 8));
					-- HeaderVersion
					write(my_line,string'(" HDRVER=0x"));
					hwrite(my_line,datapath.data(7 downto 0));
					-- BunchCrossing
					write(my_line,string'(" BC=0x"));
					hwrite(my_line,datapath.data(128+11 downto 128+0));
					-- Orbit 
					write(my_line,string'(" Orbit=0x"));
					hwrite(my_line,datapath.data(128+63 downto 128+32));
					writeline(my_file, my_line);
				end if;
			
				-- RDH3 & RDH2 --
				if packet_size256=1 then
					-- TriggerTypes 
					write(my_line,string'("TRGBCID=0x"));
					hwrite(my_line,datapath.data(31 downto 0));
					-- PageCounter
					write(my_line,string'(" PAGECNT=0x"));
					hwrite(my_line,s_datapath.data(47 downto 32));
					-- Stopbit --
					write(my_line,string'(" STOP=0x"));
					hwrite(my_line,s_datapath.data(55 downto 48));
					-- DetectorFiled
					write(my_line,string'(" DFIELD=0x"));
					hwrite(my_line,datapath.data(128+31 downto 128+0));
					-- ParBit
					write(my_line,string'(" PAR=0x"));
					hwrite(my_line,datapath.data(128+47 downto 128+32));
					writeline(my_file, my_line);
				end if;
			
				if packet_size256>1 then
					hwrite(my_line,datapath.data);
					writeline(my_file,my_line);
				end if;
				-- increase counter
				packet_size256:=packet_size256+1;
			
				-- EOP 
				if datapath.eop='1' then
					write(my_line,string'("## EOP (size "));
					write(my_line,packet_size256);
					write(my_line,string'(" words of 256 bit) ##"));
					writeline(my_file,my_line);
				end if;
			end if;
	end process;
end architecture rtl;
--=============================================================================
-- architecture end
--=============================================================================