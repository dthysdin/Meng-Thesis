-------------------------------------------------------------------------------
-- Title      : logic reduced syncronizer for clock domain crossing
-- Project    : 
-------------------------------------------------------------------------------
-- File       : cdcreduce.vhd
-- Author     : ALICE CRU team
-- Company    : 
-- Created    : 2016-06-12
-- Last update: 2017-07-23
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
--
-- configurable active high/low input.
-- output is asynchronously asserted, and synchronously deasserted.
-- typically used to synchronize active high/low resets across clock domains.
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Author  Description
-- 2016-06-12  mazsi   Created
-- 2017-07-23  mazsi   set the poweron value to the active value (A)
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;





entity cdcreduce is

  generic (
    N   : integer   := 2;               -- number of inputs
    LEN : integer   := 3;
    A   : std_logic := '1'              -- active value (1 => active high)
    );

  port (
    I : in  std_logic_vector(N - 1 downto 0);  -- rst inputs
    C : in  std_logic;                         -- output clock domain's clk
    O : out std_logic
    );

end entity cdcreduce;





architecture imp of cdcreduce is

  attribute altera_attribute        : string;
  attribute altera_attribute of imp : architecture is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

  signal inactive_values : std_logic_vector(I'range);

  signal anyrst : std_logic;

  signal clock_domain_crossing_any_sync : std_logic_vector(LEN - 1 downto 0) := (others => A);

begin

  inactive_values <= (others => not A);  -- input is compared to this: all not active (not A)

  anyrst <= or_reduce(I xor inactive_values);  -- true if at least one differs (= is active)

  process (C, anyrst) is
  begin
    if anyrst = '1' then
      clock_domain_crossing_any_sync <= (others => A);  -- set pipe to active level
    elsif C'event and C = '1' then
      clock_domain_crossing_any_sync <= clock_domain_crossing_any_sync(LEN - 2 downto 0) & not A;
    end if;
  end process;

  O <= clock_domain_crossing_any_sync(LEN - 1);

end architecture imp;
