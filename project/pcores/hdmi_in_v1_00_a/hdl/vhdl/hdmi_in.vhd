library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

entity hdmi_in is
  port
  (
    TMDS           : in std_logic_vector(3 downto 0);
    TMDSB          : in std_logic_vector(3 downto 0);
    SW             : in std_logic_vector(3 downto 0);
    LED            : out std_logic;
    FB_SELECT      : out std_logic_vector(1 downto 0);
    LOCKED_N         : out std_logic;
    -- VFBC Command Signals
    VFBC_CMD_CLK : out std_logic;
	 VFBC_CMD_IDLE : in std_logic;
	 VFBC_CMD_RESET : out std_logic;
	 VFBC_CMD_DATA : out std_logic_vector (31 downto 0);
	 VFBC_CMD_WRITE : out std_logic;
	 VFBC_CMD_END : out std_logic;
	 VFBC_CMD_FULL : in std_logic;
	 VFBC_CMD_ALMOST_FULL : in std_logic;
	 -- VFBC Write Signals
	 VFBC_WD_CLK : out std_logic;
	 VFBC_WD_RESET : out std_logic;
	 VFBC_WD_FLUSH : out std_logic;
	 VFBC_WD_WRITE : out std_logic;
	 VFBC_WD_DATA : out std_logic_vector (15 downto 0);
	 VFBC_WD_DATA_BE : out std_logic_vector (1 downto 0);
	 VFBC_WD_END_BURST : out std_logic;
	 VFBC_WD_FULL : in std_logic;
	 VFBC_WD_ALMOST_FULL : in std_logic
  );

end entity hdmi_in;

