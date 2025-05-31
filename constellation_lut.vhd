library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity constellation_lut is
    port (
        clk       : in  std_logic;
        index     : in  std_logic_vector(7 downto 0);
        qam_size  : in  std_logic_vector(1 downto 0);
        valid     : in  std_logic;
        data_out_i: out signed(15 downto 0);
        data_out_q: out signed(15 downto 0)
    );
end constellation_lut;

architecture behavioral of constellation_lut is
    -- LUT配列型定義
    type lut_array_16 is array (0 to 15) of signed(15 downto 0);
    type lut_array_64 is array (0 to 63) of signed(15 downto 0);
    type lut_array_128 is array (0 to 127) of signed(15 downto 0);
    type lut_array_256 is array (0 to 255) of signed(15 downto 0);

    -- LUT初期化（Pythonスクリプトから生成）
    signal lut_16_i : lut_array_16 := (
        0 => to_signed(-6144, 16),  -- -1.5
        1 => to_signed(-6144, 16),  -- -1.5
        2 => to_signed(-6144, 16),  -- -1.5
        3 => to_signed(-6144, 16),  -- -1.5
        4 => to_signed(-2048, 16),  -- -0.5
        5 => to_signed(-2048, 16),  -- -0.5
        6 => to_signed(-2048, 16),  -- -0.5
        7 => to_signed(-2048, 16),  -- -0.5
        8 => to_signed(2048, 16),   -- 0.5
        9 => to_signed(2048, 16),   -- 0.5
        10 => to_signed(2048, 16),  -- 0.5
        11 => to_signed(2048, 16),  -- 0.5
        12 => to_signed(6144, 16),  -- 1.5
        13 => to_signed(6144, 16),  -- 1.5
        14 => to_signed(6144, 16),  -- 1.5
        15 => to_signed(6144, 16),  -- 1.5
        others => (others => '0')
    );
    signal lut_16_q : lut_array_16 := (
        0 => to_signed(-6144, 16),  -- -1.5
        1 => to_signed(-2048, 16),  -- -0.5
        2 => to_signed(2048, 16),   -- 0.5
        3 => to_signed(6144, 16),   -- 1.5
        4 => to_signed(-6144, 16),  -- -1.5
        5 => to_signed(-2048, 16),  -- -0.5
        6 => to_signed(2048, 16),   -- 0.5
        7 => to_signed(6144, 16),   -- 1.5
        8 => to_signed(-6144, 16),  -- -1.5
        9 => to_signed(-2048, 16),  -- -0.5
        10 => to_signed(2048, 16),  -- 0.5
        11 => to_signed(6144, 16),  -- 1.5
        12 => to_signed(-6144, 16), -- -1.5
        13 => to_signed(-2048, 16), -- -0.5
        14 => to_signed(2048, 16),  -- 0.5
        15 => to_signed(6144, 16),  -- 1.5
        others => (others => '0')
    );
    -- QAM-64, 128, 256のLUTは省略（Pythonスクリプトで生成）
    -- 例: QAM-64の一部
    signal lut_64_i : lut_array_64 := (
        0 => to_signed(-14336, 16), -- -3.5
        1 => to_signed(-14336, 16), -- -3.5
        -- ... 他の62エントリ ...
        others => (others => '0')
    );
    signal lut_64_q : lut_array_64 := (
        0 => to_signed(-14336, 16), -- -3.5
        -- ... 他の62エントリ ...
        others => (others => '0')
    );
    signal lut_128_i : lut_array_128 := (
        0 => to_signed(-14336, 16), -- -3.5
        -- ... 他の126エントリ ...
        others => (others => '0')
    );
    signal lut_128_q : lut_array_128 := (
        0 => to_signed(-30720, 16), -- -7.5
        -- ... 他の126エントリ ...
        others => (others => '0')
    );
    signal lut_256_i : lut_array_256 := (
        0 => to_signed(-30720, 16), -- -7.5
        -- ... 他の254エントリ ...
        others => (others => '0')
    );
    signal lut_256_q : lut_array_256 := (
        0 => to_signed(-30720, 16), -- -7.5
        -- ... 他の254エントリ ...
        others => (others => '0')
    );

begin
    process (clk)
    begin
        if rising_edge(clk) then
            if valid = '0' then
                data_out_i <= (others => '0');
                data_out_q <= (others => '0');
            else
                case qam_size is
                    when "00" =>  -- QAM-16
                        data_out_i <= lut_16_i(to_integer(unsigned(index(3 downto 0))));
                        data_out_q <= lut_16_q(to_integer(unsigned(index(3 downto 0))));
                    when "01" =>  -- QAM-64
                        data_out_i <= lut_64_i(to_integer(unsigned(index(5 downto 0))));
                        data_out_q <= lut_64_q(to_integer(unsigned(index(5 downto 0))));
                    when "10" =>  -- QAM-128
                        data_out_i <= lut_128_i(to_integer(unsigned(index(6 downto 0))));
                        data_out_q <= lut_128_q(to_integer(unsigned(index(6 downto 0))));
                    when "11" =>  -- QAM-256
                        data_out_i <= lut_256_i(to_integer(unsigned(index(7 downto 0))));
                        data_out_q <= lut_256_q(to_integer(unsigned(index(7 downto 0))));
                    when others =>
                        data_out_i <= (others => '0');
                        data_out_q <= (others => '0');
                end case;
            end if;
        end if;
    end process;
end behavioral;
