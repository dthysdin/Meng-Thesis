------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: avalon_logic.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Student No	: 214349721
-- Company	: NRF iThemba LABS
-- Created   	: 2020-06-27
-- Platform  	: Quartus Pro 18.1
-- Standard 	: VHDL'93'
-- Version	: 2.0
-------------------------------------------------------------------------------
-- last changes: <13/02/2021> 
-------------------------------------------------------------------------------
-- TODO:  <completed>
-------------------------------------------------------------------------------
-- Description:
-- This component deals with the avalon interface of the MID user logic
-- Requirements:
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
-- Specific package 
use work.pack_cru_core.all;
use work.pack_mid_ul.all;
--=============================================================================
--Entity declaration for avalon_ulogic
--============================================================================
entity avalon_ulogic is
        generic (g_NUM_GBT_USED : integer);
	port (
	-----------------------------------------------------------------------
	mms_clk 	: in  std_logic;
	mms_reset 	: in  std_logic;
	mms_waitreq     : out std_logic ;
	mms_addr        : in  std_logic_vector(23 downto 0);
	mms_wr		: in  std_logic;
	mms_wrdata	: in  std_logic_vector(31 downto 0);
	mms_rd		: in  std_logic;
	mms_rdval	: out std_logic;
	mms_rddata	: out std_logic_vector(31 downto 0);
	--
	reset		: out std_logic;
        cruid           : out std_logic;
        --  
        trg_monit       : in std_logic_vector(31 downto 0);          -- triggers monitor 
        dw_monit        : in Array32bit(1 downto 0);                  -- d-wrappers monitor 
        gbt_monit       : in Array64bit(g_NUM_GBT_USED-1 downto 0)   -- gbt ulogic monitor 
				);  
end avalon_ulogic;
--=============================================================================
-- architecture declaration
--============================================================================
architecture rtl of avalon_ulogic is
	-- ========================================================
	-- constant declarations
	-- ========================================================
	-- avalon 
	constant ULVERSION : work.verinfopkg.verinforec := work.ulverinfo.V203A;-- mid_ulverinfo
	constant c_MODE_LGR: natural := 32;
        constant c_null : std_logic_vector(31 downto 0) := (others => '0');
	-- ========================================================
	-- signal declarations
	-- ========================================================
	-- avalon
	signal sx_wr        : std_logic_vector(1 downto 0);
	signal sx_rd        : std_logic_vector(1 downto 0);
	signal sx_addr      : Array32bit(0 to 1);
	signal sx_wrdata    : Array32bit(0 to 1);
	signal sx_rddata    : Array32bit(0 to 1):= (others => (others => '0'));
	signal sx_rdval     : std_logic_vector(1 downto 0) := (others => '0');
	signal sx_waitreq   : std_logic_vector(1 downto 0) := (others => '0');

	-- AV signals
	signal s_av_i       : Array32bit((c_MODE_LGR - 1) downto 0);
	signal s_av_o       : Array32bit((c_MODE_LGR - 1) downto 0);
	signal s_av_reg     : std_logic;
	signal s_av_wr      : std_logic_vector((c_MODE_LGR - 1) downto 0);
	signal s_av_rd      : std_logic_vector((c_MODE_LGR - 1) downto 0);

	-- Avalon registers
	signal dirty_idcode : std_logic_vector(31 downto 0);
        signal s_mid_reset  : std_logic;
        signal s_toggle     : std_logic_vector(31 downto 0) := (others => '0');
        signal s_cruid      : std_logic_vector(31 downto 0) := (others => '0');
