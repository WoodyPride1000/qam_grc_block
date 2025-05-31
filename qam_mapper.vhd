library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity qam_mapper is
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        data_in        : in  std_logic_vector(7 downto 0);  -- 入力データ (uint8)
        qam_size       : in  std_logic_vector(1 downto 0);  -- QAMサイズ (00=16, 01=64, 10=128, 11=256)
        enable_gray_map: in  std_logic;                    -- グレイコード有効フラグ
        data_out_i     : out signed(15 downto 0);          -- I成分 (16ビット固定小数点)
        data_out_q     : out signed(15 downto 0);          -- Q成分 (16ビット固定小数点)
        error_flag     : out std_logic                     -- エラーフラグ
    );
end qam_mapper;

architecture behavioral of qam_mapper is
    -- 内部信号
    signal mapped_data : std_logic_vector(7 downto 0);
    signal lut_out_i, lut_out_q : signed(15 downto 0);
    signal valid_input : std_logic;
    signal bit_width : unsigned(3 downto 0);
    signal scale_factor : signed(15 downto 0);

    -- スケーリング係数 (固定小数点、Q4.12形式、事前計算済み)
    constant SCALE_16  : signed(15 downto 0) := to_signed(8192, 16);  -- 約0.5
    constant SCALE_64  : signed(15 downto 0) := to_signed(4096, 16);  -- 約0.25
    constant SCALE_128 : signed(15 downto 0) := to_signed(3072, 16);  -- 約0.1875
    constant SCALE_256 : signed(15 downto 0) := to_signed(2048, 16);  -- 約0.125

    -- コンポーネント宣言
    component gray_decoder
        port (
            data_in   : in  std_logic_vector(7 downto 0);
            bit_width : in  unsigned(3 downto 0);
            enable    : in  std_logic;
            data_out  : out std_logic_vector(7 downto 0)
        );
    end component;

    component constellation_lut
        port (
            clk       : in  std_logic;
            index     : in  std_logic_vector(7 downto 0);
            qam_size  : in  std_logic_vector(1 downto 0);
            valid     : in  std_logic;
            data_out_i: out signed(15 downto 0);
            data_out_q: out signed(15 downto 0)
        );
    end component;

begin
    -- QAMサイズごとのビット幅
    bit_width <= to_unsigned(4, 4) when qam_size = "00" else  -- QAM-16: 4ビット
                 to_unsigned(6, 4) when qam_size = "01" else  -- QAM-64: 6ビット
                 to_unsigned(7, 4) when qam_size = "10" else  -- QAM-128: 7ビット
                 to_unsigned(8, 4);                           -- QAM-256: 8ビット

    -- 入力バリデーション
    valid_input <= '1' when unsigned(data_in) < shift_left(to_unsigned(1, 8), to_integer(bit_width)) else '0';

    -- スケーリング係数の選択
    scale_factor <= SCALE_16 when qam_size = "00" else
                    SCALE_64 when qam_size = "01" else
                    SCALE_128 when qam_size = "10" else
                    SCALE_256;

    -- グレイコード逆変換インスタンス
    gray_dec: gray_decoder
        port map (
            data_in   => data_in,
            bit_width => bit_width,
            enable    => enable_gray_map,
            data_out  => mapped_data
        );

    -- コンスタレーションLUTインスタンス
    lut: constellation_lut
        port map (
            clk       => clk,
            index     => mapped_data when enable_gray_map = '1' else data_in,
            qam_size  => qam_size,
            valid     => valid_input,
            data_out_i => lut_out_i,
            data_out_q => lut_out_q
        );

    -- 出力と正規化プロセス
    process (clk, reset)
    begin
        if reset = '1' then
            data_out_i <= (others => '0');
            data_out_q <= (others => '0');
            error_flag <= '0';
        elsif rising_edge(clk) then
            if valid_input = '0' then
                data_out_i <= (others => '0');  -- 範囲外入力は0j
                data_out_q <= (others => '0');
                error_flag <= '1';
            else
                -- スケーリング（固定小数点乗算、右シフト15で正規化）
                data_out_i <= resize(shift_right(lut_out_i * scale_factor, 15), 16);
                data_out_q <= resize(shift_right(lut_out_q * scale_factor, 15), 16);
                error_flag <= '0';
            end if;
        end if;
    end process;
end behavioral;
