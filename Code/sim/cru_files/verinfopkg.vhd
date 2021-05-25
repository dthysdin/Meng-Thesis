-------------------------------------------------------------------------------
-- Title      : verinfopkg definitions
-- Project    : 
-------------------------------------------------------------------------------
-- File       : verinfopkg.vhd
-- Author     : jozsef imrek <jozsef.imrek@cern.ch>
-- Company    : 
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package verinfopkg is

  constant VERINFOMAGIC    : std_logic_vector(31 downto 0) := x"56_49_4e_46";  -- "VINF"
  constant VERINFOALTMAGIC : std_logic_vector(31 downto 0) := x"76_69_6e_66";  -- "vinf"

  type verinforec is record

    BUILDUNIXTIME : integer;
    BUILDDATE     : std_logic_vector(31 downto 0);
    BUILDTIME     : std_logic_vector(31 downto 0);

    MODFULLNAME  : string(1 to 63);
    MODNAME      : string(1 to 63);
    MODSHORTVER  : string(1 to 4);
    MODSHORTNAME : string(1 to 8);

    GITDESC      : string(1 to 63);
    GITISDIRTY   : integer;
    GITHASH      : string(1 to 40);
    GITSHORTHASH : std_logic_vector(31 downto 0);

    BOARDTYPE : std_logic_vector(31 downto 0);

  end record verinforec;



  function "=" (a : verinforec; b : verinforec) return boolean;

  function fake (fullname : string) return verinforec;

end verinfopkg;





package body verinfopkg is



  function "=" (a : verinforec; b : verinforec) return boolean is
  begin
    return
      a.BUILDUNIXTIME = b.BUILDUNIXTIME and a.BUILDDATE = b.BUILDDATE and a.BUILDTIME = b.BUILDTIME and
      a.MODFULLNAME = b.MODFULLNAME and a.MODNAME = b.MODNAME and a.MODSHORTVER = b.MODSHORTVER and a.MODSHORTNAME = b.MODSHORTNAME and
      a.GITDESC = b.GITDESC and a.GITISDIRTY = b.GITISDIRTY and a.GITHASH = b.GITHASH and a.GITSHORTHASH = b.GITSHORTHASH and a.BOARDTYPE = b.BOARDTYPE;
  end function;





  function fake (fullname : string) return verinforec is
    variable ret : verinforec;
  begin

    -- init with default values
    ret := (
      BUILDUNIXTIME => 0,
      BUILDDATE     => x"1970_01_01",
      BUILDTIME     => x"00_00_00_00",
      MODFULLNAME   => "-                                                              ",
      MODNAME       => (others => '-'),
      MODSHORTVER   => (others => '-'),
      MODSHORTNAME  => (others => '-'),
      GITDESC       => "-------                                                        ",
      GITISDIRTY    => 0,
      GITHASH       => (others => 'f'),
      GITSHORTHASH  => (others => '1'),
      BOARDTYPE     => x"0000_0000"
      );

    -- overwrite with argument
    ret.MODFULLNAME(fullname'range) := fullname;

    return ret;

  end function;



end package body verinfopkg;


