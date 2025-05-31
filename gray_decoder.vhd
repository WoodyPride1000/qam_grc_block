library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gray_decoder is
    port (
        data_in   : in  std_logic_vector(7 downto 0);  -- Grayコード入力
        bit_width : in  unsigned(3 downto 0);           -- 有効なビット幅 (1～8)
        enable    : in  std_logic;                      -- 変換有効フラグ ('1'で変換、'0'でスルー)
        data_out  : out std_logic_vector(7 downto 0)   -- バイナリ出力
    );
end gray_decoder;

architecture behavioral of gray_decoder is
begin
    process (data_in, bit_width, enable)
        variable binary_val : unsigned(7 downto 0);
        variable masked_input : unsigned(7 downto 0);
    begin
        -- bit_widthの範囲チェック（1～8）
        if to_integer(bit_width) < 1 or to_integer(bit_width) > 8 then
            data_out <= (others => '0');  -- 無効なbit_widthの場合、ゼロ出力
        else
            -- 入力のマスク処理
            masked_input := unsigned(data_in) and (shift_left(to_unsigned(1, 8), to_integer(bit_width)) - 1);

            if enable = '0' then
                -- グレイコード変換を無効化（入力をスルー）
                data_out <= std_logic_vector(masked_input);
            else
                -- グレイコードからバイナリへの変換（並列XOR）
                binary_val := masked_input;
                -- 必要なシフトのみ実行（最大bit_width-1）
                for i in 0 to 6 loop
                    if i < to_integer(bit_width) - 1 then
                        binary_val := binary_val xor shift_right(binary_val, 2**i);
                    end if;
                end loop;
                -- 出力をマスク
                data_out <= std_logic_vector(binary_val and (shift_left(to_unsigned(1, 8), to_integer(bit_width)) - 1));
            end if;
        end if;
    end process;
end behavioral;
