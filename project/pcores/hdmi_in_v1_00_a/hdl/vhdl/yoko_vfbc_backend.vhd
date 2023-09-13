library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity yoko_vfbc_backend is
  port (
    YOKO_DI : in std_logic_vector(15 downto 0);
    YOKO_DE : in std_logic;
    YOKO_NEW_FRAME : in std_logic;
    YOKO_FB_SELECT : in std_logic_vector(1 downto 0);
    YOKO_CLK_I : in std_logic;
    YOKO_FRAME_BASE_ADDR : in std_logic_vector(31 downto 0);
    YOKO_VFBC_CMD_DATA : out std_logic_vector(31 downto 0);
    YOKO_VFBC_CMD_WRITE : out std_logic;
    YOKO_VFBC_WD_DATA : out std_logic_vector(15 downto 0);
    YOKO_VFBC_WD_WRITE : out std_logic
  );
end entity yoko_vfbc_backend;

architecture behavioral of yoko_vfbc_backend is

  constant zero : std_logic_vector(15 downto 0) := x"0000";

  signal line_buffer_01_din : std_logic_vector(15 downto 0) := (others => '0');
  signal line_buffer_01_dout : std_logic_vector(15 downto 0) := (others => '0');
  signal line_buffer_01_line : std_logic_vector(4 downto 0) := (others => '0');
  signal line_buffer_01_column : std_logic_vector(9 downto 0) := (others => '0');
  signal line_buffer_01_we : std_logic;

  signal line_buffer_02_din : std_logic_vector(15 downto 0) := (others => '0');
  signal line_buffer_02_dout : std_logic_vector(15 downto 0) := (others => '0');
  signal line_buffer_02_line : std_logic_vector(4 downto 0) := (others => '0');
  signal line_buffer_02_column : std_logic_vector(9 downto 0) := (others => '0');
  signal line_buffer_02_we : std_logic;

  signal wLine : std_logic_vector(4 downto 0) := (others => '0');
  signal rLine : std_logic_vector(4 downto 0) := (others => '0');
  signal wColumn : std_logic_vector(9 downto 0) := (others => '0');
  signal rColumn : std_logic_vector(9 downto 0) := (others => '0');
  signal pixel_dout : std_logic_vector(15 downto 0);
  signal new_frame : std_logic;
  signal pxlclk : std_logic;
  signal new_stripe : std_logic := '0';
  signal buffer_toggle : std_logic := '0';
  signal pixel_de : std_logic;
  signal pixel_delay_1 : std_logic;
  signal pixel_delay_2 : std_logic;
  signal pixel_delay_3 : std_logic;

  signal vfbc_cmd_data_i : std_logic_vector(31 downto 0) := (others => '0');
  signal vfbc_cmd_write_i : std_logic := '0';

  signal vfbc_cmd0 : std_logic_vector(31 downto 0);
  signal vfbc_cmd1 : std_logic_vector(31 downto 0);
  signal vfbc_cmd2 : std_logic_vector(31 downto 0);
  signal vfbc_cmd3 : std_logic_vector(31 downto 0);

  signal frame_base_addr : std_logic_vector(31 downto 0);
  signal frame_buffer_select : std_logic_vector(1 downto 0) := "00";

