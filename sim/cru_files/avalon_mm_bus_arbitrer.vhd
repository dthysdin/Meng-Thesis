 ------------------------------------------------------------------------------
 -- Title      : custom interconnect, with configurable address width
 -- Project    :
 ------------------------------------------------------------------------------
 -- File       : avalon_mm_bus_arbitrer ( ex avalon_mm_ic_merged.vhd )
 -- Author     : jozsef imrek <jozsef.imrek@cern.ch>
 -- Company    : 
 -- Created    : 2017-04-20
 -- Last update: 2018-07-11
 -- Platform   : 
 -- Standard   : VHDL'93/02
 ------------------------------------------------------------------------------
 -- Description:
 --
 -- the algorithm arbitrating between masters is trivial to implement, but does
 -- not guarantee any fairness at all: a single master can monopolize the
 -- interconnect.  but this is slow control, access is assumed to be rare and
 -- not time critical.
 --
 -- read/write request parameters are captured in a set of registers. the module
 -- could be implemented without these extra registers to save resources, but
 -- this will give the fitter some extra room for manoeuvre.
 ------------------------------------------------------------------------------
 -- Copyright (c) 2017
 ------------------------------------------------------------------------------
 -- Revisions  :
 -- Date        Author  Description
 -- 2017-04-20  mazsi   Created
 -- 2017-04-22  mazsi   add support for multiple masters
 -- 2018 02 28          Add reference to package file
 --                     Add RST statement in msel_gen proecess
 --                     Change bus vector in array bus vector is possible
 ------------------------------------------------------------------------------
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.pack_cru_core.all;

 entity avalon_mm_bus_arbitrer is
   generic ( NM     : natural := 1;              -- no of masters
             AWIDTH : natural := 32; -- meaningfull address to test, and start point for decoding
             NHI    : natural := 3  );           -- no of address bits to decode
   port    (
     --------------------------------------------------------------------------
     CLK       : in  std_logic;
     RST       : in  std_logic;
     --------------------------------------------------------------------------
     M_WAITREQ : out std_logic_vector(NM - 1 downto 0);
     M_ADDR    : in  Array32bit(0 to NM - 1);
     M_WR      : in  std_logic_vector(NM - 1 downto 0);
     M_WRDATA  : in  Array32bit(0 to NM - 1 );
     M_RD      : in  std_logic_vector(NM - 1 downto 0);
     M_RDDATA  : out Array32bit(0 to NM - 1);
     M_RDVAL   : out std_logic_vector(NM - 1 downto 0);
     --------------------------------------------------------------------------
     S_WAITREQ : in  std_logic_vector(2**NHI - 1 downto 0);  -- := (others => '0');
     S_ADDR    : out Array32bit(0 to 2**NHI - 1);
     S_WR      : out std_logic_vector(2**NHI - 1 downto 0);
     S_WRDATA  : out Array32bit(0 to 2**NHI - 1);
     S_RD      : out std_logic_vector(2**NHI - 1 downto 0);
     S_RDDATA  : in  Array32bit(0 to 2**NHI - 1);            -- := (others => '1'); 
     S_RDVAL   : in  std_logic_vector(2**NHI - 1 downto 0) );-- := (others => '1'));
 end avalon_mm_bus_arbitrer;
 
 architecture imp of avalon_mm_bus_arbitrer is
 
    -- master side
   signal msel             : natural range 0 to NM - 1;
   signal mcs, mcspre      : std_logic_vector(NM - 1 downto 0);
   signal mwr, mrd         : std_logic; 
   signal mwrdata          : std_logic_vector(31 downto 0);
   signal maddr            : std_logic_vector(31 downto 0);
   -- Slave side           
   signal swaitreq, srdval : std_logic;
   signal scspre, swr, srd : std_logic_vector(2**NHI - 1 downto 0);
   signal swrdata, srddata : std_logic_vector(31 downto 0);
   signal saddrhi          : std_logic_vector(AWIDTH - 1 downto AWIDTH-NHI);
   signal saddrlo          : std_logic_vector(32 - 1 downto 0);
   type STATE_TYPE is (IDLE, ACCEPT, WAITACK, WAITRDVAL, PUTRDVAL);
   signal state            : STATE_TYPE;
 
 begin
 
   ----------------------------------------------------------------------------
   --                selecting which master to serve: NM : 1 mux
   ----------------------------------------------------------------------------
 
   -- select master candidate
   msel_gen : process (RST, CLK)
   begin
     if RST = '1' then
       msel <= 0;
     elsif rising_edge(CLK) then
       if msel = NM - 1 then
         msel <= 0;
       else
         msel <= msel + 1;
       end if;
     end if;
   end process;
 
   -- multiplex request parameters from masters
   maddr   <= M_ADDR(msel);
   mwr     <= M_WR(msel);
   mwrdata <= M_WRDATA(msel);
   mrd     <= M_RD(msel);
 
   -----------------------------------------------------------------------------
   -- state machine
   -----------------------------------------------------------------------------
 
   process (CLK)
   begin
     if rising_edge(CLK) then
       if RST = '1' then
         state <= IDLE;
       else
         case state is
            when IDLE     => if mwr = '1' or mrd = '1' then
                               state <= ACCEPT;
                             else
                               state <= IDLE;
                             end if;
           when ACCEPT    => state <= WAITACK;
           when WAITACK   => if swaitreq = '1' then  -- request is still not 
                               state <= WAITACK;     -- accepted by downstream
                             elsif swr /= (swr'range => '0') then  -- not all zeros = was a write, we are done
                               state <= IDLE;
                             elsif srdval = '1' then  -- was a read, and data is already available
                               state <= PUTRDVAL;
                             else  -- none of the above: it's accepted, it was a read, but no data yet
                               state <= WAITRDVAL;
                             end if;
           when WAITRDVAL => if srdval = '1' then
                               state <= PUTRDVAL;
                             else
                               state <= WAITRDVAL;
                             end if;
           when PUTRDVAL  => state <= IDLE;
         end case;
       end if;
     end if;
   end process;
 
   -----------------------------------------------------------------------------
   -- capture request parameters when accepting a request
   -- some signal decoding is done already here to improve timing:
   -- - decode msel into master chip selects
   -- - decode higher bits of write/read address into slave chip selects, then
   --   turn those into WR enable and RD enable
   -----------------------------------------------------------------------------
 
   mcsgen : for i in mcspre'range generate
     mcspre(i) <= '1' when msel = i else '0';
   end generate mcsgen;
 
   csgen : for i in scspre'range generate
     scspre(i) <= '1' when unsigned(maddr(AWIDTH - 1 downto AWIDTH - NHI)) = i else '0';
   end generate csgen;
 
   process (CLK) is
   begin
     if rising_edge(CLK) then
       if RST = '1' then
         mcs     <= (others => '0');
         saddrhi <= (others => '0');
         saddrlo <= (others => '0');
         swr     <= (others => '0');
         srd     <= (others => '0');
         swrdata <= (others => '0');
       else
         if state = IDLE then
           mcs     <= mcspre;
           saddrhi <= maddr(saddrhi'range);
         -- saddrlo is always 32 range
           saddrlo( AWIDTH-NHI - 1 downto 0) <= maddr(AWIDTH-NHI - 1 downto 0);
           saddrlo( 31 downto AWIDTH-NHI) <= (others =>'0');
           swr     <= scspre and (scspre'range => mwr);
           srd     <= scspre and (scspre'range => mrd);
           swrdata <= mwrdata;
         end if;
       end if;
     end if;
   end process;
 
   -----------------------------------------------------------------------------
   -- select appropriate wait request / rdval for the state machine to act on
   -----------------------------------------------------------------------------
 
   swaitreq <= S_WAITREQ(to_integer(unsigned(saddrhi)));
   srdval   <= S_RDVAL(to_integer(unsigned(saddrhi)));

   -----------------------------------------------------------------------------
   -- downstream request: same addr + wrdata to all slaves, decoded wr/rd enable
   -----------------------------------------------------------------------------
 
   S_ADDR(0 to 2**NHI - 1)   <= ( others => saddrlo);
   S_WRDATA(0 to 2**NHI - 1) <= ( others => swrdata);
   S_WR <= swr when state = WAITACK else (others => '0');
   S_RD <= srd when state = WAITACK else (others => '0');

   -----------------------------------------------------------------------------
   -- upstream response
   -- 1 clk low pulse on M_WAITREQ when accepting the request
   -- 1 clk high pulse on M_RDVAL when returning the result of a read
   -----------------------------------------------------------------------------
 
   M_WAITREQ <= not mcs when state = ACCEPT   else (others => '1');  -- always returns '1' on RST
   M_RDVAL   <= mcs     when state = PUTRDVAL else (others => '0');  -- always returns '0' on RST
 
   -- mux rddata input from slaves, then feed this rddata to every master
   
   srddata  <= S_RDDATA(to_integer(unsigned(saddrhi))) when rising_edge(CLK);
   M_RDDATA <= ( others => srddata );
 
 end architecture imp;
