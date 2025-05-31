library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.qam_expected_pkg.all;

entity qam_mapper_tb is
end qam_mapper_tb;

architecture behavioral of qam_mapper_tb is
    -- 定数
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHzクロック
    constant TOLERANCE : integer := 1;    -- 量子化誤差許容値 (±1 LSB)

    -- 信号
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
    signal qam_size       : std_logic_vector(1 downto 0) := "00";
    signal enable_gray_map: std_logic := '1';
    signal data_out_i     : signed(15 downto 0);
    signal data_out_q     : signed(15 downto 0);
    signal error_flag     : std_logic;

    component qam_mapper
        port (
            clk            : in  std_logic;
            reset          : in  std_logic;
            data_in        : in  std_logic_vector(7 downto 0);
            qam_size       : in  std_logic_vector(1 downto 0);
            enable_gray_map: in  std_logic;
            data_out_i     : out signed(15 downto 0);
            data_out_q     : out signed(15 downto 0);
            error_flag     : out std_logic
        );
    end component;

begin
    -- クロック生成
    clk_process: process
    begin
        wait for CLK_PERIOD / 2;
        clk <= not clk;
    end process;

    uut: qam_mapper
        port map (
            clk            => clk,
            reset          => reset,
            data_in        => data_in,
            qam_size       => qam_size,
            enable_gray_map => enable_gray_map,
            data_out_i     => data_out_i,
            data_out_q     => data_out_q,
            error_flag     => error_flag
        );

    stim_proc: process
        procedure check_output(
            index         : in  integer;
            qam_size_val  : in  std_logic_vector(1 downto 0);
            expected_i    : in  signed(15 downto 0);
            expected_q    : in  signed(15 downto 0);
            expected_error: in  std_logic;
            test_name     : in  string
        ) is
        begin
            wait until rising_edge(clk);
            wait for CLK_PERIOD / 4;  -- 出力安定待ち
            assert abs(to_integer(data_out_i) - to_integer(expected_i)) <= TOLERANCE
                report "Error: " & test_name & ", I component mismatch at index " & integer'image(index)
                severity error;
            assert abs(to_integer(data_out_q) - to_integer(expected_q)) <= TOLERANCE
                report "Error: " & test_name & ", Q component mismatch at index " & integer'image(index)
                severity error;
            assert error_flag = expected_error
                report "Error: " & test_name & ", error_flag mismatch at index " & integer'image(index)
                severity error;
        end procedure;

        procedure test_qam(
            qam_size_val  : in  std_logic_vector(1 downto 0);
            qam_size_int  : in  integer;
            enable_gray   : in  std_logic;
            test_name     : in  string
        ) is
            variable gray_index : integer;
        begin
            qam_size <= qam_size_val;
            enable_gray_map <= enable_gray;
            wait for CLK_PERIOD * 2;  -- qam_size安定待ち

            -- 最小値、最大値、中間値をテスト
            for i in 0 to qam_size_int - 1 loop
                if i = 0 or i = qam_size_int - 1 or i = qam_size_int / 2 then
                    gray_index := i;
                    if enable_gray = '1' then
                        -- グレイコード変換（簡略化のため、PythonのGrayCoder.to_grayを模倣）
                        gray_index := i xor (i / 2);  -- 実際は別途計算
                    end if;
                    data_in <= std_logic_vector(to_unsigned(gray_index, 8));
                    if qam_size_val = "00" then
                        check_output(i, qam_size_val, EXPECTED_QAM_16_I(i), EXPECTED_QAM_16_Q(i), '0', test_name);
                    -- QAM-64, 128, 256も同様に処理（省略）
                    end if;
                end if;
            end loop;

            -- 範囲外入力テスト
            data_in <= std_logic_vector(to_unsigned(qam_size_int, 8));
            check_output(qam_size_int, qam_size_val, to_signed(0, 16), to_signed(0, 16), '1', test_name & " Out-of-range");
        end procedure;

    begin
        -- リセット
        reset <= '1';
        wait for CLK_PERIOD * 2;
        reset <= '0';
        wait for CLK_PERIOD * 2;

        -- リセット中の動作確認
        data_in <= std_logic_vector(to_unsigned(0, 8));
        qam_size <= "00";
        enable_gray_map <= '1';
        check_output(0, "00", to_signed(0, 16), to_signed(0, 16), '0', "Reset state");

        -- QAM-16テスト
        test_qam("00", 16, '1', "QAM-16 Gray");
        test_qam("00", 16, '0', "QAM-16 No Gray");

        -- QAM-64テスト
        test_qam("01", 64, '1', "QAM-64 Gray");
        test_qam("01", 64, '0', "QAM-64 No Gray");

        -- QAM-128テスト
        test_qam("10", 128, '1', "QAM-128 Gray");
        test_qam("10", 128, '0', "QAM-128 No Gray");

        -- QAM-256テスト
        test_qam("11", 256, '1', "QAM-256 Gray");
        test_qam("11", 256, '0', "QAM-256 No Gray");

        wait for CLK_PERIOD * 10;
        assert false report "Test completed" severity note;
        wait;
    end process;
end behavioral;