architecture IMP of hdmi_in is

	COMPONENT dvi_decoder
	PORT(
		tmdsclk_p : IN std_logic;
		tmdsclk_n : IN std_logic;
		blue_p : IN std_logic;
		green_p : IN std_logic;
		red_p : IN std_logic;
		blue_n : IN std_logic;
		green_n : IN std_logic;
		red_n : IN std_logic;
		exrst : IN std_logic;          
		reset : OUT std_logic;
		pclk : OUT std_logic;
		pclkx2 : OUT std_logic;
		hsync : OUT std_logic;
		vsync : OUT std_logic;
		de : OUT std_logic;
		red : OUT std_logic_vector(7 downto 0);
		green : OUT std_logic_vector(7 downto 0);
		blue : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;
  
	COMPONENT yoko_vfbc_backend
	PORT(
	  YOKO_DI             : in std_logic_vector(15 downto 0);
	  YOKO_DE             : in std_logic;
	  YOKO_NEW_FRAME      : in std_logic;
	  YOKO_FB_SELECT      : in std_logic_vector(1 downto 0);
	  YOKO_CLK_I          : in std_logic;
	  YOKO_FRAME_BASE_ADDR: in std_logic_vector(31 downto 0);
	  YOKO_VFBC_CMD_DATA  : out std_logic_vector(31 downto 0);
	  YOKO_VFBC_CMD_WRITE : out std_logic;
	  YOKO_VFBC_WD_DATA   : out std_logic_vector(15 downto 0);
	  YOKO_VFBC_WD_WRITE  : out std_logic
	  );
	END COMPONENT;
  
  	COMPONENT tate_vfbc_backend
	PORT(
	  TATE_DI             : in std_logic_vector(15 downto 0);
	  TATE_DE             : in std_logic;
	  TATE_NEW_FRAME      : in std_logic;
	  TATE_FB_SELECT      : in std_logic_vector(1 downto 0);
	  TATE_CLK_I          : in std_logic;
	  TATE_VFBC_CMD_DATA  : out std_logic_vector(31 downto 0);
	  TATE_VFBC_CMD_WRITE : out std_logic;
	  TATE_VFBC_WD_DATA   : out std_logic_vector(15 downto 0);
	  TATE_VFBC_WD_WRITE  : out std_logic;
	  TATE_VFBC_WD_RESET  : out std_logic
	  );
	END COMPONENT;
	
	COMPONENT null_vfbc_backend
	PORT(
	  NULL_CLS            : in std_logic;
	  NULL_CLEARED        : out std_logic;
	  NULL_CLK_I          : in std_logic;
	  NULL_VFBC_CMD_DATA  : out std_logic_vector(31 downto 0);
	  NULL_VFBC_CMD_WRITE : out std_logic;
	  NULL_VFBC_WD_DATA   : out std_logic_vector(15 downto 0);
	  NULL_VFBC_WD_WRITE  : out std_logic;
	  NULL_VFBC_WD_RESET  : out std_logic
	);
	END COMPONENT;
	
--	COMPONENT pixel_filter
--	PORT(
--     R_I     : in std_logic_vector(7 downto 0);
--     G_I     : in std_logic_vector(7 downto 0);
--     B_I     : in std_logic_vector(7 downto 0);
--	  CLK_I   : in std_logic;
--	  DE_I    : in std_logic;
--     R_O     : out std_logic_vector(7 downto 0);
--     G_O     : out std_logic_vector(7 downto 0);
--     B_O     : out std_logic_vector(7 downto 0);
--	  CLK_O   : out std_logic;
--	  DE_O    : out std_logic;
--	  PXL_CNT : in std_logic_vector(3 downto 0);
--	  EN      : in std_logic
--	);
--	END COMPONENT;
	
  type FRAME_STATE_TYPE is (FRAME_INIT, FRAME_CLS,FRAME_FIND_POL, FRAME_WAIT_VSYNC, FRAME_DETECT, FRAME_SYNC, FRAME_WRITE);  
  type SCREEN_ORIENTATION_TYPE is (YOKO, TATE);
  type SCREEN_VMODE_TYPE is (CGA, VGA);

  signal pll_locked_n    : std_logic;
  signal pll_reset       : std_logic;
  signal soft_reset      : std_logic := '0'; 
  
  signal pxlclk        : std_logic;
  signal pxlclkx2      : std_logic;
  
  signal hsync     : std_logic;
  signal vsync     : std_logic;
  signal de        : std_logic;
  signal vfbc_de   : std_logic;
  
  signal red   : std_logic_vector(7 downto 0);
  signal green : std_logic_vector(7 downto 0);
  signal blue  : std_logic_vector(7 downto 0);
  signal red_reg   : std_logic_vector(7 downto 0);
  signal green_reg : std_logic_vector(7 downto 0);
  signal blue_reg  : std_logic_vector(7 downto 0);
  signal rouge : std_logic_vector(7 downto 0);
  signal vert  : std_logic_vector(7 downto 0);
  signal bleu  : std_logic_vector(7 downto 0);
  
  signal frame_state     : FRAME_STATE_TYPE := FRAME_INIT;
  signal frame_is_locked : std_logic;
  
  signal screen_orientation     : SCREEN_ORIENTATION_TYPE;
  signal screen_vmode           : SCREEN_VMODE_TYPE := VGA;
  signal orientation_sw         : std_logic := '0';
  signal orientation_sw_reg     : std_logic := '0';
  signal orientation_sw_change  : std_logic := '0';
  signal hOffset                : std_logic_vector(7 downto 0) := (others => '0');
  signal hOffset_reg            : std_logic_vector(7 downto 0) := (others => '0');
  signal hOffset_change         : std_logic := '0';
  signal vmode_sw               : std_logic := '0';
  signal screen_mode            : std_logic := '0';
  
  signal clear_screen           : std_logic := '0';
  signal screen_cleared         : std_logic := '0';
  
  signal hsync_pol     : std_logic := '0';
  signal vsync_pol     : std_logic := '0';
  
  signal hsync_reg            : std_logic := '0';
  signal vsync_reg            : std_logic := '0';
  signal de_reg               : std_logic := '0';

  signal new_frame     : std_logic;
  signal new_frame_cnt : std_logic_vector(7 downto 0) := (others => '0');
  signal line_end      : std_logic;
  signal frame_reset   : std_logic := '1';
  signal fb_selector   : std_logic_vector(1 downto 0) := "00";
  
  signal pxl_cnt  : std_logic_vector(15 downto 0) := (others => '0');
  signal line_cnt : std_logic_vector(15 downto 0) := (others => '0');
  signal p_cnt  : ieee.numeric_std.unsigned(3 downto 0) := (others => '0');
  
  signal write_en        : std_logic := '0';
  signal frame_width     : std_logic_vector(15 downto 0) := (others => '0');
  signal frame_height    : std_logic_vector(15 downto 0) := (others => '0');
  signal frame_base_addr : std_logic_vector(31 downto 0) := x"49000000";
    
  signal yoko_vfbc_cmd_data_i : std_logic_vector(31 downto 0) := (others => '0');
  signal yoko_vfbc_cmd_write_i : std_logic := '0';
  signal tate_vfbc_cmd_data_i : std_logic_vector(31 downto 0) := (others => '0');
  signal tate_vfbc_cmd_write_i : std_logic := '0';
  signal null_vfbc_cmd_data_i : std_logic_vector(31 downto 0) := (others => '0');
  signal null_vfbc_cmd_write_i : std_logic := '0';
  signal null_vfbc_cmd_reset_i : std_logic := '0';
  
  signal yoko_vfbc_wd_data_i : std_logic_vector(15 downto 0) := (others => '0');
  signal yoko_vfbc_wd_write_i : std_logic := '0';
  signal tate_vfbc_wd_data_i : std_logic_vector(15 downto 0) := (others => '0');
  signal tate_vfbc_wd_write_i : std_logic := '0';
  signal tate_vfbc_wd_reset_i : std_logic := '0';
  signal null_vfbc_wd_data_i : std_logic_vector(15 downto 0) := (others => '0');
  signal null_vfbc_wd_write_i : std_logic := '0';
  signal null_vfbc_wd_reset_i : std_logic := '0';
  
  signal pxl_data : std_logic_vector(15 downto 0);
  
  signal clk_pulse : std_logic := '0';
  
begin

Inst_yoko_vfbc_backend: yoko_vfbc_backend PORT MAP(
     YOKO_DI => pxl_data,
	  YOKO_DE => vfbc_de,           	  
	  YOKO_NEW_FRAME => new_frame,
	  YOKO_FB_SELECT => fb_selector,
     YOKO_CLK_I => pxlclk,
	  YOKO_FRAME_BASE_ADDR => frame_base_addr,
	  YOKO_VFBC_CMD_DATA => yoko_vfbc_cmd_data_i,
	  YOKO_VFBC_CMD_WRITE => yoko_vfbc_cmd_write_i,
	  YOKO_VFBC_WD_DATA => yoko_vfbc_wd_data_i,
	  YOKO_VFBC_WD_WRITE => yoko_vfbc_wd_write_i
   );
	
Inst_tate_vfbc_backend: tate_vfbc_backend PORT MAP(
     TATE_DI => pxl_data,
	  TATE_DE => vfbc_de,           	  
	  TATE_NEW_FRAME => new_frame,
	  TATE_FB_SELECT => fb_selector,
	  TATE_CLK_I => pxlclk,
	  TATE_VFBC_CMD_DATA => tate_vfbc_cmd_data_i,
	  TATE_VFBC_CMD_WRITE => tate_vfbc_cmd_write_i,
	  TATE_VFBC_WD_DATA => tate_vfbc_wd_data_i,
	  TATE_VFBC_WD_WRITE => tate_vfbc_wd_write_i,
	  TATE_VFBC_WD_RESET => tate_vfbc_wd_reset_i
   );

Inst_null_vfbc_backend: null_vfbc_backend PORT MAP(
     NULL_CLS => clear_screen,
	  NULL_CLEARED => screen_cleared,
	  NULL_CLK_I => pxlclk,
	  NULL_VFBC_CMD_DATA => null_vfbc_cmd_data_i,
	  NULL_VFBC_CMD_WRITE => null_vfbc_cmd_write_i,
	  NULL_VFBC_WD_DATA => null_vfbc_wd_data_i,
	  NULL_VFBC_WD_WRITE => null_vfbc_wd_write_i,
	  NULL_VFBC_WD_RESET => null_vfbc_wd_reset_i
   );

--Inst_pixel_filter: pixel_filter PORT MAP(
--     R_I => red,
--     G_I => green,
--     B_I => blue,
--	  CLK_I => pxlclk,
--	  DE_I => de,
--     R_O => vfbc_red,
--     G_O => vfbc_green,
--     B_O => vfbc_blue,
--	  CLK_O => vfbc_clk,
--	  DE_O => vfbc_de,
--	  PXL_CNT => p_cnt,
--	  EN => filter_en
--   );

Inst_dvi_decoder: dvi_decoder PORT MAP(
		tmdsclk_p => TMDS(3),
		tmdsclk_n => TMDSB(3),
		blue_p => TMDS(0),
		green_p => TMDS(1),
		red_p => TMDS(2),
		blue_n => TMDSB(0),
		green_n => TMDSB(1),
		red_n => TMDSB(2),
		exrst => pll_reset,
		reset => pll_locked_n,
		pclk => pxlclk,
		pclkx2 => pxlclkx2,
		hsync => hsync,
		vsync => vsync,
		de => de,
		red => red, 
		green => green,
		blue => blue
	);
 
  orientation_sw <= SW(0);
  vmode_sw <= SW(1);
  FB_SELECT <= fb_selector;
  LOCKED_N <= '0' when (frame_state = FRAME_WRITE) else
              '1';
  
  with SW(3 downto 2) select
  hOffset <= x"00" when "00", -- NAOMI
             x"08" when "01", -- CHIHIRO
             x"0B" when "10", -- NEOGEO
				 x"05" when "11", -- Windows
				 x"00" when others;
  
  frame_base_addr <= x"49001400" - (hOffset * x"0A00");

  FB_TOGGLE_PROC : process (pxlclk) is
  begin
    if rising_edge(pxlclk) then
      if (new_frame = '1') then
        if fb_selector = "00" then
          fb_selector <= "01";
        elsif fb_selector = "01" then
          fb_selector <= "10";
        elsif fb_selector = "10" then
          fb_selector <= "11";
	     elsif fb_selector = "11" then
          fb_selector <= "00";
        end if;
      end if;
    end if;
  end process FB_TOGGLE_PROC; 
  
  signal_delay_proc : process (pxlclk)
  begin
    if (rising_edge(pxlclk)) then
      de_reg <= de;
      orientation_sw_reg <= orientation_sw;
      vsync_reg <= vsync;
		hOffset_reg <= hOffset;
		red_reg <= red;
		green_reg <= green;
		blue_reg <= blue;
    end if;
  end process signal_delay_proc;
  
  --vfbc_de <= '0' when (frame_width = 720) and ((ieee.numeric_std.unsigned(pxl_cnt) mod 9) = 0) else
  vfbc_de <= '0' when (frame_width = 720) and p_cnt = 1 else
				 de;
  
  clear_screen <= '1' when (frame_state = FRAME_CLS) else
                  '0';  
  new_frame <= '1' when ((vsync_reg = not(vsync_pol)) and (vsync = vsync_pol)) else
               '0';
  line_end  <= '1' when ((de_reg = '1') and (de = '0'))else
               '0';
  orientation_sw_change <= '1' when (orientation_sw_reg /= orientation_sw) else
                           '0';
  hOffset_change <= '1' when (hOffset_reg /= hOffset) else
                           '0';									
  
  LED <= clk_pulse;
  
  pll_reset <= '1' when ((frame_state = FRAME_DETECT) and (new_frame = '1') and (write_en = '0')) else
               '0';

  --Next state logic for frame detect and write state machine
  next_state_proc : process (pxlclk, pll_locked_n)
  begin
    if (pll_locked_n = '1') then
      frame_state <= FRAME_INIT;
      new_frame_cnt <= (others => '0');
    elsif (rising_edge(pxlclk)) then
      if (orientation_sw_change = '1' or hOffset_change = '1') then
        frame_state <= FRAME_CLS;
      end if;
      case frame_state is
        when FRAME_INIT => -- LED 0100000
          frame_state <= FRAME_CLS;
        when FRAME_CLS =>
          if (screen_cleared = '1') then
            frame_state <= FRAME_FIND_POL;
          end if;
        when FRAME_FIND_POL => -- LED 0010000
          if (de = '1') then
            frame_state <= FRAME_WAIT_VSYNC;
          end if;
        when FRAME_WAIT_VSYNC => -- LED 0001000
          if (new_frame = '1') then
            frame_state <= FRAME_DETECT;
          end if;
        when FRAME_DETECT => -- LED 0000100
          if (new_frame = '1') then
            if (write_en = '1') then
              frame_state <= FRAME_SYNC;
            end if;
          end if;
        when FRAME_SYNC => -- LED 0000010
          if (new_frame = '1') then
            frame_state <= FRAME_WRITE;
          end if;
        when FRAME_WRITE => -- LED 0000001
          if (new_frame = '1') then
            if (new_frame_cnt < 59) then
              new_frame_cnt <= new_frame_cnt + 1;
            else
              new_frame_cnt <= (others => '0');
              clk_pulse <= not(clk_pulse);
            end if;
          end if;
        when others=> --Should be unreachable
          frame_state <= FRAME_INIT;
      end case;
    end if;
  end process next_state_proc;

 select_vfbc_backend : process (pxlclk) is
  begin
    if (rising_edge(pxlclk)) then
      if (frame_state = FRAME_WRITE) then
 	     VFBC_CMD_RESET <= '0';
        if (screen_orientation = YOKO) then
		    --LED <= "0000001";
          VFBC_CMD_DATA  <= yoko_vfbc_cmd_data_i;
          VFBC_CMD_WRITE <= yoko_vfbc_cmd_write_i;
          VFBC_WD_DATA   <= yoko_vfbc_wd_data_i;
          VFBC_WD_WRITE  <= yoko_vfbc_wd_write_i;
          VFBC_WD_RESET  <= '0';
        else
		    --LED <= "0000010";
          VFBC_CMD_DATA  <= tate_vfbc_cmd_data_i;
          VFBC_CMD_WRITE <= tate_vfbc_cmd_write_i;
          VFBC_WD_DATA   <= tate_vfbc_wd_data_i;
          VFBC_WD_WRITE  <= tate_vfbc_wd_write_i;
          VFBC_WD_RESET  <= tate_vfbc_wd_reset_i;
		  end if;
		else
		  --LED <= "0000100";
		  VFBC_CMD_DATA  <= null_vfbc_cmd_data_i;
        VFBC_CMD_WRITE <= null_vfbc_cmd_write_i;
        VFBC_WD_DATA   <= null_vfbc_wd_data_i;
        VFBC_WD_WRITE  <= null_vfbc_wd_write_i;
	     VFBC_WD_RESET  <= null_vfbc_wd_reset_i;
		end if;
    end if;
  end process select_vfbc_backend;
  
  screen_orientation <= TATE when (orientation_sw = '0') else
                        YOKO;
							
  screen_vmode <= VGA when (vmode_sw = '0') else
                  CGA;
  write_en <= '1' when (frame_height = 480) else
              '0';

  find_sync_pol_proc : process (pxlclk)
  begin
    if (rising_edge(pxlclk)) then
      if (frame_state = FRAME_INIT) then
        vsync_pol <= '0';
        hsync_pol <= '0';
      elsif (frame_state = FRAME_FIND_POL) then
        if (de = '1') then
          vsync_pol <= not(vsync);
          hsync_pol <= not(hsync);
        end if;
      end if;
    end if;
  end process find_sync_pol_proc;
    
  pxl_cnt_proc : process (pxlclk)
  begin
    if (rising_edge(pxlclk)) then
		if (new_frame = '1') then
		  frame_height <= line_cnt;
		  pxl_cnt <= (others => '0');
        line_cnt <= (others => '0');
		  p_cnt <= (others => '0');
		else
        if (de = '1') then
          pxl_cnt <= pxl_cnt + 1;
			 if (p_cnt < 9) then 
			   p_cnt <= p_cnt + 1;
			 else
			   p_cnt <= "0001";
			 end if;
        elsif (line_end = '1') then
		    frame_width <= pxl_cnt;
          pxl_cnt <= (others => '0');
          line_cnt <= line_cnt + 1;
			 p_cnt <= (others => '0');
        end if;
      end if;  
    end if;
  end process pxl_cnt_proc;

  --------------------------------
  -- VFBC Command Logic
  --------------------------------

  VFBC_CMD_CLK <= pxlclk;
  VFBC_CMD_END <= '0'; -- never ends

  VFBC_WD_CLK <= pxlclkx2;
  VFBC_WD_FLUSH <= '0';
  VFBC_WD_DATA_BE <= (others => '1');
  VFBC_WD_END_BURST <= '0';

--  rouge <= std_logic_vector(resize(x"10" + shift_right(x"010B" * ieee.numeric_std.unsigned(red), 10) + shift_right(x"0081" * ieee.numeric_std.unsigned(green), 8)  + shift_right(x"0019" * ieee.numeric_std.unsigned(blue), 8), 8)) when (frame_width = 720) else
  rouge <= std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(red) + (10 - p_cnt)*ieee.numeric_std.unsigned(red_reg)) / 9, 8)) when (frame_width = 720) else
              red;
