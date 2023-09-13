library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity null_vfbc_backend is
  port
  (
    NULL_CLS            : in std_logic;
	 NULL_CLEARED        : out std_logic;
    NULL_CLK_I          : in std_logic;
    NULL_VFBC_CMD_DATA  : out std_logic_vector(31 downto 0);
    NULL_VFBC_CMD_WRITE : out std_logic;
    NULL_VFBC_WD_DATA   : out std_logic_vector(15 downto 0);
    NULL_VFBC_WD_WRITE  : out std_logic;
    NULL_VFBC_WD_RESET  : out std_logic
  );
end entity null_vfbc_backend;

architecture behavioral of null_vfbc_backend is

  signal pxlclk         : std_logic;
  signal clear_screen   : std_logic := '1';
  signal screen_cleared : std_logic := '0';
  
  signal vfbc_cmd_data_i  : std_logic_vector(31 downto 0) := (others => '0');
  signal vfbc_cmd_write_i : std_logic := '0';

  signal vfbc_cnt : std_logic_vector(31 downto 0) := (others => '0');
  
  signal vfbc_cmd0 : std_logic_vector(31 downto 0);
  signal vfbc_cmd1 : std_logic_vector(31 downto 0);
  signal vfbc_cmd2 : std_logic_vector(31 downto 0);
  signal vfbc_cmd3 : std_logic_vector(31 downto 0);
  
  signal frame_base_addr : std_logic_vector(31 downto 0);
      
begin
  
  pxlclk <= NULL_CLK_I;
  clear_screen <= NULL_CLS;
  NULL_CLEARED <= screen_cleared;
  
  frame_base_addr <= x"49000000";
  
  --------------------------------
  -- VFBC Command Logic
  --------------------------------

  NULL_VFBC_CMD_DATA  <= vfbc_cmd_data_i;
  NULL_VFBC_CMD_WRITE <= vfbc_cmd_write_i;
  
  NULL_VFBC_WD_DATA  <= (others => '0');
  NULL_VFBC_WD_WRITE <= '1' when ((vfbc_cnt > 79) and (vfbc_cnt < 3686480)) else
                        '0';
  
  NULL_VFBC_WD_RESET <= '1' when (vfbc_cnt < 50) else
                        '0'; 
  
  vfbc_cmd0 <= x"00000A00";
  vfbc_cmd1 <= '1' & frame_base_addr(30 downto 0);
  vfbc_cmd2 <= x"00000B3F";
  vfbc_cmd3 <= x"00000A00";
 
  CLEAR_SCREEN_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (vfbc_cnt = 75) then
		  vfbc_cmd_data_i <= vfbc_cmd0;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cnt = 76) then
		  vfbc_cmd_data_i <= vfbc_cmd1;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cnt = 77) then
		  vfbc_cmd_data_i <= vfbc_cmd2;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cnt = 78) then
		  vfbc_cmd_data_i <= vfbc_cmd3;
        vfbc_cmd_write_i <= '1';
      else
		  vfbc_cmd_data_i <= (others => '0');
        vfbc_cmd_write_i <= '0';
		end if;
    end if;
  end process CLEAR_SCREEN_PROC;
  
  screen_cleared <= '1' when (vfbc_cnt = 3686480) else
                    '0';

  VFBC_CNT_PROC: process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
	   if (clear_screen = '0') then
        vfbc_cnt <= (others => '0');
      elsif (vfbc_cnt < 3686480) then
        vfbc_cnt <= vfbc_cnt + 1;
      end if;
    end if;
  end process VFBC_CNT_PROC;

end behavioral;
