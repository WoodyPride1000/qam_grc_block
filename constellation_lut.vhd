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
    type lut_array is array (0 to 255) of signed(15 downto 0);
    signal lut_16_i, lut_16_q : lut_array;
    -- 他のQAMサイズ用のLUTも同様に定義
    -- 実際にはROMまたはBRAMに格納

begin
    -- LUT初期化（QAM-16の例、固定小数点、Q4.12形式）
    process
    begin
        lut_16_i(0) <= to_signed(-12288, 16);  -- -3
        lut_16_q(0) <= to_signed(-12288, 16);  -- -3
        lut_16_i(1) <= to_signed(-12288, 16);  -- -3
        lut_16_q(1) <= to_signed(-4096, 16);   -- -1
        -- ... 他のインデックス（2～15）を同様に設定
        -- QAM-64, 128, 256のLUTも同様に初期化
        wait;
    end process;

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
                    when others =>  -- QAM-64, 128, 256（未実装の例）
                        data_out_i <= (others => '0');
                        data_out_q <= (others => '0');
                end case;
            end if;
        end if;
    end process;
end behavioral;
