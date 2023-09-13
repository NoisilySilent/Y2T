library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity demux_5x32 is
  port
  (
    d_in  : in  std_logic_vector(4 downto 0);
	d_out : out std_logic_vector(31 downto 0);
	clk   : in  std_logic
  );
end entity demux_5x32;

architecture behavioral of demux_5x32 is
begin

  DEMUX_PROC : process (clk) is
  begin
    if (rising_edge(clk)) then
	  case (d_in) is
	    when "00000" => d_out <= x"00000001";
		when "00001" => d_out <= x"00000002";
		when "00010" => d_out <= x"00000004";
		when "00011" => d_out <= x"00000008";
		when "00100" => d_out <= x"00000010";
		when "00101" => d_out <= x"00000020";
		when "00110" => d_out <= x"00000040";
		when "00111" => d_out <= x"00000080";
		when "01000" => d_out <= x"00000100";
		when "01001" => d_out <= x"00000200";
		when "01010" => d_out <= x"00000400";
		when "01011" => d_out <= x"00000800";
		when "01100" => d_out <= x"00001000";
		when "01101" => d_out <= x"00002000";
		when "01110" => d_out <= x"00004000";
		when "01111" => d_out <= x"00008000";
		when "10000" => d_out <= x"00010000";
		when "10001" => d_out <= x"00020000";
		when "10010" => d_out <= x"00040000";
		when "10011" => d_out <= x"00080000";
		when "10100" => d_out <= x"00100000";
		when "10101" => d_out <= x"00200000";
		when "10110" => d_out <= x"00400000";
		when "10111" => d_out <= x"00800000";
		when "11000" => d_out <= x"01000000";
		when "11001" => d_out <= x"02000000";
		when "11010" => d_out <= x"04000000";
		when "11011" => d_out <= x"08000000";
		when "11100" => d_out <= x"10000000";
		when "11101" => d_out <= x"20000000";
		when "11110" => d_out <= x"40000000";
		when "11111" => d_out <= x"80000000";
		when others => d_out <= x"00000000";
	  end case;
	end if;
  end process DEMUX_PROC;
  
end behavioral;