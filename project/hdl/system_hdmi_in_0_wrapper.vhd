-------------------------------------------------------------------------------
-- system_hdmi_in_0_wrapper.vhd
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

library hdmi_in_v1_00_a;
use hdmi_in_v1_00_a.all;

entity system_hdmi_in_0_wrapper is
  port (
    TMDS : in std_logic_vector(3 downto 0);
    TMDSB : in std_logic_vector(3 downto 0);
    SW : in std_logic_vector(3 downto 0);
    LED : out std_logic;
    FB_SELECT : out std_logic_vector(1 downto 0);
    LOCKED_N : out std_logic;
    VFBC_CMD_CLK : out std_logic;
    VFBC_CMD_RESET : out std_logic;
    VFBC_CMD_DATA : out std_logic_vector(31 downto 0);
    VFBC_CMD_WRITE : out std_logic;
    VFBC_CMD_END : out std_logic;
    VFBC_CMD_FULL : in std_logic;
    VFBC_CMD_ALMOST_FULL : in std_logic;
    VFBC_CMD_IDLE : in std_logic;
    VFBC_WD_CLK : out std_logic;
    VFBC_WD_RESET : out std_logic;
    VFBC_WD_WRITE : out std_logic;
    VFBC_WD_END_BURST : out std_logic;
    VFBC_WD_FLUSH : out std_logic;
    VFBC_WD_DATA : out std_logic_vector(15 downto 0);
    VFBC_WD_DATA_BE : out std_logic_vector(1 downto 0);
    VFBC_WD_FULL : in std_logic;
    VFBC_WD_ALMOST_FULL : in std_logic
  );
end system_hdmi_in_0_wrapper;

architecture STRUCTURE of system_hdmi_in_0_wrapper is

  component hdmi_in is
    port (
      TMDS : in std_logic_vector(3 downto 0);
      TMDSB : in std_logic_vector(3 downto 0);
      SW : in std_logic_vector(3 downto 0);
      LED : out std_logic;
      FB_SELECT : out std_logic_vector(1 downto 0);
      LOCKED_N : out std_logic;
      VFBC_CMD_CLK : out std_logic;
      VFBC_CMD_RESET : out std_logic;
      VFBC_CMD_DATA : out std_logic_vector(31 downto 0);
      VFBC_CMD_WRITE : out std_logic;
      VFBC_CMD_END : out std_logic;
      VFBC_CMD_FULL : in std_logic;
      VFBC_CMD_ALMOST_FULL : in std_logic;
      VFBC_CMD_IDLE : in std_logic;
      VFBC_WD_CLK : out std_logic;
      VFBC_WD_RESET : out std_logic;
      VFBC_WD_WRITE : out std_logic;
      VFBC_WD_END_BURST : out std_logic;
      VFBC_WD_FLUSH : out std_logic;
      VFBC_WD_DATA : out std_logic_vector(15 downto 0);
      VFBC_WD_DATA_BE : out std_logic_vector(1 downto 0);
      VFBC_WD_FULL : in std_logic;
      VFBC_WD_ALMOST_FULL : in std_logic
    );
  end component;

begin

  hdmi_in_0 : hdmi_in
    port map (
      TMDS => TMDS,
      TMDSB => TMDSB,
      SW => SW,
      LED => LED,
      FB_SELECT => FB_SELECT,
      LOCKED_N => LOCKED_N,
      VFBC_CMD_CLK => VFBC_CMD_CLK,
      VFBC_CMD_RESET => VFBC_CMD_RESET,
      VFBC_CMD_DATA => VFBC_CMD_DATA,
      VFBC_CMD_WRITE => VFBC_CMD_WRITE,
      VFBC_CMD_END => VFBC_CMD_END,
      VFBC_CMD_FULL => VFBC_CMD_FULL,
      VFBC_CMD_ALMOST_FULL => VFBC_CMD_ALMOST_FULL,
      VFBC_CMD_IDLE => VFBC_CMD_IDLE,
      VFBC_WD_CLK => VFBC_WD_CLK,
      VFBC_WD_RESET => VFBC_WD_RESET,
      VFBC_WD_WRITE => VFBC_WD_WRITE,
      VFBC_WD_END_BURST => VFBC_WD_END_BURST,
      VFBC_WD_FLUSH => VFBC_WD_FLUSH,
      VFBC_WD_DATA => VFBC_WD_DATA,
      VFBC_WD_DATA_BE => VFBC_WD_DATA_BE,
      VFBC_WD_FULL => VFBC_WD_FULL,
      VFBC_WD_ALMOST_FULL => VFBC_WD_ALMOST_FULL
    );

end architecture STRUCTURE;

