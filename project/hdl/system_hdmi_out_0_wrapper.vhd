-------------------------------------------------------------------------------
-- system_hdmi_out_0_wrapper.vhd
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library hdmi_out_v1_00_a;
use hdmi_out_v1_00_a.all;

entity system_hdmi_out_0_wrapper is
  port (
    FB_SELECT : in std_logic_vector(1 downto 0);
    RST : in std_logic;
    LED : out std_logic;
    RPI_TMDS : in std_logic_vector(3 downto 0);
    RPI_TMDSB : in std_logic_vector(3 downto 0);
    TMDS : out std_logic_vector(3 downto 0);
    TMDSB : out std_logic_vector(3 downto 0);
    VFBC_CMD_CLK : out std_logic;
    VFBC_CMD_RESET : out std_logic;
    VFBC_CMD_DATA : out std_logic_vector(31 downto 0);
    VFBC_CMD_WRITE : out std_logic;
    VFBC_CMD_END : out std_logic;
    VFBC_CMD_FULL : in std_logic;
    VFBC_CMD_ALMOST_FULL : in std_logic;
    VFBC_CMD_IDLE : in std_logic;
    VFBC_RD_CLK : out std_logic;
    VFBC_RD_RESET : out std_logic;
    VFBC_RD_READ : out std_logic;
    VFBC_RD_END_BURST : out std_logic;
    VFBC_RD_FLUSH : out std_logic;
    VFBC_RD_DATA : in std_logic_vector(15 downto 0);
    VFBC_RD_EMPTY : in std_logic;
    VFBC_RD_ALMOST_EMPTY : in std_logic
  );
end system_hdmi_out_0_wrapper;

architecture STRUCTURE of system_hdmi_out_0_wrapper is

  component hdmi_out is
    generic (
      FRAME_BASE_ADDR : std_logic_vector;
      RESOLUTION_SELECT : integer;
      LINE_STRIDE : std_logic_vector
    );
    port (
      FB_SELECT : in std_logic_vector(1 downto 0);
      RST : in std_logic;
      LED : out std_logic;
      RPI_TMDS : in std_logic_vector(3 downto 0);
      RPI_TMDSB : in std_logic_vector(3 downto 0);
      TMDS : out std_logic_vector(3 downto 0);
      TMDSB : out std_logic_vector(3 downto 0);
      VFBC_CMD_CLK : out std_logic;
      VFBC_CMD_RESET : out std_logic;
      VFBC_CMD_DATA : out std_logic_vector(31 downto 0);
      VFBC_CMD_WRITE : out std_logic;
      VFBC_CMD_END : out std_logic;
      VFBC_CMD_FULL : in std_logic;
      VFBC_CMD_ALMOST_FULL : in std_logic;
      VFBC_CMD_IDLE : in std_logic;
      VFBC_RD_CLK : out std_logic;
      VFBC_RD_RESET : out std_logic;
      VFBC_RD_READ : out std_logic;
      VFBC_RD_END_BURST : out std_logic;
      VFBC_RD_FLUSH : out std_logic;
      VFBC_RD_DATA : in std_logic_vector(15 downto 0);
      VFBC_RD_EMPTY : in std_logic;
      VFBC_RD_ALMOST_EMPTY : in std_logic
    );
  end component;

begin

  hdmi_out_0 : hdmi_out
    generic map (
      FRAME_BASE_ADDR => X"D1000000",
      RESOLUTION_SELECT => 3,
      LINE_STRIDE => X"000500"
    )
    port map (
      FB_SELECT => FB_SELECT,
      RST => RST,
      LED => LED,
      RPI_TMDS => RPI_TMDS,
      RPI_TMDSB => RPI_TMDSB,
      TMDS => TMDS,
      TMDSB => TMDSB,
      VFBC_CMD_CLK => VFBC_CMD_CLK,
      VFBC_CMD_RESET => VFBC_CMD_RESET,
      VFBC_CMD_DATA => VFBC_CMD_DATA,
      VFBC_CMD_WRITE => VFBC_CMD_WRITE,
      VFBC_CMD_END => VFBC_CMD_END,
      VFBC_CMD_FULL => VFBC_CMD_FULL,
      VFBC_CMD_ALMOST_FULL => VFBC_CMD_ALMOST_FULL,
      VFBC_CMD_IDLE => VFBC_CMD_IDLE,
      VFBC_RD_CLK => VFBC_RD_CLK,
      VFBC_RD_RESET => VFBC_RD_RESET,
      VFBC_RD_READ => VFBC_RD_READ,
      VFBC_RD_END_BURST => VFBC_RD_END_BURST,
      VFBC_RD_FLUSH => VFBC_RD_FLUSH,
      VFBC_RD_DATA => VFBC_RD_DATA,
      VFBC_RD_EMPTY => VFBC_RD_EMPTY,
      VFBC_RD_ALMOST_EMPTY => VFBC_RD_ALMOST_EMPTY
    );

end architecture STRUCTURE;

