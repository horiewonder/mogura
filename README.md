# 土竜 mogura

macOS LaunchAgent を使った SSH トンネル常駐ツール 🕳️

## 特徴

- `~/.ssh/config` の Host 設定を活用
- ポートフォワード (`-L`) とダイナミックトンネル (`-D`) に対応
- LaunchAgent の KeepAlive で自動再接続
- 複数トンネルの同時管理
- シェルスクリプトで依存なし

## インストール

```bash
git clone https://github.com/yourusername/mogura.git
cd mogura
./install.sh
```

`~/.local/bin` が PATH に含まれていない場合は、シェル設定に追加:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 使い方

### 1. SSH config にトンネル設定を追加

```plain text
# ~/.ssh/config
Host my-dev-tunnel
    HostName example.com
    User myuser
    IdentityFile ~/.ssh/id_ed25519
    LocalForward 3306 localhost:3306
    LocalForward 6379 localhost:6379
    DynamicForward 1080
```

### 2. mogura に登録

```bash
mogura add dev --host my-dev-tunnel
```

これで自動的に LaunchAgent が作成され、トンネルが開始されます。

### 3. 確認

```bash
# 状態確認
mogura status

# 一覧表示
mogura list

# ログ確認
mogura logs dev
```

## コマンド

| コマンド | 説明 |
|---------|------|
| `mogura add <name> --host <ssh-host>` | トンネル追加・起動 |
| `mogura remove <name>` | トンネル削除 |
| `mogura start <name>` | 開始 |
| `mogura stop <name>` | 停止 |
| `mogura restart <name>` | 再起動 |
| `mogura status [name]` | 状態確認 |
| `mogura list` | 一覧 |
| `mogura enable <name>` | 自動起動有効 |
| `mogura disable <name>` | 自動起動無効 |
| `mogura logs <name>` | ログ表示 |
| `mogura upgrade [name]` | plistを最新設定で再生成 |

## ディレクトリ構成

```plain text
~/.config/mogura/
├── tunnels/              # トンネル設定
│   └── {name}.conf

~/Library/LaunchAgents/
└── com.mogura.tunnel.{name}.plist

~/.local/log/mogura/      # ログ
├── {name}.log
└── {name}.err
```

## 仕組み

1. `mogura add` でトンネル設定ファイルと LaunchAgent plist を生成
2. LaunchAgent がログイン時に自動起動
3. SSH 接続が切れると KeepAlive により自動再接続
4. ネットワーク切断時は待機、復帰時に再接続

### LaunchAgent 設定

- `RunAtLoad: true` - ログイン時自動起動
- `KeepAlive: true` - プロセス終了時に自動再起動
- `ThrottleInterval: 10` - 再起動間隔 10秒

### SSH 接続オプション

- `ServerAliveInterval=15` - 15秒ごとにサーバーに生存確認
- `ServerAliveCountMax=3` - 3回失敗で切断（約45秒で検知）
- `TCPKeepAlive=yes` - TCP層でもキープアライブ

## アンインストール

```bash
./uninstall.sh
```

## ライセンス

MIT