begin	

	--========================================================================---
	-- AVALON INTERFACE FROM DUMMY_UL
	--========================================================================--
	-----------------------------------------------------------------------------
	-- bus mux/demux to 2 address ranges: 0 => idcomp 1 => regs, others not yet used
	-- bit 19 :  idcomp => x"0_0000", ranges => x"8_0000"
	-----------------------------------------------------------------------------
	busmux : avalon_mm_bus_arbitrer generic map (
        AWIDTH => 20, NHI => 1, NM => 1)
        port map (
        clk                      => mms_clk,
        rst                      => mms_reset,
        --
        m_waitreq(0)       	 => mms_waitreq,
        m_addr(0)(23 downto 0)	 => mms_addr,
        m_addr(0)(31 downto 24)  => x"00",
        m_wr(0)                  => mms_wr,
        m_wrdata(0)              => mms_wrdata,
        m_rd(0)                  => mms_rd,
        m_rdval(0)               => mms_rdval,
        m_rddata(0)              => mms_rddata,
        --
        s_waitreq                => sx_waitreq,
        s_addr                   => sx_addr,
        s_wr                     => sx_wr,
        s_wrdata                 => sx_wrdata,
        s_rd                     => sx_rd,
        s_rdval                  => sx_rdval,
        s_rddata                 => sx_rddata
                );
	-----------------------------------------------------------------------------
	-- avalon memory mapped slave: local ID and status registers (0)
	-- ALL DETECTOR USER logic should reserve the same area with the same INFORMATION
	-- See COMMON for more help on avalon slaves
        -- ## remove (4 for sim)
	-----------------------------------------------------------------------------
	id_comp : avalon_mm_slave
        generic map (
        MODE_LG => 4, --c_MODE_LGR, 
        AWIDTH  => 8,
        MODE    => (0 to 3  => x"1", -- input 
                    others  => x"4") -- disabled 
            )
        port map (
        clk     => mms_clk,
        reset   => mms_reset,
        waitreq => sx_waitreq(0),
        addr    => sx_addr(0)(7 downto 0),
        wr      => sx_wr(0),
        wrdata  => sx_wrdata(0),
        rd      => sx_rd(0),
        rdval   => sx_rdval(0),
        rddata  => sx_rddata(0),
        --
        din(0)  => dirty_idcode,
        din(1)  => ULVERSION.GITSHORTHASH,
        din(2)  => ULVERSION.BUILDDATE,
        din(3)  => ULVERSION.BUILDTIME);
		  
	dirty_idcode(31)   	   <= '1' when ULVERSION.GITISDIRTY = 1 else'0';
	dirty_idcode(30 downto 16) <= (others=>'0');
	dirty_idcode(15 downto 0)  <= x"A003"; -- MID IDCODE
	----------------------------------------------------------------------------
	-- avalon memory mapped slave
	-- See COMMON for more help on avalon slaves
	-----------------------------------------------------------------------------
	regs : avalon_mm_slave
        generic map (
        MODE_LG => c_MODE_LGR,
        AWIDTH  => 8,
        MODE    => (0        => x"0", -- output
                    1 to 2   => x"2", -- output + input
                    3 to 12  => x"4", -- disabled for the moment
                    13 to 31 => x"1", -- input 
                    others   => x"4") -- disabled
        )
        port map (
        clk     => mms_clk,
        reset   => mms_reset,
        WAITREQ => sx_waitreq(1),
        addr    => sx_addr(1)(7 downto 0),
        wr      => sx_wr(1),
        wrdata  => sx_wrdata(1),
        rd      => sx_rd(1),
        rdval   => sx_rdval(1),
        rddata  => sx_rddata(1),
        --
        ALTCLK  => '0',
        --
        USERWR  => s_av_wr, -- vector of 0..2
        USERRD  => s_av_rd,
        --
        qout => s_av_o,
        --
        din  => s_av_i
        );
	-----------------------------------------------------------------------------
	-- Get the MID reset signal from avalon port
	-----------------------------------------------------------------------------
	p_mid_reset_in : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_mid_reset = '0' then 
           if s_av_wr(0) = '1' then
            s_mid_reset <= '1';
           end if;
          else 
           s_mid_reset <= '0';
          end if;
         end if;
	end process;
        -----------------------------------------------------------------------------
	-- Get the MID cru ID signal from avalon port
	-----------------------------------------------------------------------------
	p_mid_cruid_in : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_av_wr(1) = '1' then
           s_cruid <= s_av_o(1);
          end if;
         end if;
	end process;
        -----------------------------------------------------------------------------
	-- Get the MID toggle signal from avalon port
	-----------------------------------------------------------------------------
	p_mid_toggle : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_av_wr(2) = '1' then
           s_toggle <= s_av_o(2);
          end if;
         end if;
	end process;
         
	-- send the cruid value 
        s_av_i(1) <= s_cruid;
        -- send toogle value back 
        s_av_i(2) <= s_toggle;
        -- send triggers monitor to avalon port 
        s_av_i(13) <= trg_monit;
        -- send packets monitor to avalon port 
        s_av_i(14) <= dw_monit(0);
        s_av_i(15) <= dw_monit(1);
	-- send gbt ulogic monitor to avalon port 
        gen_status_monit : for i in 0 to g_NUM_GBT_USED-1 generate
         s_av_i(16+i) <= gbt_monit(i)(31 downto 0) when s_toggle /= c_null else gbt_monit(i)(63 downto 32);
        end generate;
        -- reset 
	reset <= s_mid_reset;
        -- cruid 
        cruid <= '1' when s_cruid /= c_null else '0';

end architecture rtl;
--=============================================================================
-- architecture end
--=============================================================================