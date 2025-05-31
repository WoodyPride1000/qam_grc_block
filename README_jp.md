# QAM Mapperブロック説明書

## 1. 概要

**QAM Mapper**は、GNU Radioフレームワーク向けのカスタム同期ブロックです。入力バイトデータ（`unsigned char`）を指定されたQAM（直交振幅変調）コンスタレーションの複素数点にマッピングします。QAM-64（8x8グリッド）およびQAM-128（8x16グリッド）をサポートし、グレイコードマッピングの有効/無効を選択可能です。

このブロックは、デジタル通信システム（例：DVB、5G、Wi-Fi）での変調処理に適しており、効率的なNumPyベクトル化と堅牢なエラーハンドリングを実装しています。

## 2. 機能

- **入力**: 8ビット符号なし整数（`uint8`）の配列。各値はQAMコンスタレーションのインデックスを表します。
- **出力**: 複素数（`complex64`）の配列で、単位平均パワー（1）に正規化されたQAMシンボル。
- **設定可能なパラメータ**:
  - **QAM Size**: コンスタレーションサイズ（64または128）。
  - **Enable Gray Mapping**: グレイコードマッピングを適用するかどうか。
- **特徴**:
  - QAM-64（8x8グリッド）およびQAM-128（8x16グリッド）をサポート。
  - グレイコード変換/逆変換を効率的に処理。
  - 入力値の範囲チェックとエラーログ出力。
  - NumPyベクトル化による高パフォーマンス。

## 3. 依存関係

- **GNU Radio**: 同期ブロックの基盤として必要。
- **NumPy**: 配列操作とコンスタレーション生成に使用。
- **utils.py**: `generate_constellation`関数と`GrayCoder`クラスを含むユーティリティモジュール。

## 4. インストール

1. **ブロックの配置**:
   - XML定義ファイル（`qam_mapper.xml`）をGNU Radioのブロックディレクトリ（例: `~/.grc_gnuradio/`）に配置。
   - Python実装コードを`make_block`セクションから適切な`.py`ファイル（例: `qam_mapper.py`）として保存。
2. **ユーティリティモジュールの配置**:
   - `utils.py`をプロジェクトのPythonパス（例: `PYTHONPATH`）に配置。
