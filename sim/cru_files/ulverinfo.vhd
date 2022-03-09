library ieee;
use ieee.std_logic_1164.all;

package ulverinfo is

constant V203A : work.verinfopkg.verinforec:= (
BUILDUNIXTIME => 1601379420,
BUILDDATE => x"2020_09_29",
BUILDTIME => x"00_11_37_00",
MODFULLNAME => "MID                                                            ",
MODNAME => "MID                                                            ",
MODSHORTVER => "    ",
MODSHORTNAME => "MID     ", -- first 8 alpha chars
GITDESC => "0f880a0b-dirty                                                 ",
GITISDIRTY => 1,
GITHASH => "0f880a0bfed8dfb42ea9c959ec666ec821e36ef9",
GITSHORTHASH => x"0f880a0b",
BOARDTYPE => x"00000000"
);

end ulverinfo;
