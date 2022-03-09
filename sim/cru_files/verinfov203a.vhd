library ieee;
use ieee.std_logic_1164.all;

package verinfo is

constant V203A : work.verinfopkg.verinforec:= (
BUILDUNIXTIME => 1601379420,
BUILDDATE => x"2020_09_29",
BUILDTIME => x"00_11_37_00",
MODFULLNAME => "preint                                                         ",
MODNAME => "preint                                                         ",
MODSHORTVER => "    ",
MODSHORTNAME => "preint  ", -- first 8 alpha chars
GITDESC => "v3.8.0-1-ge7687156-dirty                                       ",
GITISDIRTY => 1,
GITHASH => "e76871560ab9390044c30750d7a5c7f934624202",
GITSHORTHASH => x"e7687156",
BOARDTYPE => x"00763232"
);

end verinfo;
