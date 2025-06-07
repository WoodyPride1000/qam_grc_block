library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all; -- シミュレーション用途、合成時にはLUTやCORDICなどに置き換え

-- =========================================================================
-- Top-level entity for GPS L1 C/A Signal Simulator on USRP FPGA
-- =========================================================================
entity gps_l1_ca_simulator is
    generic (
        NUM_SATELLITES : natural := 4; -- 同時にシミュレートする衛星の数
        SDR_SAMPLE_RATE_HZ : natural := 40e6 -- SDRのサンプリングレート (例: 40 MSPS)
    );
    port (
        -- FPGA共通インターフェース
        clk_fpga        : in  std_logic; -- FPGAメインクロック (例: 100 MHz or higher)
        clk_sdr_tx      : in  std_logic; -- SDR送信部クロック (DACクロック)
        reset           : in  std_logic;
        
        -- GPSDOインターフェース (USRP内部で供給)
        pps_in          : in  std_logic; -- 1 PPS (Pulse Per Second)
        ref_clk_10mhz   : in  std_logic; -- 10 MHzリファレンスクロック
        
        -- ホストPCからのパラメータインターフェース (UHD/DMA経由を想定)
        -- 各衛星に対するパラメータをまとめて受信
        -- 実際のインターフェースはAXI4-Liteやカスタムレジスタマップになる
        host_params_valid : in  std_logic;
        host_prn_ids      : in  std_logic_vector(NUM_SATELLITES * 5 - 1 downto 0); -- 各5ビット
        host_pseudoranges : in  signed(NUM_SATELLITES * 32 - 1 downto 0); -- 擬似距離 (m), Q形式など
        host_dopplers_hz  : in  signed(NUM_SATELLITES * 32 - 1 downto 0); -- ドップラー周波数 (Hz), Q形式など
        host_nav_message_bits : in  std_logic_vector(NUM_SATELLITES * 50 - 1 downto 0); -- 各衛星の航法メッセージビット (1秒分など)
        
        -- USRP DACへの出力
        tx_data_i       : out signed(15 downto 0); -- I成分 (DAC入力)
        tx_data_q       : out signed(15 downto 0)  -- Q成分 (DAC入力)
    );
end gps_l1_ca_simulator;

architecture structural of gps_l1_ca_simulator is

    -- 内部信号宣言
    -- C/AコードとNavデータのXOR結果 (各衛星ごと)
    signal sv_data_in_bpsk : std_logic_vector(NUM_SATELLITES - 1 downto 0);
    
    -- NCOからのキャリア信号 (各衛星ごと)
    signal sv_nco_cos_out : signed(15 downto 0) array (0 to NUM_SATELLITES - 1);
    signal sv_nco_sin_out : signed(15 downto 0) array (0 to NUM_SATELLITES - 1);
    
    -- BPSK変調後のI/Qサンプル (各衛星ごと)
    signal sv_bpsk_i_out : signed(15 downto 0) array (0 to NUM_SATELLITES - 1);
    signal sv_bpsk_q_out : signed(15 downto 0) array (0 to NUM_SATELLITES - 1);

    -- 最終的な合成I/Qサンプル
    signal combined_i_sum : signed(31 downto 0); -- Summing requires wider bitwidth
    signal combined_q_sum : signed(31 downto 0);
    
    -- DAC出力スケーリング用定数 (必要に応じて調整)
    constant DAC_SCALE_FACTOR : signed(15 downto 0) := to_signed(16384, 16); -- Q1.15, 0.5f

    -- =========================================================================
    -- Component Declarations (これまで作成してきたモジュールを宣言)
    -- =========================================================================

    -- Component: C/A Code Generator
    -- (PRN IDとチップ位相オフセットをパラメータとして受け取り、チップを出力)
    component gps_ca_code_generator is
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            prn_id      : in  std_logic_vector(4 downto 0); -- 0-31
            -- C/Aコードの開始チップオフセット (擬似距離に対応)
            code_offset : in  signed(20 downto 0); -- チップ数で表現されるオフセット (例: 1ms = 1023チップ)
            code_chip_out : out std_logic -- '1' or '0' for +1/-1
        );
    end component;

    -- Component: Navigation Message Generator
    -- (GPS時刻などを受け取り、航法メッセージビットを出力)
    component gps_nav_message_generator is
        port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            gps_time_sec  : in  unsigned(20 downto 0); -- GPS時刻 (秒単位)
            prn_id        : in  std_logic_vector(4 downto 0);
            nav_message_bit : out std_logic -- 50 bps data bit
        );
    end component;

    -- Component: Numerically Controlled Oscillator (NCO)
    -- (キャリア周波数とドップラーを合成した周波数ワードを受け取り、サイン/コサイン波を生成)
    component nco is
        generic (
            PHASE_ACC_BITS : natural := 32; -- 位相アキュムレータのビット幅
            COS_SIN_OUT_BITS : natural := 16 -- サイン/コサイン出力のビット幅 (Q1.15)
        );
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            frequency_word: in signed(PHASE_ACC_BITS - 1 downto 0); -- 周波数ワード (Hz/SDR_SAMPLE_RATE_HZ * 2^PHASE_ACC_BITS)
            cos_out     : out signed(COS_SIN_OUT_BITS - 1 downto 0);
            sin_out     : out signed(COS_SIN_OUT_BITS - 1 downto 0)
        );
    end component;

    -- Component: BPSK Modulator (以前作成したもの)
    component gps_bpsk_modulator is
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            data_in         : in  std_logic; 
            nco_cos_in      : in  signed(15 downto 0);
            nco_sin_in      : in  signed(15 downto 0);
            data_out_i      : out signed(15 downto 0);
            data_out_q      : out signed(15 downto 0)
        );
    end component;

