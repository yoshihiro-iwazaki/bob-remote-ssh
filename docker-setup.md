# リモート環境 (Docker) セットアップ手順

IBM Bob の接続先になる「SSH でログインできる Linux ホスト」を Docker コンテナで用意する。
ここが終わったら [bob-remote-ssh.md](bob-remote-ssh.md) に進む。

```
IBM Bob ── SSH 127.0.0.1:2222 ──▶ コンテナ bob-remote-host (Ubuntu 24.04 / x86_64)
```

- ユーザー `bob` (公開鍵認証のみ・sudo 可)
- `127.0.0.1` にのみ公開し、LAN からは到達できない
- コンテナは x86_64 (linux/amd64) で動かす。Bob のサーバーは linux/arm64 版が配布されていないため
  (Bob 1.126.0+bob2.2.3 の配布 URL で、x64 は取得でき arm64 は 404 になることを確認済み)

> **`<PROJECT_DIR>` について**: 手順中の `<PROJECT_DIR>` は、このリポジトリを置いたディレクトリの絶対パスを表す。
> 自分の環境に合わせて書き換えること (例: Mac `/Users/taro/work/remote-server_bob` / Windows `~/remote-server_bob`)。

自分の OS の節だけを上から順に行う。

- [Mac の場合](#mac-の場合) (M1〜M5)
- [Windows の場合](#windows-の場合) (W1〜W6)

---

## Mac の場合

### 前提

- Apple Silicon の Mac (Intel Mac ではコンテナがそのまま x86_64 で動くので M1 は不要)
- Docker Desktop または Colima がインストール済みであること
- コマンドはすべてこのリポジトリのディレクトリで実行する

```sh
cd <PROJECT_DIR>
```

### M1. Rosetta を有効にする (初回のみ)

```sh
colima stop
colima start --vz-rosetta --cpu 4 --memory 8
```

- Apple Silicon ではコンテナを x86 エミュレーションで動かすことになる。Rosetta にすると速く安定する
- Colima を再起動すると、他のコンテナも一度止まる
- Docker Desktop の場合は Settings → General → "Use Rosetta for x86_64/amd64 emulation" を ON

### M2. SSH 鍵を作る (初回のみ)

```sh
ssh-keygen -t ed25519 -f ssh/bob_remote_key -N ""
```

### M3. SSH 接続設定を作る (初回のみ)

ひな形をコピーする。

```sh
cp ssh/config.example ssh/config
```

`ssh/config` をエディタで開き、`<PROJECT_DIR>` (2 か所) を自分のパスに書き換えて保存する。今いるディレクトリの絶対パスは `pwd` で確認できる。

書き換え例 (`/Users/taro/work/remote-server_bob` に置いた場合):

```sshconfig
  IdentityFile /Users/taro/work/remote-server_bob/ssh/bob_remote_key
  UserKnownHostsFile /Users/taro/work/remote-server_bob/ssh/known_hosts
```

パスにスペースを含む場合は `"…"` で囲む。

### M4. コンテナを起動する

```sh
docker compose up -d --build
docker compose ps
```

`STATUS` が `Up`、`PORTS` が `127.0.0.1:2222->2222/tcp` なら OK。初回のビルドは数分かかる。

### M5. 接続を確認する

```sh
ssh -F ssh/config bob-docker-demo 'whoami; uname -m'
```

`bob` と `x86_64` が表示されれば OK。
初回だけ `Warning: Permanently added '[127.0.0.1]:2222' ...` と出るが正常。

---

## Windows の場合

> **未検証の注意**: Windows の手順は Mac 上での検証をもとに作成しており、Windows 実機では未確認。
> 各手順の「OK」の条件を確認しながら進め、合わないときは末尾の「うまくいかないとき」を見ること。

### 前提

- x64 版の Windows 10 / 11 (ARM 版 Windows は対象外)
- Docker Desktop for Windows がインストール済み
  (大企業での利用は有償サブスクリプションが必要な場合がある。社内のルールを確認すること。
  Mac 版で使える Colima は Windows 非対応)
- コマンドはすべて **PowerShell** で実行する

### W1. ファイルを配置する (初回のみ)

リポジトリを **`%USERPROFILE%` (例: `C:\Users\<ユーザー名>`) 配下** の好きな場所に置く (例: `%USERPROFILE%\remote-server_bob`)。

```
remote-server_bob\
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── sshd\remote-dev.conf
└── ssh\config_windows.example
```

- 動かすのに必要なのは上の 5 ファイル (手順書の `docker-setup.md` / `bob-remote-ssh.md` は任意)。
  他人の個人用ファイル (`ssh\config`、`ssh\config_windows`、`ssh\bob_remote_key`、`ssh\bob_remote_key.pub`、`ssh\known_hosts`) は持ってこない (W3・W4 で自分用を作る)
- `%USERPROFILE%` 配下に置くこと。`C:\` 直下などに置くと秘密鍵に他のユーザーのアクセス権が付き、Windows の OpenSSH が鍵の使用を拒否する

以降のコマンドはすべてこのフォルダーで実行する。

```powershell
cd <PROJECT_DIR>
```

### W2. Docker と SSH を確認する (初回のみ)

Docker Desktop を起動してから実行する。

```powershell
docker version --format '{{.Server.Os}}/{{.Server.Arch}}'
docker compose version
ssh -V
```

1 行目が `linux/amd64`、残り 2 つがバージョンを表示すれば OK。

- `docker` でエラーになる: Docker Desktop が起動しきっていない。起動完了を待って再実行する
- 1 行目が `windows/amd64`: Docker Desktop が Windows コンテナーモードになっている。タスクトレイの Docker アイコンを右クリック → `Switch to Linux containers...`
- `ssh` が見つからない: OpenSSH クライアントを追加する
  (Windows 11: 設定 → システム → オプション機能 / Windows 10: 設定 → アプリ → オプション機能 → 「OpenSSH クライアント」)

Windows (x64) ではコンテナがそのまま x86_64 で動くので、Mac の M1 (Rosetta) に当たる手順は不要。

### W3. SSH 鍵を作る (初回のみ)

```powershell
ssh-keygen -t ed25519 -f ssh\bob_remote_key
```

パスフレーズを聞かれたら、**何も入力せずに Enter を 2 回** 押す。
`ssh\bob_remote_key` と `ssh\bob_remote_key.pub` ができれば OK。

(PowerShell 5.1 では `-N ""` の空文字が ssh-keygen に渡らないため、Enter で空にする)

### W4. SSH 接続設定を作る (初回のみ)

ひな形をコピーする。

```powershell
Copy-Item ssh\config_windows.example ssh\config_windows
```

`ssh\config_windows` をエディタで開き、`<PROJECT_DIR>` (2 か所) を自分のパスに書き換えて保存する。

書き換え例 (`%USERPROFILE%\remote-server_bob` に置いた場合):

```sshconfig
  IdentityFile ~/remote-server_bob/ssh/bob_remote_key
  UserKnownHostsFile ~/remote-server_bob/ssh/known_hosts
```

- 区切りは `\` ではなく `/` を使う
- `~` は `%USERPROFILE%` を表す。ユーザー名に日本語を含む場合は `C:/Users/...` ではなく `~/...` の形で書く
- パスにスペースを含む場合は `"…"` で囲む

### W5. コンテナを起動する

```powershell
docker compose up -d --build
docker compose ps
```

`STATUS` が `Up`、`PORTS` が `127.0.0.1:2222->2222/tcp` なら OK。初回のビルドは数分かかる。

### W6. 接続を確認する

```powershell
ssh -F ssh\config_windows bob-docker-demo 'whoami; uname -m'
```

`bob` と `x86_64` が表示されれば OK。
初回だけ `Warning: Permanently added '[127.0.0.1]:2222' ...` と出るが正常。

---

## 片付け

```sh
docker compose down      # コンテナを削除 (-v を付けると workspace も削除)
```

Bob 側の設定の片付けは [bob-remote-ssh.md](bob-remote-ssh.md) の「片付け」を参照。

---

## うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| `no such identity: <PROJECT_DIR>/...` / `Failed to add the host to the list of known hosts` | `ssh/config` (Windows: `ssh\config_windows`) の `<PROJECT_DIR>` が書き換わっていないか、パスが間違っている。M3 / W4 を見直す |
| `REMOTE HOST IDENTIFICATION HAS CHANGED!` | 再ビルドでホスト鍵が変わった。Mac: `rm ssh/known_hosts` / Windows: `Remove-Item ssh\known_hosts` |
| `Connection refused` / タイムアウト | コンテナが止まっている (Colima や Docker Desktop の再起動後など)。Docker が起動しているか確認し、`docker compose up -d` |
| `Permission denied (publickey)` | 上の `no such identity` も出ていればパスの誤り (M3 / W4)。出ていなければ鍵を作り直した後の再ビルド漏れなので `docker compose up -d --build` |
| `uname -m` が `aarch64` になる | amd64 で起動していない。`compose.yaml` の `platform: linux/amd64` を確認して `docker compose up -d --build` |
| (Windows) `docker` / `ssh` でエラーになる | W2 を見直す |
| (Windows) `docker compose up` で `Ports are not available` / `access permissions` | 2222 番が Windows の予約ポート範囲に入っている可能性がある。`netsh interface ipv4 show excludedportrange protocol=tcp` で確認し、範囲内なら `compose.yaml` の `"127.0.0.1:2222:2222"` の真ん中の数字と `ssh\config_windows` の `Port` を空いている番号 (例: `22222`) に変える。bob-remote-ssh.md の手順 1 で `.ssh\config` に追記した `Port` も変える |
| (Windows) `UNPROTECTED PRIVATE KEY FILE!` / `Bad permissions` | 秘密鍵に他のユーザーのアクセス権が付いている。リポジトリを `%USERPROFILE%` 配下 (W1) に置き直すのが確実。その場で直すなら `icacls ssh\bob_remote_key /inheritance:r /grant:r "$(whoami):(F)"` |

構成の詳細と元記事との違いは [README.md](README.md) を参照。
