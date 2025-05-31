library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gray_decoder is
    port (
        data_in   : in  std_logic_vector(7 downto 0);
        bit_width : in  unsigned(3 downto 0);
        enable    : in  std_logic;
        data_out  : out std_logic_vector(7 downto 0)
    );
end gray_decoder;

architecture behavioral of gray_decoder is
begin
    process (data_in, bit_width, enable)
        variable binary : std_logic_vector(7 downto 0);
        variable temp : std_logic_vector(7 downto 0);
    begin
        if enable = '0' then
            binary := data_in;
        else
            binary := data_in;
            for i in 0 to 6 loop  -- bit_width-1まで
                if i < to_integer(bit_width) - 1 then
                    binary := binary xor shift_right(unsigned(data_in), i + 1);
                end if;
            end loop;
        end if;
        -- ビット幅でマスク
        temp := (others => '0');
        for i in 0 to 7 loop
            if i < to_integer(bit_width) then
                temp(i) := binary(i);
            end if;
        end loop;
        data_out <= temp;
    end process;
end behavioral;
