--
--    0     hsr           hbpr                hfpr         htr
--    | Sync |--------------|-------------------|------------
--    |------|  Back Porch  |   active video    | Front Porch
--	 														
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity hdmi_out is
  generic (
    FRAME_BASE_ADDR : std_logic_vector(31 downto 0) := x"00000000";
    LINE_STRIDE : std_logic_vector(23 downto 0) := x"000000";
    RESOLUTION_SELECT : integer := 1);
  port (
    --   LOCKED_I : in std_logic;
    -- ports pour hdmi_in
    FB_SELECT : in std_logic_vector(1 downto 0);
    RST : in std_logic;
    LED : out std_logic;
    -- HDMI ports
    RPI_TMDS : in std_logic_vector(3 downto 0);
    RPI_TMDSB : in std_logic_vector(3 downto 0);
    TMDS : out std_logic_vector(3 downto 0);
    TMDSB : out std_logic_vector(3 downto 0);
    -- VFBC Cmd Ports
    VFBC_CMD_CLK : out std_logic;
    VFBC_CMD_IDLE : in std_logic;
    VFBC_CMD_RESET : out std_logic;
    VFBC_CMD_DATA : out std_logic_vector (31 downto 0);
    VFBC_CMD_WRITE : out std_logic;
    VFBC_CMD_END : out std_logic;
    VFBC_CMD_FULL : in std_logic;
    VFBC_CMD_ALMOST_FULL : in std_logic;
    -- VFBC Read Ports
    VFBC_RD_CLK : out std_logic;
    VFBC_RD_RESET : out std_logic;
    VFBC_RD_FLUSH : out std_logic;
    VFBC_RD_READ : out std_logic;
    VFBC_RD_END_BURST : out std_logic;
    VFBC_RD_DATA : in std_logic_vector (15 downto 0);
    VFBC_RD_EMPTY : in std_logic;
    VFBC_RD_ALMOST_EMPTY : in std_logic);

  attribute MAX_FANOUT : string;
  attribute SIGIS : string;

end entity hdmi_out;

architecture IMP of hdmi_out is

  component dvi_decoder
    port (
      tmdsclk_p : in std_logic;
      tmdsclk_n : in std_logic;
      blue_p : in std_logic;
      green_p : in std_logic;
      red_p : in std_logic;
      blue_n : in std_logic;
      green_n : in std_logic;
      red_n : in std_logic;
      exrst : in std_logic;
      reset : out std_logic;
      pll_lckd : out std_logic;
      pclk : out std_logic;
      pclkx2 : out std_logic;
      pclkx10 : out std_logic;
      hsync : out std_logic;
      vsync : out std_logic;
      de : out std_logic;
      red : out std_logic_vector(7 downto 0);
      green : out std_logic_vector(7 downto 0);
      blue : out std_logic_vector(7 downto 0)
    );
  end component;

  component dvi_out_native
    port (
      reset : in std_logic;
      pll_lckd : in std_logic;
      clkin : in std_logic;
      clkx2in : in std_logic;
      clkx10in : in std_logic;
      blue_din : in std_logic_vector(7 downto 0);
      green_din : in std_logic_vector(7 downto 0);
      red_din : in std_logic_vector(7 downto 0);
      hsync : in std_logic;
      vsync : in std_logic;
      de : in std_logic;
      TMDS : out std_logic_vector(3 downto 0);
      TMDSB : out std_logic_vector(3 downto 0)
    );
  end component;

  constant vfbc_cmd3 : std_logic_vector(31 downto 0) := "0000000" & LINE_STRIDE(23 downto 7) & "00000000"; --The line stride must be 128 byte alligned and be in bytes (2x input)

  signal vfbc_cmd0 : std_logic_vector(31 downto 0);
  signal vfbc_cmd1 : std_logic_vector(31 downto 0);
  signal vfbc_cmd2 : std_logic_vector(31 downto 0);

  signal polarity : std_logic;

  signal pll_reset : std_logic;
  signal pll_locked : std_logic;
  signal pll_locked_n : std_logic;
  signal pxlclk : std_logic;
  signal pxlclkx2 : std_logic;
  signal pxlclkx10 : std_logic;
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal de : std_logic;
  signal vsync_reg : std_logic;
  signal red : std_logic_vector(7 downto 0);
  signal green : std_logic_vector(7 downto 0);
  signal blue : std_logic_vector(7 downto 0);

  signal enabled : std_logic := '1';

  signal vfbc_cmd_data_i : std_logic_vector(31 downto 0);
  signal vfbc_cmd_write_i : std_logic;
  signal vfbc_rd_reset_i : std_logic;

  signal hcnt : std_logic_vector(15 downto 0) := (others => '0');
  signal vcnt : std_logic_vector(15 downto 0) := (others => '0');

  signal video_data_i : std_logic_vector(23 downto 0);

  signal unused_dout : std_logic_vector(15 downto 0);
  signal line_buffer_dout : std_logic_vector(15 downto 0);
  signal line_buffer_waddr : std_logic_vector(9 downto 0);
  signal line_buffer_raddr : std_logic_vector(9 downto 0);

  signal frame_buffer_out : std_logic_vector(1 downto 0);
  signal frame_buffer_in : std_logic_vector(1 downto 0);

  signal new_frame : std_logic := '0';
  signal vfbc_cmd_cnt : std_logic_vector(7 downto 0) := (others => '0');
  signal vfbc_rd_rst_cnt : std_logic_vector(7 downto 0) := (others => '0');

  signal clk_led : std_logic := '0';

