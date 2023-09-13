library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
use proc_common_v3_00_a.srl_fifo_f;

entity user_logic is
  generic
  (
    C_DDC_GIE                    : std_logic_vector     := X"0000001C";
    C_DDC_ISR                    : std_logic_vector     := X"00000020";
    C_DDC_IER                    : std_logic_vector     := X"00000028";
    C_DDC_SOFTR                  : std_logic_vector     := X"00000040";
    C_DDC_CR                     : std_logic_vector     := X"00000100";
    C_DDC_SR                     : std_logic_vector     := X"00000104";
    C_DDC_Tx_FIFO                : std_logic_vector     := X"00000108";
    C_DDC_Rc_FIFO                : std_logic_vector     := X"0000010C";
    C_DDC_ADR                    : std_logic_vector     := X"00000110";
    C_DDC_Tx_FIFO_OCY            : std_logic_vector     := X"00000114";
    C_DDC_Rc_FIFO_OCY            : std_logic_vector     := X"00000118";
    C_DDC_TEN_ADR                : std_logic_vector     := X"0000011C";
    C_DDC_Rc_FIFO_PIRQ           : std_logic_vector     := X"00000120";
    C_DDC_GPO                    : std_logic_vector     := X"00000124";

    C_SLV_DWIDTH                   : integer              := 32;
    C_MST_AWIDTH                   : integer              := 32;
    C_MST_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 4
  );
  port
  (
    Intr                           : in std_logic;

    Bus2IP_Clk                     : in  std_logic;
    Bus2IP_Reset                   : in  std_logic;
    Bus2IP_Data                    : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    Bus2IP_BE                      : in  std_logic_vector(0 to C_SLV_DWIDTH/8-1);
    Bus2IP_RdCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    Bus2IP_WrCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    IP2Bus_Data                    : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    IP2Bus_RdAck                   : out std_logic;
    IP2Bus_WrAck                   : out std_logic;
    IP2Bus_Error                   : out std_logic;
    IP2Bus_MstRd_Req               : out std_logic;
    IP2Bus_MstWr_Req               : out std_logic;
    IP2Bus_Mst_Addr                : out std_logic_vector(0 to C_MST_AWIDTH-1);
    IP2Bus_Mst_BE                  : out std_logic_vector(0 to C_MST_DWIDTH/8-1);
    IP2Bus_Mst_Lock                : out std_logic;
    IP2Bus_Mst_Reset               : out std_logic;
    Bus2IP_Mst_CmdAck              : in  std_logic;
    Bus2IP_Mst_Cmplt               : in  std_logic;
    Bus2IP_Mst_Error               : in  std_logic;
    Bus2IP_Mst_Rearbitrate         : in  std_logic;
    Bus2IP_Mst_Cmd_Timeout         : in  std_logic;
    Bus2IP_MstRd_d                 : in  std_logic_vector(0 to C_MST_DWIDTH-1);
    Bus2IP_MstRd_src_rdy_n         : in  std_logic;
    IP2Bus_MstWr_d                 : out std_logic_vector(0 to C_MST_DWIDTH-1);
    Bus2IP_MstWr_dst_rdy_n         : in  std_logic
  );

  attribute MAX_FANOUT : string;
  attribute SIGIS : string;

  attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
  attribute SIGIS of Bus2IP_Reset  : signal is "RST";
  attribute SIGIS of IP2Bus_Mst_Reset: signal is "RST";

end entity user_logic;

architecture IMP of user_logic is

  type STATE_T is (DDC_INIT, DDC_RW_REQ, DDC_WAIT, DDC_NEXT, DDC_ERROR, IDLE, DDC_INTR);
  signal state : STATE_T := DDC_INIT;
  
  type OPCODE_T is (DDC_READ, DDC_WRITE);
  type OPERATION_T is record
    OPCODE : OPCODE_T;
    ADDR   : std_logic_vector(0 to 31);
    DATA   : std_logic_vector(0 to 31);
    FLAG   : std_logic_vector(0 to 31);
  end record;
  type OPERATIONS_T is array (0 to 13) of OPERATION_T;
  
  signal operations : OPERATIONS_T := ((DDC_WRITE, C_DDC_IER, X"00000026", (others => '0')),
                                       (DDC_WRITE, C_DDC_ADR, X"000000A0", (others => '0')),
                                       (DDC_WRITE, C_DDC_GIE, X"80000000", (others => '0')),
                                       (DDC_WRITE, C_DDC_CR, X"00000001", (others => '0')),
                                       (DDC_READ, C_DDC_ISR, (others => '0'), X"00000020"),
                                       (DDC_READ, C_DDC_Rc_FIFO, (others => '0'), (others => '0')),
                                       (DDC_READ, C_DDC_ISR, (others => '0'), X"00000004"),
                                       (DDC_READ, C_DDC_Tx_FIFO_OCY, (others => '0'), X"0000000F"),
                                       (DDC_WRITE, C_DDC_Tx_FIFO, (others => '0'), (others => '0')), 
                                       (DDC_READ, C_DDC_ISR, (others => '0'), X"00000002"),
                                       (DDC_WRITE, C_DDC_CR, X"00000003", (others => '0')),
                                       (DDC_WRITE, C_DDC_CR, X"00000001", (others => '0')),
                                       (DDC_READ, C_DDC_ISR, (others => '0'), X"11111111"),
	                                    (DDC_WRITE, C_DDC_ISR, (others => '0'), (others => '0')));
  
  type EDID is array(0 to 127) of std_logic_vector(0 to 7);
  constant atlys_edid : EDID := (x"00",x"FF",x"FF",x"FF",x"FF",x"FF",x"FF",x"00",x"11",x"27",x"00",x"00",x"00",x"00",x"00",x"00",
                                 x"2C",x"15",x"01",x"03",x"80",x"26",x"1E",x"78",x"2A",x"E5",x"C5",x"A4",x"56",x"4A",x"9C",x"23",
                                 x"12",x"50",x"54",x"BF",x"EF",x"80",x"8B",x"C0",x"95",x"00",x"95",x"0F",x"81",x"80",x"81",x"40",
                                 x"81",x"C0",x"71",x"4F",x"61",x"4F",x"6B",x"35",x"A0",x"F0",x"51",x"84",x"2A",x"30",x"60",x"98",
                                 x"36",x"00",x"78",x"2D",x"11",x"00",x"00",x"1C",x"00",x"00",x"00",x"FD",x"00",x"38",x"4B",x"1F",
                                 x"50",x"0E",x"0A",x"0A",x"20",x"20",x"20",x"20",x"20",x"20",x"00",x"00",x"00",x"FC",x"00",x"41",
                                 x"54",x"4C",x"59",x"53",x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"20",x"00",x"00",x"00",x"FE",
                                 x"00",x"44",x"49",x"47",x"49",x"4C",x"45",x"4E",x"54",x"52",x"4F",x"43",x"4B",x"53",x"00",x"12");

  signal iic_intr : std_logic;
  
  signal op     : natural range 0 to 15 := 0;
  signal edid_i : natural range 0 to 128 := 0;


