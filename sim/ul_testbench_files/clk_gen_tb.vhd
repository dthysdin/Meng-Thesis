-------------------------------------------------------------------------------
--  Cape Peninsula Universty of Technology --
------------------------------------------------------------------------------
-- Project	: Muon Identifier User Logic 
-------------------------------------------------------------------------------
-- File		: clk_gen.vhd
-- Author	: Orcel Thys <dieuveil.orcel.thys-dingou@cern.ch>
-- Author	: Orcel Thys
-- Company	: NRF iThemba LABS
-- Created	: 2019-07-02
-- Platform	: Quartus Pro 17.1
-- Standard	: VHDL'93/02
-------------------------------------------------------------------------------
-- Description: --
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Standard library 
library ieee;
-- Standard packages
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
--=============================================================================
--Entity declaration for clk_gen
--=============================================================================
entity clk_gen is
	generic (g_NUM_GBT_USED : natural := 2 );
	port (
	---------------------------------------------------------------------------
	-- activate 
	activate_ttc: in std_logic; -- ttc
	activate_sim: in std_logic; -- sim  
	activate_gbt: in std_logic; -- gbt
	-- reset;
	reset_p		: in std_logic;
	--clock out gen 
	clk_40 		: out  std_logic;
	clk_100 		: out  std_logic;
	clk_240 		: out  std_logic;
	-- gbt status 
	gbt_valid	: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_sel		: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	gbt_ready	: out std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	-- ttc status 
	ttc_valid	: out std_logic;
	ttc_ready	: out std_logic	
	---------------------------------------------------------------------------
	    );
end entity clk_gen;
--=============================================================================
-- architecture declaration
--============================================================================
architecture behavior of clk_gen is
	-- ========================================================
	-- function declarations
	-- ========================================================
	function fcn_or_reduce(arg : std_logic_vector) return std_logic is
		variable v_result : std_logic;
	begin
		v_result := '0';
		for i in arg'range loop
			v_result := v_result or arg(i);
		end loop;
		return v_result;
	end;
	-- ========================================================
	-- signal declarations
	-- ========================================================
	signal s_ttc_valid: std_logic_vector(4 downto 0) := "00001";

	signal s_clk_40	: std_logic;
	signal s_clk_100	: std_logic := '0';
	signal s_clk_240	: std_logic;
	signal s_clk_960	: std_logic := '0';
	
	signal s_gbt_pulse	: std_logic;
	signal s_gbt_valid	: std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal s_gbt_ready	: std_logic_vector(g_NUM_GBT_USED-1 downto 0);
	signal s_gbt_sel		: std_logic_vector(g_NUM_GBT_USED-1 downto 0); 
	
	signal s_pipe_40_to_240 : std_logic := '0';
	signal s_40 : std_logic := '0';
	
begin
	--=============================================================================
	-- Begin of p_clk40
	-- This generates the gbt clock
	--=============================================================================
	p_clk40 : process
	begin
		loop
			s_clk_40 <= '1';
			wait until rising_edge(s_clk_240);
			wait until rising_edge(s_clk_240);
			wait until rising_edge(s_clk_240);
			s_clk_40 <= '0';
			wait until rising_edge(s_clk_240);
			wait until rising_edge(s_clk_240);
			wait until rising_edge(s_clk_240);
			if (activate_sim = '0') then
				wait; 
			end if;
		end loop;
	end process;
	--=============================================================================
	-- Begin of p_clk100
	-- This generates the avalon clock
	--=============================================================================
	p_clk100: process
	begin 
		loop 
			s_clk_100 <= not(s_clk_100);
			wait for 5000 ps;
			if (activate_sim = '0') then 
				wait;
			end if;
		end loop;
	end process p_clk100;
	--=============================================================================
	-- Begin of p_clk240
	-- This generates the ttc clock
	--=============================================================================
	p_clk240 : process
	begin
		loop
			s_clk_240 <= '1';
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			s_clk_240 <= '0';
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			wait until rising_edge(s_clk_960);
			if (activate_sim ='0') then
				wait; 
			end if;
		end loop;
	end process;
	--=============================================================================
	-- Begin of p_clk960
	-- This generates the avalon clock
	--=============================================================================
	p_clk960: process
	begin  
		loop 
			s_clk_960 <= not(s_clk_960);
			wait for 520 ps;
			if (activate_sim = '0') then 
				wait;
			end if;
		end loop;
	end process p_clk960;
	--=============================================================================
	-- Begin of p_s40
	-- This generates the avalon clock
	--=============================================================================
	p_s40: process(reset_p,s_clk_40)
	begin
    if (reset_p ='1') then
      s_40 <= '0';
    elsif (rising_edge(s_clk_40)) then
      s_40 <= not(s_40); -- changes at every rising edge of s_clk_40
    end if;
	end process;
	--=============================================================================
	-- Begin of p_s240
	-- This generates the pulse on each rising edge of s40 
	--=============================================================================
	p_s240 : process(s_clk_240)
	begin
    if (rising_edge(s_clk_240)) then
		-- pipeline 
		s_pipe_40_to_240 <= s_40;
		-- rising edge of s40 
      if s_pipe_40_to_240 /= s_40 then
			-- pulse on 
			s_gbt_pulse    <= '1'; 
      else
			-- pulse off 
			s_gbt_pulse    <= '0';
      end if;
    end if;
	end process;
	
	-- GBT -- 
	gbt_v : for i in 0 to g_NUM_GBT_USED-1 generate 
		s_gbt_valid(i) <= s_gbt_pulse;
	end generate;
	--
	s_gbt_ready(g_NUM_GBT_USED-1 downto 0) <= (others => '1');
	s_gbt_sel(g_NUM_GBT_USED-1 downto 0) <= (others => '1');
	
	-- TTC --
	s_ttc_valid	<= s_ttc_valid(3 downto 0) & not fcn_or_reduce(s_ttc_valid) when rising_edge(s_clk_240);
	ttc_valid	<= s_ttc_valid(3) when activate_sim ='1' and activate_ttc = '1' else '0';
	ttc_ready	<= '1' when activate_sim ='1' and activate_ttc = '1' else '0';
	
	-- GBT -- 
	gbt_ready	<= s_gbt_ready when activate_gbt = '1' and activate_sim = '1'  else (others => '0');
	gbt_valid	<=	s_gbt_valid when activate_gbt = '1' and activate_sim = '1'  else (others => '0');
	gbt_sel		<= s_gbt_sel when activate_gbt = '1' and  activate_sim = '1' else (others => '0');
	
	-- CLK --
	clk_40		<= s_clk_40;
	clk_100		<= s_clk_100;
	clk_240		<= s_clk_240;
	
end architecture behavior;
--=============================================================================
-- architecture end
--=============================================================================