begin

  vfbc_cmd0 <= x"00000A00";
  vfbc_cmd2 <= x"000002CF";

  polarity <= '1';
  new_frame <= '1' when ((vsync = polarity) and (vsync_reg = not(polarity))) else
               '0';

  signal_delay_proc : process (pxlclk)
  begin
    if (rising_edge(pxlclk)) then
      vsync_reg <= vsync;
    end if;
  end process signal_delay_proc;

  frame_buffer_in <= FB_SELECT;

  with frame_buffer_out select
    vfbc_cmd1 <= x"49000000" when "00",
                 x"491C2000" when "01",
                 x"49384000" when "10",
                 x"49546000" when "11";

  --HV_CNT_PROC : horizontal and vertical counter
  HV_CNT_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if new_frame = '1' then
        hcnt <= (others => '0');
        vcnt <= (others => '0');
        case frame_buffer_in is
          when "00" => frame_buffer_out <= "10";
          when "01" => frame_buffer_out <= "11";
          when "10" => frame_buffer_out <= "00";
          when "11" => frame_buffer_out <= "01";
          when others => frame_buffer_out <= "11";
        end case;
      elsif de = '1' then
        if (hcnt < 1279) then
          hcnt <= hcnt + 1;
        else
          hcnt <= (others => '0');
          vcnt <= vcnt + 1;
        end if;
      end if;
    end if;
  end process HV_CNT_PROC;

  video_data_i <= (others => '0') when RST = '1' else
                  line_buffer_dout(7 downto 3) & "000" & line_buffer_dout(2 downto 0) & line_buffer_dout(15 downto 13) & "00" & line_buffer_dout(12 downto 8) & "000";
  --hcnt(15 downto 11) & "000" & hcnt(10 downto 8) & hcnt(7 downto 5) & "00" & hcnt(4 downto 0) & "000";

  --Instantiate TMDS decoder for input clocks
  Inst_dvi_decoder : dvi_decoder port map(
    tmdsclk_p => RPI_TMDS(3),
    tmdsclk_n => RPI_TMDSB(3),
    blue_p => RPI_TMDS(0),
    green_p => RPI_TMDS(1),
    red_p => RPI_TMDS(2),
    blue_n => RPI_TMDSB(0),
    green_n => RPI_TMDSB(1),
    red_n => RPI_TMDSB(2),
    exrst => pll_reset,
    reset => pll_locked_n,
    pll_lckd => pll_locked,
    pclk => pxlclk,
    pclkx2 => pxlclkx2,
    pclkx10 => pxlclkx10,
    hsync => hsync,
    vsync => vsync,
    de => de,
    red => red,
    green => green,
    blue => blue
  );

  --Instantiate TMDS encoder
  Inst_dvi_out_native : dvi_out_native port map(
    reset => pll_locked_n,
    pll_lckd => pll_locked,
    clkin => pxlclk,
    clkx2in => pxlclkx2,
    clkx10in => pxlclkx10,
    blue_din => video_data_i(23 downto 16),
    green_din => video_data_i(15 downto 8),
    red_din => video_data_i(7 downto 0),
    hsync => hsync,
    vsync => vsync,
    de => de,
    TMDS => TMDS,
    TMDSB => TMDSB
  );

  --------------------------------
  -- VFBC Command Logic
  --------------------------------

  VFBC_CMD_CLK <= pxlclk;
  VFBC_CMD_RESET <= '1' when pll_locked = '0' else
                    '0'; -- reset at the very beginning
  VFBC_CMD_DATA <= vfbc_cmd_data_i;
  VFBC_CMD_WRITE <= vfbc_cmd_write_i;
  VFBC_CMD_END <= '0'; -- never ends

  -- Feed command into VFBC Cmd Port at the beginning of each frame
  VFBC_FEED_CMD_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (new_frame = '1') then
        vfbc_cmd_data_i <= vfbc_cmd0;
        vfbc_cmd_write_i <= '1';
        vfbc_cmd_cnt <= vfbc_cmd_cnt + 1;
      elsif vfbc_cmd_cnt = 1 then
        vfbc_cmd_data_i <= vfbc_cmd1;
        vfbc_cmd_write_i <= '1';
        vfbc_cmd_cnt <= vfbc_cmd_cnt + 1;
      elsif vfbc_cmd_cnt = 2 then
        vfbc_cmd_data_i <= vfbc_cmd2;
        vfbc_cmd_write_i <= '1';
        vfbc_cmd_cnt <= vfbc_cmd_cnt + 1;
      elsif vfbc_cmd_cnt = 3 then
        vfbc_cmd_data_i <= vfbc_cmd3;
        vfbc_cmd_write_i <= '1';
        vfbc_cmd_cnt <= vfbc_cmd_cnt + 1;
      else
        vfbc_cmd_data_i <= (others => '0');
        vfbc_cmd_write_i <= '0';
        vfbc_cmd_cnt <= (others => '0');
      end if;
    end if;
  end process VFBC_FEED_CMD_PROC;

  --------------------------------
  -- VFBC Read Logic
  --------------------------------
  VFBC_RD_CLK <= pxlclk;
  VFBC_RD_RESET <= vfbc_rd_reset_i;
  VFBC_RD_FLUSH <= '0';
  VFBC_RD_READ <= de;
  --TODO: allow non 128 byte alligned parameters by implementing Burst stop logic
  VFBC_RD_END_BURST <= '0';

  -- Reset VFBC Read Port at the beginning of each frame
  VFBC_READ_DATA_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if new_frame = '1' then
        vfbc_rd_reset_i <= '1';
        vfbc_rd_rst_cnt <= (others => '0');
      elsif vfbc_rd_rst_cnt < 10 then
        vfbc_rd_reset_i <= '1';
        vfbc_rd_rst_cnt <= vfbc_rd_rst_cnt + 1;
      else
        vfbc_rd_reset_i <= '0';
      end if;
    end if;
  end process VFBC_READ_DATA_PROC;

  VFBC_LINE_BUFFER_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (de = '1') then
        if (hcnt(0) = '1') then
          line_buffer_waddr <= line_buffer_waddr + 1;
        end if;
        if (hcnt = 639) then
          line_buffer_raddr <= (others => '0');
        elsif (hcnt > 639) then
          line_buffer_raddr <= line_buffer_raddr + 1;
        else
          line_buffer_raddr <= (others => '1');
        end if;
      else
        line_buffer_waddr <= (others => '0');
      end if;
    end if;
  end process VFBC_LINE_BUFFER_PROC;

  -- Instantiate BRAM Line Buffer
  BRAM_640P_LINE_BUFFER : BRAM_TDP_MACRO
  generic map(
    BRAM_SIZE => "18Kb", -- Target BRAM, "9Kb" or "18Kb" 
    DEVICE => "SPARTAN6", -- Target Device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
    DOA_REG => 0, -- Optional port A output register (0 or 1)
    DOB_REG => 0, -- Optional port B output register (0 or 1)
    INIT_A => X"000000000", -- Initial values on A output port
    INIT_B => X"000000000", -- Initial values on B output port
    INIT_FILE => "NONE",
    READ_WIDTH_A => 16, -- Valid values are 1-36 
    READ_WIDTH_B => 16, -- Valid values are 1-36
    SIM_COLLISION_CHECK => "ALL", -- Collision check enable "ALL", "WARNING_ONLY", 
    -- "GENERATE_X_ONLY" or "NONE" 
    SRVAL_A => X"000000000", -- Set/Reset value for A port output
    SRVAL_B => X"000000000", -- Set/Reset value for B port output
    WRITE_MODE_A => "WRITE_FIRST", -- "WRITE_FIRST", "READ_FIRST" or "NO_CHANGE" 
    WRITE_MODE_B => "WRITE_FIRST", -- "WRITE_FIRST", "READ_FIRST" or "NO_CHANGE" 
    WRITE_WIDTH_A => 16, -- Valid values are 1-36
    WRITE_WIDTH_B => 16, -- Valid values are 1-36
    -- The following INIT_xx declarations specify the initial contents of the RAM
    INIT_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_07 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_08 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_09 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0A => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0B => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0C => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0D => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0E => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_0F => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_10 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_11 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_12 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_13 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_14 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_15 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_16 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_17 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_18 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_19 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1A => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1B => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1C => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1D => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1E => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_1F => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_20 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_21 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_22 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_23 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_24 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_25 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_26 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_27 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_28 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_29 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2A => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2B => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2C => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2D => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2E => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_2F => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_30 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_31 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_32 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_33 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_34 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_35 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_36 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_37 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_38 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_39 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3A => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3B => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3C => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3D => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3E => X"0000000000000000000000000000000000000000000000000000000000000000",
    INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
    INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000")
  port map(
    DOA => unused_dout, -- Output port-A data
    DOB => line_buffer_dout, -- Output port-B data
    ADDRA => line_buffer_waddr, -- Input port-A address
    ADDRB => line_buffer_raddr, -- Input port-B address
    CLKA => pxlclk, -- Input port-A clock
    CLKB => pxlclk, -- Input port-B clock
    DIA => VFBC_RD_DATA, -- Input port-A data
    DIB => x"0000", -- Input port-B data
    ENA => de, -- Input port-A enable
    ENB => de, -- Input port-B enable
    REGCEA => '0', -- Input port-A output register enable
    REGCEB => '0', -- Input port-B output register enable
    RSTA => '0', -- Input port-A reset
    RSTB => '0', -- Input port-B reset
    WEA => "11", -- Input port-A write enable
    WEB => "00" -- Input port-B write enable
  );

end IMP;