begin

  pxlclk <= YOKO_CLK_I;
  new_frame <= YOKO_NEW_FRAME;
  frame_buffer_select <= YOKO_FB_SELECT;

  --------------------------------
  -- Instantiate 2 stripe buffers
  --------------------------------

  LINE_BUFFER_X32_01 : entity work.line_buffer_x32
    port map
    (
      DI => line_buffer_01_din,
      DO => line_buffer_01_dout,
      LINE_I => line_buffer_01_line,
      PXL_I => line_buffer_01_column,
      WE => line_buffer_01_we,
      CLK => YOKO_CLK_I
    );

  LINE_BUFFER_X32_02 : entity work.line_buffer_x32
    port map
    (
      DI => line_buffer_02_din,
      DO => line_buffer_02_dout,
      LINE_I => line_buffer_02_line,
      PXL_I => line_buffer_02_column,
      WE => line_buffer_02_we,
      CLK => YOKO_CLK_I
    );

  YOKO_COUNTERS_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (new_frame = '1') then
        wLine <= (others => '0');
        wColumn <= "0000000001";
        rLine <= "11111";
        rColumn <= (others => '0');
        new_stripe <= '0';
        vfbc_cmd_data_i <= (others => '0');
        vfbc_cmd_write_i <= '0';
        case frame_buffer_select is
          when "00" => frame_base_addr <= YOKO_FRAME_BASE_ADDR + x"00019800";
          when "01" => frame_base_addr <= YOKO_FRAME_BASE_ADDR + x"001DB800";
          when "10" => frame_base_addr <= YOKO_FRAME_BASE_ADDR + x"0039D800";
          when "11" => frame_base_addr <= YOKO_FRAME_BASE_ADDR + x"0055F800";
          when others => frame_base_addr <= YOKO_FRAME_BASE_ADDR + x"00019800";
        end case;
      elsif (YOKO_DE = '1') then
        -- VFBC CMD LOGIC --
        if (wLine = 31) then
          if (wColumn = 636) then
            vfbc_cmd_data_i <= vfbc_cmd0;
            vfbc_cmd_write_i <= '1';
          elsif (wColumn = 637) then
            vfbc_cmd_data_i <= vfbc_cmd1;
            vfbc_cmd_write_i <= '1';
          elsif (wColumn = 638) then
            vfbc_cmd_data_i <= vfbc_cmd2;
            vfbc_cmd_write_i <= '1';
          elsif (wColumn = 639) then
            vfbc_cmd_data_i <= vfbc_cmd3;
            vfbc_cmd_write_i <= '1';
          else
            vfbc_cmd_data_i <= (others => '0');
            vfbc_cmd_write_i <= '0';
          end if;
        else
          vfbc_cmd_data_i <= (others => '0');
          vfbc_cmd_write_i <= '0';
        end if;
        -- WRITE LOGIC --
        if (((wColumn < 639) and (wLine > 0)) or ((wColumn < 640) and (wLine = 0))) then
          wColumn <= wColumn + 1;
          new_stripe <= '0';
        else
          if (wLine < 31) then
            wColumn <= (others => '0');
            wLine <= wLine + 1;
            new_stripe <= '0';
          else
            wColumn <= "0000000001";
            wLine <= (others => '0');
            new_stripe <= '1';
            frame_base_addr <= frame_base_addr - x"00000080";
          end if;
        end if;
        -- READ LOGIC --
        if (rLine > 0) then
          rLine <= rLine - 1;
        else
          rLine <= "11111";
          if (rColumn < 639) then
            rColumn <= rColumn + 1;
          else
            rColumn <= (others => '0');
          end if;
        end if;
      else
        new_stripe <= '0';
        vfbc_cmd_data_i <= (others => '0');
        vfbc_cmd_write_i <= '0';
      end if;
    end if;
  end process YOKO_COUNTERS_PROC;

  BUFFER_TOGGLE_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (new_stripe = '1') then
        buffer_toggle <= not buffer_toggle;
      end if;
    end if;
  end process BUFFER_TOGGLE_PROC;

  SWAP_BUFFERS_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (buffer_toggle = '0') then
        line_buffer_01_din <= YOKO_DI;
        line_buffer_01_line <= wLine;
        line_buffer_01_column <= wColumn;
        line_buffer_01_we <= '1';
        line_buffer_02_din <= zero;
        line_buffer_02_line <= rLine;
        line_buffer_02_column <= rColumn;
        line_buffer_02_we <= '0';
        pixel_dout <= line_buffer_02_dout;
      else
        line_buffer_01_din <= zero;
        line_buffer_01_line <= rLine;
        line_buffer_01_column <= rColumn;
        line_buffer_01_we <= '0';
        line_buffer_02_din <= YOKO_DI;
        line_buffer_02_line <= wLine;
        line_buffer_02_column <= wColumn;
        line_buffer_02_we <= '1';
        pixel_dout <= line_buffer_01_dout;
      end if;
    end if;
  end process SWAP_BUFFERS_PROC;

  --------------------------------
  -- VFBC Command Logic
  --------------------------------

  YOKO_VFBC_CMD_DATA <= vfbc_cmd_data_i;
  YOKO_VFBC_CMD_WRITE <= vfbc_cmd_write_i;

  vfbc_cmd0 <= x"00000080";
  vfbc_cmd1 <= '1' & frame_base_addr(30 downto 0);
  vfbc_cmd2 <= x"0000027F";
  vfbc_cmd3 <= x"00000A00";

  --------------------------------
  -- VFBC Write Logic
  --------------------------------

  YOKO_VFBC_WD_WRITE <= pixel_de;
  YOKO_VFBC_WD_DATA <= pixel_dout;

  YOKO_DE_DELAY_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      pixel_de <= pixel_delay_3;
      pixel_delay_3 <= pixel_delay_2;
      pixel_delay_2 <= pixel_delay_1;
      pixel_delay_1 <= YOKO_DE;
    end if;
  end process YOKO_DE_DELAY_PROC;

end behavioral;
