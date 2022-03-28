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
-- last changes: <23/01/2022>
-- enabled more avalon registers 
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
        monitor : in t_mid_monitor;
        config  : out t_mid_config

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
	-- avalon sx 
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
	signal dirty_idcode : std_logic_vector(31 downto 0);

        -- config
        signal s_config  : t_mid_config := (mid_rst     => '0',              -- default MID reset is 0          
                                            mid_cruid   => x"0",             -- default MID CRUID is 0         
                                            mid_switch  => x"0",             -- default MID switch is 0
                                            mid_mapping => (others => '0'),  -- default MID GBT mapping is 0 (32-bit per EPN)
                                            mid_sync    => x"080");          -- default MID sync  x"080" (synchronization every 128 HBF) 

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
	-- ALL DETECTOR USER logic should reserve the same area with the same INFORMATION
	-- See COMMON for more help on avalon slaves
        -- ##Personal notes:
        -- ## MODE_LG = 4  (for simulation)
        -- ## MODE_LG = c_MODE_LGR (for final compilation)
	-----------------------------------------------------------------------------
	id_comp : avalon_mm_slave
        generic map (
        MODE_LG => 4, 
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
                    1 to 5   => x"2", -- output + input
                    6 to 12  => x"4", -- disabled for the moment (not used by MID)
                    13 to 14 => x"1", -- 2 gbt inputs 
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
        USERWR  => s_av_wr, -- vector of 0..4
        USERRD  => s_av_rd,
        --
        qout => s_av_o,
        --
        din  => s_av_i
        );
        --=============================================================================
	-- Begin of p_mid_reset
	-- This process allows the MID UL to generate a reset pulse using avalon register
        -- as a catalyst
	--=============================================================================
	p_mid_reset : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_config.mid_rst = '0' then 
           if s_av_wr(0) = '1' then
            s_config.mid_rst <= '1';
           end if;
          else 
           s_config.mid_rst <= '0';
          end if;
         end if;
	end process;
        --=============================================================================
	-- Begin of p_mid_CRUID
	-- This process collects the CRUID from avalon port
	--=============================================================================
	p_mid_CRUID : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_av_wr(1) = '1' then
           s_config.mid_cruid <= s_av_o(1)(3 downto 0);
          end if;
         end if;
	end process;
        --=============================================================================
	-- Begin of _timeframe_length 
	-- This process collects the timeframe length from avalon port
	--=============================================================================
	p_timeframe_length : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_av_wr(2) = '1' then
           s_config.mid_sync <= s_av_o(2)(11 downto 0);
          end if;
         end if;
	end process;
        --=============================================================================
	-- Begin of p_gbt_mapping
	-- This process collects the fiber mapping from avalon port
	--=============================================================================
	p_gbt_mapping : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          -- EPN#0
          if s_av_wr(3) = '1' then
           s_config.mid_mapping(3 downto 0) <= s_av_o(3)(3 downto 0);
          end if;
          -- EPN#1
          if s_av_wr(4) = '1' then
           s_config.mid_mapping(7 downto 4) <= s_av_o(4)(3 downto 0);
          end if; 
         end if;
	end process;
        --=============================================================================
	-- Begin of p_mid_gbt_switch
	-- This process collects the gbt config word from avalon port
	--=============================================================================
	p_mid_gbt_switch : process(MMS_CLK)
	begin
         if rising_edge(MMS_CLK) then
          if s_av_wr(5) = '1' then
           s_config.mid_switch <= s_av_o(5)(3 downto 0);
          end if;
         end if;
	end process;

	-- feedback configuration signals 
        s_av_i(0)  <= x"0000000" & "000" & s_config.mid_rst;
        s_av_i(1)  <= x"0000000" & s_config.mid_cruid;
        s_av_i(2)  <= x"00000" & s_config.mid_sync; 
        s_av_i(3)(3 downto 0)  <= s_config.mid_mapping(3 downto 0);
        s_av_i(4)(3 downto 0)  <= s_config.mid_mapping(7 downto 4);
        s_av_i(5)  <= x"0000000" & s_config.mid_switch;

        s_av_i(13) <= monitor.trg;
        s_av_i(14) <= monitor.dw(0);
        s_av_i(15) <= monitor.dw(1);
        gen_status_monit : for i in 0 to c_NUM_GBT_USED-1 generate
         s_av_i(16+i) <= monitor.gbt(i);
        end generate;

        -- output 
        config.mid_rst     <= s_config.mid_rst;
	config.mid_switch  <= s_config.mid_switch;
        config.mid_cruid   <= s_config.mid_cruid;
        config.mid_mapping <= s_config.mid_mapping;
        config.mid_sync    <= s_config.mid_sync;
 
        --=============================================================================
        --      READ/WRITE AVALON REGISTERS 
        --=============================================================================
        -- #Read all avalon registers under (module load)
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80004 --range=31                 # Read all registers 
        -- ---------------------------------------------------------------------------------------------------------
        -- #Write MID Reset
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80000 --val=0x00000001                # MID Reset (100 MHz clk cycle)
        -- ---------------------------------------------------------------------------------------------------------
        -- #Read/Write MID CRUID register              
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80004 --val=0x00000001                # Write MID CRUID = 1
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80004 --val=0x00000000                # Write MID CRUID = 0 -- default   
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80004 --range=1                  # Read MID CRUID register
        --------------------------------------------------------------------------------------------------------- 
        -- #Read/Write MID synchronization  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80008 --val=0x00000080                # Write MID sync  = 128 HBF -- default      
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80008 --range=1                  # Read  MID sync value 
        ---------------------------------------------------------------------------------------------------------
        -- #Read/Write GBT Mapping 
      
        -- ## EPN#0 
        -- ### Initial Mapping 
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x00000000                # Write MID mapping  default (0-7) 

        -- ### SPARE LINK 8,9,10,11
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x00000001                # Write MID mapping link 0 is taking data from link(8)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x00000002                # Write MID mapping link 0 is taking data from link(9)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x00000003                # Write MID mapping link 0 is taking data from link(10)
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x00000004                # Write MID mapping link 0 is taking data from link(11)
        -- .....                                                                      # .....
        -- .....                                                                      # .....
        -- .....                                                                      # .....
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x10000000                # Write MID mapping link 7 is taking data from link(8)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x20000000                # Write MID mapping link 7 is taking data from link(9)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x30000000                # Write MID mapping link 7 is taking data from link(10)
        -- roc-reg-write --i=#0 --ch=2 --add=0xc8000C --val=0x40000000                # Write MID mapping link 7 is taking data from link(11)

        -- ## EPN#1
        -- ### Initial Mapping 
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x00000000                # Write MID mapping  default (0-7) 

        -- ### SPARE LINK 8,9,10,11
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x00000001                # Write MID mapping link 0 is taking data from link(8)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x00000002                # Write MID mapping link 0 is taking data from link(9)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x00000003                # Write MID mapping link 0 is taking data from link(10)
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x00000004                # Write MID mapping link 0 is taking data from link(11)
        -- .....                                                                      # .....                           
        -- .....                                                                      # .....
        -- .....                                                                      # .....
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x10000000                # Write MID mapping link 7 is taking data from link(8)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x20000000                # Write MID mapping link 7 is taking data from link(9)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x30000000                # Write MID mapping link 7 is taking data from link(10)
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80010 --val=0x40000000                # Write MID mapping link 7 is taking data from link(11)

        --------------------------------------------------------------------------------------------------------- 
        -- #Read/Write MID switch register content
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80014 --val=0x00000000                # Write MID switch (0)          
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80014 --val=0x00000001                # Write MID switch (1)  
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80014 --val=0x00000002                # Write MID switch (2)
        -- roc-reg-write --i=#0 --ch=2 --add=0xc80014 --val=0x00000003                # Write MID switch (3)  
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80014 --range=1                  # Read  MID switch 
        ---------------------------------------------------------------------------------------------------------
        -- #Monitor trigger register
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80034 --range=1                  # read trigger monitoring register 
        ---------------------------------------------------------------------------------------------------------
        -- #Monitor DWrapper registers 
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80038 --range=1                  # read DWrapper#0 register 
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc8003C --range=1                  # read DWrapper#1 register 
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80038 --range=2                  # read all DWrapper registers 
        ---------------------------------------------------------------------------------------------------------
        -- #Monitor gbt registers  
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80040 --range=2                  # read from GBT#0 to GBT#1 registers (SA FLP)
        -- roc-reg-read-range --i=#0 --ch=2 --add=0xc80040 --range=16                 # read from GBT#0 to GBT#15 registers (CERN FLP)
---------------------------------------------------------------------------------------------------------       
end architecture rtl;
--=============================================================================
-- architecture end
--=============================================================================