begin
  
  iic_intr <= Intr;

  NEXT_STATE_PROC : process(Bus2IP_Clk, iic_intr) is
  begin
    if ((iic_intr = '1') and (state = IDLE)) then
      op <= 4;
      state <= DDC_RW_REQ;

    elsif ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
	   if ( Bus2IP_Reset = '1' ) then
        -- reset condition
      else
        case state is

          when DDC_INIT =>
            op <= 0;
            state   <= DDC_RW_REQ;

          when DDC_RW_REQ =>
            IP2Bus_MstWr_Req <= '0';
            IP2Bus_MstRd_Req <= '0';
            if ( Bus2IP_Mst_CmdAck = '1' and Bus2IP_Mst_Cmplt = '0' ) then
              state <= DDC_WAIT;
            elsif ( Bus2IP_Mst_Cmplt = '1' ) then
              if ((Bus2IP_Mst_Cmd_Timeout = '1') or (Bus2IP_Mst_Error = '1')) then
                state <= DDC_ERROR;
              else
                if (operations(op).OPCODE = DDC_READ) then
                  operations(op).DATA <= Bus2IP_MstRd_d;
                end if;
                state <= DDC_NEXT;
              end if;
            else
              IP2Bus_Mst_Addr <= operations(op).ADDR;
              if (operations(op).OPCODE = DDC_READ) then
                IP2Bus_Mst_BE <= X"F";
                operations(op).DATA <= Bus2IP_MstRd_d;
                IP2Bus_MstWr_Req <= '0';
                if (Bus2IP_MstRd_src_rdy_n = '1') then
                  IP2Bus_MstRd_Req <= '1';
                end if;
              else
                if (op = 8) then
                  IP2Bus_MstWr_d <= x"000000" & atlys_edid(edid_i);
                  IP2Bus_Mst_BE <= "0001";
                elsif (op = 13) then
                  IP2Bus_MstWr_d <= operations(12).DATA;
                  IP2Bus_Mst_BE <= X"F";
                else
                  IP2Bus_MstWr_d   <= operations(op).DATA;
                  IP2Bus_Mst_BE <= X"F";
                end if;
                IP2Bus_MstRd_Req <= '0';
                if (Bus2IP_MstWr_dst_rdy_n = '1') then
                  IP2Bus_MstWr_Req <= '1';
                end if;
              end if;
              state <= DDC_RW_REQ;
            end if;

          when DDC_WAIT =>
            if ( Bus2IP_Mst_Cmplt = '1' ) then
              if ((Bus2IP_Mst_Cmd_Timeout = '1') or (Bus2IP_Mst_Error = '1')) then
                state <= DDC_ERROR;
              else 
                if (operations(op).OPCODE = DDC_READ) then
                  operations(op).DATA <= Bus2IP_MstRd_d;
                end if;
                state <= DDC_NEXT;
              end if;
            else
              state <= DDC_WAIT;
            end if;

          when DDC_NEXT =>
            case op is
              when 0|1|2|5|10|11|12 =>
                if (op = 11) then
                  edid_i <= 0;
                end if;
                op <= op + 1;
                state <= DDC_RW_REQ;
              when 4|6|9 =>
                if ((operations(op).DATA and operations(op).FLAG) /= X"00000000") then
                  op <= op + 1;
                else
                  if (op = 4) then
                    op <= 6;
                  else
                    op <= op + 3;
                  end if;
                end if;
                state <= DDC_RW_REQ;
              when 7 =>
                if (((operations(op).DATA and operations(op).FLAG) < 15) and (edid_i < 128)) then
                  op <= 8;
                else
                  op <= 9;
                end if;
                state <= DDC_RW_REQ;
              when 8 =>
                op <= 7;
                edid_i <= edid_i + 1;
                state <= DDC_RW_REQ;
              when 3|13 =>
                state <= IDLE;
              when others =>
                state <= DDC_ERROR;
            end case;

          when IDLE =>
            state <= IDLE;
				
          when DDC_INTR =>
            state <= DDC_INTR;

          when others =>
            state <= DDC_ERROR;
        end case;

      end if;
    end if;

  end process NEXT_STATE_PROC;

end IMP;
