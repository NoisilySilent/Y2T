library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity mux_32x5x16 is
  port
  (
    sel   : in  std_logic_vector(31 downto 0);
    d_in  : in  std_logic_vector(511 downto 0);
    d_out : out std_logic_vector(15 downto 0);
    clk   : in  std_logic
  );
end entity mux_32x5x16;

architecture behavioral of mux_32x5x16 is
begin

  MUX_PROC : process (clk) is
  begin
    if (rising_edge(clk)) then
      case (sel) is
        when x"00000001" => d_out <= d_in(15 downto 0);
        when x"00000002" => d_out <= d_in(31 downto 16);
        when x"00000004" => d_out <= d_in(47 downto 32);
        when x"00000008" => d_out <= d_in(63 downto 48);
        when x"00000010" => d_out <= d_in(79 downto 64);
        when x"00000020" => d_out <= d_in(95 downto 80);
        when x"00000040" => d_out <= d_in(111 downto 96);
        when x"00000080" => d_out <= d_in(127 downto 112);
        when x"00000100" => d_out <= d_in(143 downto 128);
        when x"00000200" => d_out <= d_in(159 downto 144);
        when x"00000400" => d_out <= d_in(175 downto 160);
        when x"00000800" => d_out <= d_in(191 downto 176);
        when x"00001000" => d_out <= d_in(207 downto 192);
        when x"00002000" => d_out <= d_in(223 downto 208);
        when x"00004000" => d_out <= d_in(239 downto 224);
        when x"00008000" => d_out <= d_in(255 downto 240);
        when x"00010000" => d_out <= d_in(271 downto 256);
        when x"00020000" => d_out <= d_in(287 downto 272);
        when x"00040000" => d_out <= d_in(303 downto 288);
        when x"00080000" => d_out <= d_in(319 downto 304);
        when x"00100000" => d_out <= d_in(335 downto 320);
        when x"00200000" => d_out <= d_in(351 downto 336);
        when x"00400000" => d_out <= d_in(367 downto 352);
        when x"00800000" => d_out <= d_in(383 downto 368);
        when x"01000000" => d_out <= d_in(399 downto 384);
        when x"02000000" => d_out <= d_in(415 downto 400);
        when x"04000000" => d_out <= d_in(431 downto 416);
        when x"08000000" => d_out <= d_in(447 downto 432);
        when x"10000000" => d_out <= d_in(463 downto 448);
        when x"20000000" => d_out <= d_in(479 downto 464);
        when x"40000000" => d_out <= d_in(495 downto 480);
        when x"80000000" => d_out <= d_in(511 downto 496);
        when others => d_out <= (others => '0');
      end case;
    end if;
  end process MUX_PROC;
  
end behavioral;
