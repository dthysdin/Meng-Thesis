 -------------------------------------------------------------------------------
 -- Title      : avalon memory mapped slave
 -- Project    : 
 -------------------------------------------------------------------------------
 -- File       : avalon_mm_slave.vhd
 -- Author     : jozsef imrek <jozsef.imrek@cern.ch>
 -------------------------------------------------------------------------------
 -- Description:
 --
 -- avalon mm slave 
 --
 -- integer code for MODE is kept the same as they are in the original altrea file:
 -- 0 = Output, 1 = Input, 2 = Output + Input, 3 = Output w/ loopback, 4 = Disabled
 --
 -- to add clock domain crossing into / from ALTCLK, add 8 to the MODE:
 -- 8 = Output, 9 = Input, A = Output + Input, B = Output w/ loopback
 -- 8 = Output,            A = Output        , B = Output w/ loopback
 --
 -- limited to fullword access (template supports byte enables).
 --
 -------------------------------------------------------------------------------
 
 library ieee;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_misc.all;
   use ieee.numeric_std.all;
   use work.pack_cru_core.all;
 
 entity avalon_mm_slave is
   generic ( MODE_LG  : positive := 3;
             AWIDTH   : integer := 8;
             MODE     : Array4bit(63 downto 0)  := ( 0 => x"A", 1 => x"A", 2 => x"A", others => x"4");
             RSTVAL   : Array32bit(63 downto 0) := (others => (others =>'0')) );
   port    ( CLK      : in  std_logic                     := '0';
             RESET    : in  std_logic                     := '0';
             WAITREQ  : out std_logic;
             ADDR     : in  std_logic_vector(AWIDTH - 1 downto 0)  := (others => '0');
             WR       : in  std_logic                     := '0';
             WRDATA   : in  std_logic_vector(31 downto 0) := (others => '0');
             RD       : in  std_logic                     := '0';
             RDDATA   : out std_logic_vector(31 downto 0);
             RDVAL    : out std_logic;
             --       
             ALTCLK   : in  std_logic               := '0';
             --     
             USERWR   : out std_logic_vector((MODE_LG - 1 ) downto 0);
			 USERRD   : out std_logic_vector((MODE_LG - 1 ) downto 0); -- this signal is a read acknowledge, not a read request!
             --
             din      : in  Array32bit( (MODE_LG - 1) downto 0) := (others => (others =>'0'));
             qout     : out Array32bit( (MODE_LG - 1) downto 0) );
 end entity avalon_mm_slave;
 
 architecture imp of avalon_mm_slave is
 
   function nb_bit(mode_lg : in integer) return integer is
   begin
     if mode_lg = 1 then 
       return 1 ;
     else
       return integer(ieee.math_real.ceil(ieee.math_real.log2(real(mode_lg))));
     end if;
   end nb_bit;
 
   signal ddirect    : array32bit((MODE_LG - 1 ) downto 0):= (others => (others => '0'));
 
   signal altrst     : std_logic;
   signal userwr_int : std_logic_vector( MODE_LG -1 downto 0);
   signal userrd_int : std_logic_vector( MODE_LG -1 downto 0);
 
   signal RESET_INT  : std_logic_vector(0 downto 0);
   constant LOG2N  : integer := nb_bit(mode_lg);
   
   signal wordaddr : unsigned(LOG2N + 1 downto 2);
   signal wrdata_int : std_logic_vector(31 downto 0);
   signal REG      : array32bit(MODE_LG - 1 downto 0);
   signal rdsel    : array32bit( (2**LOG2N - 1) downto 0) := (others => (others =>'0'));
 
 begin
 
   -----------------------------------------------------------------------------
   -- helper signals for clock domain crossing into / from ALTCLK
   -- synchronized reset + counter that ticks every so often
   -----------------------------------------------------------------------------
 
   RESET_INT <= (0 => RESET);
   
   altrstgen : cdcreduce
     generic map ( N => 1 ,
                   A => '1' )             -- active value (1 => active high)
     port map    ( I => RESET_INT, 
                   C => ALTCLK, 
                   O => altrst);
 
   -----------------------------------------------------------------------------
   -- add clock domain crossing for input when instructed
   -----------------------------------------------------------------------------
 
   dgen : for i in ( MODE_LG - 1) downto 0 generate
	   userrd_int(i)  <= RD when (RESET = '0'and wordaddr=i ) else '0';
 
     -- input register are always n fdirect
     ddirect(i) <= din(i);

     -- USERRD can be synchrone with ALTCLK
     cdcnogen : if MODE(i) < x"5" generate  -- direct connection
       USERRD(i)  <= userrd_int(i); 
     end generate cdcnogen;
 
     cdcgen : if MODE(i) > x"7" generate  -- CDC only
       cdcuserrd : cdcbus
         generic map ( W => 1 )
         port map    ( CLKI => CLK, 
                       E    => userrd_int(i), 
                       I(0) =>'0' ,
                       CLKO => ALTCLK, 
                       RSTO => altrst, 
					   V    => USERRD(i), 
                       O    => open );
     end generate cdcgen;
     
   end generate dgen;

   -----------------------------------------------------------------------------
   --                    control signals, address decode
   -----------------------------------------------------------------------------
 
   WAITREQ <= '0';
  
   wordaddr <= unsigned(ADDR(wordaddr'range));
 
   -----------------------------------------------------------------------------
   --  write process in avalon clock domain
   -----------------------------------------------------------------------------
 
     process (CLK) is
     begin
       if rising_edge(CLK) then
         if RESET = '1' then
           REG <= RSTVAL(MODE_LG-1 downto 0);
		   USERWR_int <= (others=>'0');
           wrdata_int <= (others=>'0');
         elsif WR = '1'  and to_integer(wordaddr) < MODE_LG then
           REG(to_integer(wordaddr)) <= WRDATA;
           wrdata_int <= WRDATA;
		   USERWR_int(to_integer(wordaddr)) <= '1';
	     else
		   USERWR_int <= (others=>'0');
         end if;
       end if;
     end process;
 
   -----------------------------------------------------------------------------
   -- select what to present on read from bus: the value of REG, D input, or zeros
   -----------------------------------------------------------------------------
 
   rdselgen : for i in ( MODE_LG - 1) downto 0 generate
   begin
     rdsel(i) <= ddirect(i) when MODE(i) = x"1" or MODE(i) = x"9" else  --x"1"
                 ddirect(i) when MODE(i) = x"2" or MODE(i) = x"A" else  --x"2"
                 REG(i)     when MODE(i) = x"3" or MODE(i) = x"B" else  --x"3"
                 x"00000000";
   end generate rdselgen;
 
   -----------------------------------------------------------------------------
   -- read process: 32 bit * 2^LOG2N to 1 mux -- latency = 1
   -----------------------------------------------------------------------------
 
   RDVAL <= RD and not RESET when rising_edge(CLK);
 
   RDDATA <= rdsel(to_integer(wordaddr)) when rising_edge(CLK);
 
   -----------------------------------------------------------------------------
   -- add clock domain crossing for output when instructed
   -----------------------------------------------------------------------------
 
   qgen : for i in ( MODE_LG - 1) downto 0 generate
 
     cdcnogen0 : if ( MODE(i) = x"0" or MODE(i) = x"2" or MODE(i) = x"3" )  generate
       qout(i)   <= REG(i);
       USERWR(i) <= USERWR_int(i);
     end generate cdcnogen0 ;
     
     cdcnogen1 : if ( MODE(i) = x"1" or MODE(i) = x"4" )  generate
       qout(i)   <= x"00000000";
       USERWR(i) <= USERWR_int(i);
     end generate cdcnogen1 ;

     cdcgen0 : if ( MODE(i) = x"8" or MODE(i) = x"A" or MODE(i) = x"B" ) generate
       cdc : cdcbus
         generic map ( W      => 32,
                       FREEZE => false )
         port map    ( CLKI => CLK, 
                       E    => USERWR_int(i), 
                       I    => wrdata_int,
                       RSTVAL=>RSTVAL(i),
                       CLKO => ALTCLK, 
                       RSTO => altrst, 
                       V    => USERWR(i),
                       O    => qout(i)  );
     end generate cdcgen0;
     
     cdcgen1 : if ( MODE(i) = x"9" or MODE(i) > x"B" ) generate
       cdc : cdcbus
         generic map ( W => 32)
         port map    ( CLKI => CLK, 
                       E    => USERWR_int(i), 
                       I    => x"00000000",
                       RSTVAL=>RSTVAL(i),
                       CLKO => ALTCLK, 
                       RSTO => altrst, 
                       V    => USERWR(i),
                       O    => qout(i)  );
     end generate cdcgen1;
     
   end generate qgen;
 
 end architecture imp;
