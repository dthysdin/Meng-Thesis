-------------------------------------------------------------------------------
-- wrapper around cdcreduce for active high signals
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;



entity cdcor is

  generic (
    N   : integer := 2;                 -- number of inputs
    LEN : integer := 3
    );

  port (
    I : in  std_logic_vector(N - 1 downto 0);  -- rst inputs
    C : in  std_logic;                         -- output clock domain's clk
    O : out std_logic
    );

end entity cdcor;



architecture imp of cdcor is
begin

  orwrap : entity work.cdcreduce generic map (N => N, LEN => LEN, A => '1')
    port map (
      I => I,
      C => C,
      O => O
      );

end architecture imp;


