library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity qam_mapper_tb is
end qam_mapper_tb;

architecture behavioral of qam_mapper_tb is
    -- 定数
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHzクロック

    -- 信号
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '1';
    signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
    signal qam_size       : std_logic_vector(1 downto 0) := "00";
    signal enable_gray_map: std_logic := '1';
    signal data_out_i     : signed(15 downto 0);
    signal data_out_q     : signed(15 downto 0);
    signal error_flag     : std_logic;

    -- LUT配列型定義
    type lut_array_16 is array (0 to 15) of signed(15 downto 0);
    type lut_array_64 is array (0 to 63) of signed(15 downto 0);
    type lut_array_128 is array (0 to 127) of signed(15 downto 0);
    type lut_array_256 is array (0 to 255) of signed(15 downto 0);

    -- 期待値（Pythonスクリプトから生成）
    constant EXPECTED_QAM_16_I : lut_array_16 := (
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
    constant EXPECTED_QAM_16_Q : lut_array_16 := (
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
    -- QAM-64, 128, 256の期待値は省略（Pythonスクリプトで生成）

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
            assert data_out_i = expected_i
                report "Error: " & test_name & ", I component mismatch at index " & integer'image(index)
                severity error;
            assert data_out_q = expected_q
                report "Error: " & test_name & ", Q component mismatch at index " & integer'image(index)
                severity error;
            assert error_flag = expected_error
                report "Error: " & test_name & ", error_flag mismatch at index " & integer'image(index)
                severity error;
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

        -- QAM-16テスト（Gray有効）
        qam_size <= "00";
        enable_gray_map <= '1';
        wait for CLK_PERIOD * 2;  -- qam_size安定待ち
        data_in <= std_logic_vector(to_unsigned(0, 8));  -- Gray: 0, Binary: 0
        check_output(0, "00", EXPECTED_QAM_16_I(0), EXPECTED_QAM_16_Q(0), '0', "QAM-16 Gray");
        data_in <= std_logic_vector(to_unsigned(1, 8));  -- Gray: 1, Binary: 1
        check_output(1, "00", EXPECTED_QAM_16_I(1), EXPECTED_QAM_16_Q(1), '0', "QAM-16 Gray");
        data_in <= std_logic_vector(to_unsigned(3, 8));  -- Gray: 3, Binary: 2
        check_output(3, "00", EXPECTED_QAM_16_I(2), EXPECTED_QAM_16_Q(2), '0', "QAM-16 Gray");
        data_in <= std_logic_vector(to_unsigned(16, 8)); -- 範囲外
        check_output(16, "00", to_signed(0, 16), to_signed(0, 16), '1', "QAM-16 Out-of-range");

        -- QAM-16テスト（Gray無効）
        enable_gray_map <= '0';
        wait for CLK_PERIOD * 2;
        data_in <= std_logic_vector(to_unsigned(0, 8));
        check_output(0, "00", EXPECTED_QAM_16_I(0), EXPECTED_QAM_16_Q(0), '0', "QAM-16 No Gray");
        data_in <= std_logic_vector(to_unsigned(15, 8));
        check_output(15, "00", EXPECTED_QAM_16_I(15), EXPECTED_QAM_16_Q(15), '0', "QAM-16 No Gray");

        -- QAM-64テスト（Gray有効）
        qam_size <= "01";
        enable_gray_map <= '1';
        wait for CLK_PERIOD * 2;
        data_in <= std_logic_vector(to_unsigned(0, 8));
        check_output(0, "01", to_signed(-14336, 16), to_signed(-14336, 16), '0', "QAM-64 Gray");
        data_in <= std_logic_vector(to_unsigned(63, 8));
        check_output(63, "01", to_signed(14336, 16), to_signed(14336, 16), '0', "QAM-64 Gray");
        data_in <= std_logic_vector(to_unsigned(64, 8));
        check_output(64, "01", to_signed(0, 16), to_signed(0, 16), '1', "QAM-64 Out-of-range");

        -- QAM-128, QAM-256も同様にテスト（省略）
        wait for CLK_PERIOD * 10;
        assert false report "Test completed" severity note;
        wait;
    end process;
end behavioral;
