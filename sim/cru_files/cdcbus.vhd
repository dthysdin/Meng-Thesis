-------------------------------------------------------------------------------
-- Title      : synchronizer for clock domain crossing
-- Project    : 
-------------------------------------------------------------------------------
-- File       : cdcbus.vhd
-- Author     : 
-------------------------------------------------------------------------------
-- Description:
--
-- bring a whole bus across a clock domain crossing
-- E indicates when new value is presented on I.
-- V indicates when O output is updated.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity cdcbus is

  generic (
    FREEZE : boolean := true;           -- capture data in src clk domain?
    W      : integer := 32;             -- bus width
    N      : integer := 6               -- delay for Valid (in CLKO clocks)
    );

  port (
    CLKI : in  std_logic;               -- input clock domain's clk
    E    : in  std_logic;
    I    : in  std_logic_vector(W - 1 downto 0);
    RSTVAL : in std_logic_vector(W-1 downto 0):=(others=>'0');
    --
    CLKO : in  std_logic;               -- output clock domain's clk
    RSTO : in  std_logic := '0';
    V    : out std_logic;
    O    : out std_logic_vector(W - 1 downto 0)
    );

end entity cdcbus;


architecture imp of cdcbus is

  signal rsti                            : std_logic;
  signal cnt                             : integer range 0 to N - 1 := 0;
  signal clock_domain_crossing_bus_pulse : std_logic;
  signal clock_domain_crossing_bus_data  : std_logic_vector(W - 1 downto 0);

  signal transfer : std_logic_vector(W - 1 downto 0);

  signal newpulse                          : std_logic_vector(2 downto 0) := (others => '0');
  signal newdata                           : std_logic;
  signal clock_domain_crossing_bus_newdata : std_logic_vector(W - 1 downto 0);


  attribute altera_attribute        : string;
  attribute altera_attribute of imp : architecture is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

begin



  -----------------------------------------------------------------------------
  -- bring reset into CLKI clock domain
  -----------------------------------------------------------------------------

  rstigen : entity work.cdcor generic map (N => 1)
    port map (I(0) => RSTO, C => CLKI, O => rsti);



  -----------------------------------------------------------------------------
  -- stretch + delay E, freeze input data
  -----------------------------------------------------------------------------

  process (CLKI) is
  begin
    if rising_edge(CLKI) then

      if E = '1' then
        cnt                             <= N - 1;
        clock_domain_crossing_bus_pulse <= '1';
      elsif cnt /= 0 then
        cnt                             <= cnt - 1;
        clock_domain_crossing_bus_pulse <= '1';
      else
        cnt                             <= cnt;
        clock_domain_crossing_bus_pulse <= '0';
      end if;

      if rsti = '1' then
        clock_domain_crossing_bus_data <= RSTVAL(W-1 downto 0);
      elsif E = '1' then
        clock_domain_crossing_bus_data <= I;
      end if;

    end if;
  end process;

  -----------------------------------------------------------------------------
  -- select if we use captured or non captured version of input
  -----------------------------------------------------------------------------

  transfer <= clock_domain_crossing_bus_data when FREEZE else I;

  -----------------------------------------------------------------------------
  -- bring pulse into the output clock domain, detect falling edge
  -----------------------------------------------------------------------------

  newpulse <= newpulse(1 downto 0) & clock_domain_crossing_bus_pulse when rising_edge(CLKO);
  newdata  <= newpulse(2) and not newpulse(1)                        when rising_edge(CLKO);

  -----------------------------------------------------------------------------
  -- capture data in new clock domain, generate Valid flag
  -----------------------------------------------------------------------------

  process (CLKO) is
  begin
    if rising_edge(CLKO) then

      V <= newdata;

      if RSTO = '1' then
        clock_domain_crossing_bus_newdata <= RSTVAL(W-1 downto 0);
      elsif newdata = '1' then
        clock_domain_crossing_bus_newdata <= transfer;
      end if;

    end if;
  end process;

  O <= clock_domain_crossing_bus_newdata;

end architecture imp;
