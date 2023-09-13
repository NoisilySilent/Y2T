library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity tate_vfbc_backend is
  port
  (
    TATE_DI             : in std_logic_vector(15 downto 0);
    TATE_DE             : in std_logic;
    TATE_NEW_FRAME	   : in std_logic;
    TATE_FB_SELECT	   : in std_logic_vector(1 downto 0);
    TATE_CLK_I          : in std_logic;
    TATE_VFBC_CMD_DATA  : out std_logic_vector(31 downto 0);
    TATE_VFBC_CMD_WRITE : out std_logic;
    TATE_VFBC_WD_DATA   : out std_logic_vector(15 downto 0);
    TATE_VFBC_WD_WRITE  : out std_logic;
	 TATE_VFBC_WD_RESET  : out std_logic
  );
end entity tate_vfbc_backend;

architecture behavioral of tate_vfbc_backend is

  constant zero : std_logic_vector(15 downto 0) := x"0000";

  signal new_frame : std_logic;
  signal pxlclk : std_logic;
  
  signal vfbc_cmd_data_i : std_logic_vector(31 downto 0) := (others => '0');
  signal vfbc_cmd_write_i : std_logic := '0';
  
  signal vfbc_cmd_cnt : std_logic_vector(31 downto 0) := (others => '0');
  
  signal vfbc_cmd0 : std_logic_vector(31 downto 0);
  signal vfbc_cmd1 : std_logic_vector(31 downto 0);
  signal vfbc_cmd2 : std_logic_vector(31 downto 0);
  signal vfbc_cmd3 : std_logic_vector(31 downto 0);
  
  signal frame_base_addr : std_logic_vector(31 downto 0);
  signal frame_buffer_select : std_logic_vector(1 downto 0) := "00";
      
begin
  
  pxlclk <= TATE_CLK_I;
  new_frame <= TATE_NEW_FRAME;
  frame_buffer_select <= TATE_FB_SELECT;

  --------------------------------
  -- VFBC Command Logic
  --------------------------------

  TATE_VFBC_CMD_DATA <= vfbc_cmd_data_i;
  TATE_VFBC_CMD_WRITE <= vfbc_cmd_write_i;
  
  vfbc_cmd0 <= x"00000A00";
  vfbc_cmd1 <= '1' & frame_base_addr(30 downto 0);
  vfbc_cmd2 <= x"000001DF";
  vfbc_cmd3 <= x"00000A00";
 
  VFBC_FEED_CMD_PROCESS: process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (vfbc_cmd_cnt = 75) then
        vfbc_cmd_data_i <= vfbc_cmd0;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cmd_cnt = 76) then
        vfbc_cmd_data_i <= vfbc_cmd1;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cmd_cnt = 77) then
        vfbc_cmd_data_i <= vfbc_cmd2;
        vfbc_cmd_write_i <= '1';
      elsif (vfbc_cmd_cnt = 78) then
        vfbc_cmd_data_i <= vfbc_cmd3;
        vfbc_cmd_write_i <= '1';
      else
        vfbc_cmd_data_i <= (others => '0');
        vfbc_cmd_write_i <= '0';
      end if;
    end if;
  end process VFBC_FEED_CMD_PROCESS;
  
  VFBC_CMD_CNT_PROCESS: process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (new_frame = '1') then
        vfbc_cmd_cnt <= (others => '0');
        case frame_buffer_select is
          when "00" => frame_base_addr <= x"4904E200";
          when "01" => frame_base_addr <= x"49210200";
          when "10" => frame_base_addr <= x"493D2200";
          when "11" => frame_base_addr <= x"49594200";
	       when others => frame_base_addr <= x"4904E200";
        end case;
      else
        vfbc_cmd_cnt <= vfbc_cmd_cnt + 1;
      end if;
    end if;
  end process;
 
  --------------------------------
  -- VFBC Write Logic
  --------------------------------

  TATE_VFBC_WD_WRITE <= TATE_DE;
  TATE_VFBC_WD_DATA <= TATE_DI;
  TATE_VFBC_WD_RESET <= '1' when (vfbc_cmd_cnt < 50) else
                        '0'; 
  
end behavioral;