begin

    -- =========================================================================
    -- ホストPCからのパラメータ処理 (概念的、実際のUSRPインターフェースに依存)
    -- =========================================================================
    -- この部分は、ホストPCから送られてくるパラメータを適切なタイミングで
    -- 各モジュールに供給するロジックを記述します。
    -- 例: ホストPC_params_valid が '1' のときに、パラメータをラッチするFFなど。
    -- 時間同期ロジック (GPSDO PPSとの同期) はここに記述されます。
    -- 現在時刻の計算 (GPS Week, TOW) もここに含める必要があります。
    
    -- 簡略化のため、ここではホストPCから各衛星へのパラメータ分割のみ記述
    -- 各PRN ID、擬似距離、ドップラー、航法メッセージビットを個別に抽出
    -- (実際のホストPCインターフェースとバス幅に合わせて調整)
    -- VHDL-2008では配列のスライスが可能だが、ここでは明示的に記述
    
    -- 例: N個の衛星に対してループを回し、各コンポーネントをインスタンス化
    GEN_SATELLITES: for i in 0 to NUM_SATELLITES - 1 generate
        -- 各衛星のPRN IDを抽出 (ホスト_prn_ids から5ビットずつ)
        -- to_integerでPRN IDを0-31に変換
        signal prn_id_current : std_logic_vector(4 downto 0) := host_prn_ids(i*5+4 downto i*5);
        
        -- 各衛星の擬似距離を抽出
        signal pseudorange_current : signed(31 downto 0) := host_pseudoranges(i*32+31 downto i*32);
        
        -- 各衛星のドップラーを抽出
        signal doppler_current : signed(31 downto 0) := host_dopplers_hz(i*32+31 downto i*32);
        
        -- 各衛星の航法メッセージビットを抽出 (1秒分など)
        signal nav_message_bits_current : std_logic_vector(49 downto 0) := host_nav_message_bits(i*50+49 downto i*50);

        -- C/Aコード生成器インスタンス
        -- 擬似距離をC/Aコードのチップオフセットに変換するロジックが必要
        -- (pseudorange_current / C_LIGHT_M_PER_S) * CA_CODE_CHIP_RATE
        -- この変換はホストPC側で行い、FPGAにはチップオフセット値を送るのが一般的
        -- 仮にホストがチップオフセット (signed 21 bit) を送ってくると仮定
        signal ca_code_chip_offset : signed(20 downto 0); -- ホストから提供されると仮定
        
        ca_gen: gps_ca_code_generator
            port map (
                clk         => clk_sdr_tx, -- DACクロックで駆動
                reset       => reset,
                prn_id      => prn_id_current,
                code_offset => ca_code_chip_offset, -- 例: ホストから来た値をそのまま使用
                code_chip_out => sv_data_in_bpsk(i) -- C/Aコードを直接BPSKデータとして使用 (簡略化)
            );

        -- 航法メッセージ生成器インスタンス (簡略化: ホストからビットを直接受け取ると仮定)
        -- 実際は、ホストから来たnav_message_bits_currentから、現在の時刻に対応する1ビットを抽出するロジックが必要
        signal current_nav_bit : std_logic;
        -- 簡略化: nav_message_bits_current(0) を常に使用
        current_nav_bit <= nav_message_bits_current(0); 

        -- C/Aコードと航法メッセージのXOR (BPSKデータ)
        -- NOTE: GPS L1 C/Aでは、NavメッセージがC/Aコードを変調します。
        -- したがって、この `sv_data_in_bpsk(i)` は (C/A_code XOR Nav_bit) になります。
        -- 上記の `ca_gen` の出力は `code_chip_out` ですが、実際は
        -- `sv_data_in_bpsk(i) <= ca_gen.code_chip_out XOR current_nav_bit;`
        -- のような形で合成されます。ここでは簡略化のため `code_chip_out` を直接使用。
        
        -- NCOインスタンス
        -- ドップラーとL1周波数から周波数ワードを計算するロジックが必要
        -- F_word = (f_L1 + doppler_current) / SDR_SAMPLE_RATE_HZ * 2^PHASE_ACC_BITS
        -- この計算はホストPC側で行い、FPGAには周波数ワードを送るのが一般的
        signal nco_freq_word : signed(31 downto 0); -- ホストから提供されると仮定
        
        nco_gen: nco
            generic map (
                PHASE_ACC_BITS => 32,
                COS_SIN_OUT_BITS => 16
            )
            port map (
                clk         => clk_sdr_tx,
                reset       => reset,
                frequency_word=> nco_freq_word, -- 例: ホストから来た値をそのまま使用
                cos_out     => sv_nco_cos_out(i),
                sin_out     => sv_nco_sin_out(i)
            );

        -- BPSK変調器インスタンス
        bpsk_mod: gps_bpsk_modulator
            port map (
                clk             => clk_sdr_tx,
                reset           => reset,
                data_in         => sv_data_in_bpsk(i), -- C/Aコードと航法メッセージのXOR結果
                nco_cos_in      => sv_nco_cos_out(i),
                nco_sin_in      => sv_nco_sin_out(i),
                data_out_i      => sv_bpsk_i_out(i),
                data_out_q      => sv_bpsk_q_out(i)
            );

    end generate GEN_SATELLITES;

    -- =========================================================================
    -- 複数衛星信号の合成 (Summing)
    -- =========================================================================
    -- 各衛星のBPSK変調済みI/Qサンプルを合計します。
    -- 合計する前に、各衛星の信号強度 (CN0) を調整するためのゲイン制御を入れることも可能
    
    -- 初期化
    combined_i_sum <= (others => '0');
    combined_q_sum <= (others => '0');

    -- 合計ループ
    SUM_SATELLITES: for i in 0 to NUM_SATELLITES - 1 generate
        -- 適切な符号拡張を行って合計
        combined_i_sum <= combined_i_sum + resize(sv_bpsk_i_out(i), 32);
        combined_q_sum <= combined_q_sum + resize(sv_bpsk_q_out(i), 32);
    end generate SUM_SATELLITES;

    -- =========================================================================
    -- 最終出力のスケーリングと量子化
    -- =========================================================================
    -- 合計されたI/QサンプルをDACの入力フォーマットに合わせるため、スケーリングとリサイズを行う
    -- sum_i_sum と sum_q_sum は 32bit width, DAC_SCALE_FACTOR は Q1.15
    -- 積は 32 + 16 = 48bit width
    -- 例: Q1.15 * Q1.15 = Q3.30. 合計後もQ3.30と考える。
    -- これをDAC向け (16bit) にするため、適切な右シフトが必要。
    -- N個の信号の合計なので、飽和を避けるためにシフト量や初期スケールファクターを調整
    
    process (clk_sdr_tx, reset)
    begin
        if reset = '1' then
            tx_data_i <= (others => '0');
            tx_data_q <= (others => '0');
        elsif rising_edge(clk_sdr_tx) then
            -- 合計信号に最終スケーリングを適用
            -- 飽和を避けるため、通常はログスケールでゲインを調整するか、
            -- 非常に多くのビットを右シフトしてリサイズします。
            -- ここでは簡易的に、例えば NUM_SATELLITES = 4 なら 2ビット右シフトで対応 (2^2=4)
            -- そしてDAC_SCALE_FACTORを適用
            
            -- 例: combined_i_sum を単純に 2ビット右シフトし、DAC_SCALE_FACTOR を掛ける
            -- この固定小数点形式が非常に重要です。
            -- 実際には、SDR_DAC_MAX_VAL = 2^(15)-1 を超えないようにスケーリングします。
            tx_data_i <= resize(shift_right(combined_i_sum * DAC_SCALE_FACTOR, 15 + ceil_log2(NUM_SATELLITES)), 16);
            tx_data_q <= resize(shift_right(combined_q_sum * DAC_SCALE_FACTOR, 15 + ceil_log2(NUM_SATELLITES)), 16);
            -- ceil_log2はシミュレーションのみ、実際の合成では手動計算
        end if;
    end process;

    -- Helper function for ceil_log2 (for synthesis, a fixed value based on NUM_SATELLITES is better)
    -- function ceil_log2(N : natural) return natural is
    --     variable M : natural := 0;
    --     variable Temp : natural := N;
    -- begin
    --     if N = 0 then return 0; end if; -- Or error
    --     while Temp > 1 loop
    --         Temp := (Temp + 1) / 2;
    --         M := M + 1;
    --     end loop;
    --     return M;
    -- end function;

end structural;
