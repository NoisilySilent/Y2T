library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pixel_filter is
  port
  (
    R_I     : in std_logic_vector(7 downto 0);
    G_I     : in std_logic_vector(7 downto 0);
    B_I     : in std_logic_vector(7 downto 0);
	 CLK_I   : in std_logic;
	 DE_I    : in std_logic;
    R_O     : out std_logic_vector(7 downto 0);
    G_O     : out std_logic_vector(7 downto 0);
    B_O     : out std_logic_vector(7 downto 0);
	 CLK_O   : out std_logic;
	 DE_O    : out std_logic;
	 PXL_CNT : in std_logic_vector(3 downto 0);
	 EN      : in std_logic
  );
end entity pixel_filter;

architecture behavioral of pixel_filter is

  signal pxlclk_in  : std_logic;
  signal pxlclk_out : std_logic;
  signal red   : std_logic_vector(7 downto 0);
  signal green : std_logic_vector(7 downto 0);
  signal blue  : std_logic_vector(7 downto 0);
  signal red_reg   : std_logic_vector(7 downto 0);
  signal green_reg : std_logic_vector(7 downto 0);
  signal blue_reg  : std_logic_vector(7 downto 0);
  signal p_cnt  : std_logic_vector(3 downto 0);
  signal de_out : std_logic;

begin

red   <= R_I;
green <= G_I;
blue  <= B_I;
p_cnt <= PXL_CNT;

--R_O <= R_I when EN = '0' else
--       std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(red) + (10 - p_cnt)*ieee.numeric_std.unsigned(red_reg)) / 9, 8));
--G_O <= G_I when EN = '0' else
--       std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(green) + (10 - p_cnt)*ieee.numeric_std.unsigned(green_reg)) / 9, 8));
--B_O <= B_I when EN = '0' else
--       std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(red) + (10 - p_cnt)*ieee.numeric_std.unsigned(red_reg)) / 9, 8));
--CLK_O <= CLK_I when EN = '0' else
--         pxlclk_in and de_out;
--DE_O <= DE_I when EN = '0' else
--        de_out; 
R_O <= R_I;
G_O <= G_I;
B_O <= B_I;
CLK_O <= CLK_I;
DE_O <= DE_I;


--  signal_delay_proc : process (pxlclk_in)
--  begin
--    if (rising_edge(pxlclk_in)) then
--		red_reg <= red;
--		green_reg <= green;
--		blue_reg <= blue;
--    end if;
--  end process signal_delay_proc;
--  
--  DE_OUT_PROC : process (pxlclk_in) is
--  begin
--    if falling_edge(pxlclk_in) then
--      if p_count < 2 then
--		  de_out <= '0';
--		else 
--		  de_out <= de_in;
--		end if;
--    end if;
--  end process DE_OUT_PROC; 

end behavioral;