--  vert  <= std_logic_vector(resize(x"80" - shift_right(x"0026" * ieee.numeric_std.unsigned(red), 8)  - shift_right(x"0095" * ieee.numeric_std.unsigned(green), 9)  + shift_right(x"0707" * ieee.numeric_std.unsigned(blue), 12), 8)) when (frame_width = 720) else
  vert <= std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(green) + (10 - p_cnt)*ieee.numeric_std.unsigned(green_reg)) / 9, 8)) when (frame_width = 720) else
           green;
--  bleu  <= std_logic_vector(resize(x"80" + shift_right(x"0707" * ieee.numeric_std.unsigned(red), 12) - shift_right(x"0BC5" * ieee.numeric_std.unsigned(green), 11) - shift_right(x"1249" * ieee.numeric_std.unsigned(blue), 16), 8)) when (frame_width = 720) else
  bleu <= std_logic_vector(resize(((p_cnt - 1)*ieee.numeric_std.unsigned(blue) + (10 - p_cnt)*ieee.numeric_std.unsigned(blue_reg)) / 9, 8)) when (frame_width = 720) else
           blue;
  
  pxl_data <= (others => '0') when ((screen_vmode = CGA) and (line_cnt(0) = '1')) else
              vert(4 downto 2) & rouge(7 downto 3) &  bleu(7 downto 3) & vert(7 downto 5);
  
end IMP;