3. **依存ライブラリの確認**:
   ```bash
   pip install numpy

GNU Radioがインストール済みであることを確認。

4. **GRCでの使用**:
GNU Radio Companion（GRC）でブロックをインポートし、フローに追加。

## 5. **パラメータ**:

|パラメータ名|型|デフォルト|説明|
| ---- | ---- | ---- | ---- |
|qam_size|int|128|QAMコンスタレーションサイズ（64または128）。|
|enable_gray_map|bool|True|グレイコードマッピングを有効化。|

パラメータ詳細
QAM Size:
64: 8x8グリッド（64点）のQAMコンスタレーション。

128: 8x16グリッド（128点）のQAMコンスタレーション。

その他の値はサポートされず、ValueErrorが発生します。

Enable Gray Mapping:
True: 入力値をグレイコードからバイナリに変換後、コンスタレーションにマッピング。

False: 入力値を直接コンスタレーションのインデックスとして使用。

## 6. **入力と出力**
入力: unsigned char（uint8）
範囲: 0 から qam_size-1（例: QAM-64なら0～63、QAM-128なら0～127）。

範囲外の値は0j（複素数ゼロ）にマッピングされ、警告ログが出力されます。

出力: complex float（complex64）
単位平均パワー（1）に正規化されたQAMシンボル。

## 7. **ユーティリティ関数（utils.py）**
QAM Mapperブロックは、以下のユーティリティ関数/クラスに依存します。
## 7.1 **generate_constellation**
機能: 指定されたQAMサイズに基づき、単位平均パワーに正規化されたコンスタレーションを生成。

引数:
qam_size (int): QAMサイズ（64または128）。

戻り値: np.ndarray（複素数配列）。

詳細:
QAM-64: 8x8グリッド（各軸8点、座標は{-7,-5,-3,-1,1,3,5,7}）。

QAM-128: 8x16グリッド（I軸8点、Q軸16点）。

平均パワーを1に正規化。

無効なqam_sizeはValueErrorを投げる。

## 7.2 **GrayCoderクラス**
機能: グレイコードの変換（バイナリ→グレイ）と逆変換（グレイ→バイナリ）を提供。

メソッド:
__init__(qam_size): QAMサイズに基づき、必要なビット数とマスクを初期化。

to_gray(vals): バイナリ値をグレイコードに変換。

from_gray(vals): グレイコードをバイナリ値に変換。

特徴:
NumPy配列に対応し、複数値の一括処理が可能。

QAMサイズに応じたビット数で値を制限（例: QAM-64は6ビット、QAM-128は7ビット）。

## 8. **使用例（GNU Radio Companion）**
フローの構築:
入力: Vector Source（uint8）でテストデータ（例: [0, 1, 2, ..., 63]）を生成。

QAM Mapper: パラメータを設定（例: qam_size=64, enable_gray_map=True）。

出力: QT GUI Constellation Sinkでコンスタレーションを可視化。

設定例:
QAM-64、グレイマッピング有効:

   ```plaintext
     QAM Size: 64
    Enable Gray Mapping: True
   ```


入力[0, 1, 2, 3]はグレイコード逆変換後、対応するコンスタレーション点にマッピング。

実行:
GRCでフローを実行し、コンスタレーション図を確認。

範囲外の入力値（例: 64以上の値）は0jにマッピングされ、ログに警告が出力。

## 9. **エラーハンドリング**:
無効なQAMサイズ: qam_sizeが64または128以外の場合は、ValueErrorが発生。

無効な入力値: 入力値が0未満またはqam_size以上の場合、0jを出力し、警告ログを記録。

コンスタレーションエラー: generate_constellationが期待するサイズの配列を返さない場合、ValueErrorが発生。


## 10. **パフォーマンス**:
効率性: NumPyベクトル化により、大量データの処理を高速化。

メモリ: コンスタレーションはqam_sizeに応じたサイズ（64または128のcomplex64配列）で、メモリ使用量は最小限。

ログ: 無効な入力値を検出時にlogging.warningで記録し、デバッグを支援。

## 11. **制限と拡張**:
制限:
現在の実装はQAM-64およびQAM-128のみサポート。

QAM-128は8x16グリッドを採用（DVB-T2や5G NRに準拠）。他の配置（例: 12x12）は未サポート。

拡張の可能性:
16-QAMや256-QAMをサポートするには、generate_constellationを一般化（points_per_axis = int(np.sqrt(qam_size))）。

他のグレイコード方式（例: 非標準のビット配置）に対応する場合は、GrayCoderを拡張。

## 12. **テスト**:
以下の単体テストで機能を確認できます（test_qam_mapper.py）：


```python

import numpy as np
import unittest
from utils import generate_constellation, GrayCoder

class TestQAMMapper(unittest.TestCase):
    def test_generate_constellation(self):
        points = generate_constellation(64)
        self.assertEqual(len(points), 64)
        self.assertAlmostEqual(np.mean(np.abs(points)**2), 1.0, delta=1e-6)
        
        points = generate_constellation(128)
        self.assertEqual(len(points), 128)
        self.assertAlmostEqual(np.mean(np.abs(points)**2), 1.0, delta=1e-6)

    def test_gray_coder(self):
        coder = GrayCoder(64)
        vals = np.array([0, 1, 2, 3])
        gray_vals = coder.to_gray(vals)  # [0, 1, 3, 2]
        self.assertTrue(np.array_equal(gray_vals, [0, 1, 3, 2]))
        binary_vals = coder.from_gray(gray_vals)
        self.assertTrue(np.array_equal(binary_vals, vals))

    def test_invalid_qam_size(self):
        with self.assertRaises(ValueError):
            generate_constellation(32)

if __name__ == '__main__':
    unittest.main()
```

## 13. **注意事項**:
ログの確認: 無効な入力値が検出された場合、ログファイルまたはコンソールに警告が出力されます。

規格準拠: QAM-128は8x16グリッドを使用。特定の規格（例: IEEE 802.11）で異なる配置が必要な場合は、generate_constellationを調整。

依存ファイル: utils.pyが正しく配置されていない場合、インポートエラーが発生します。

