# backup-with-rsync

`backup_list.csv` ファイルで指定された複数のディレクトリを、`rsync` を使って効率的にバックアップするシェルスクリプトです。
Linux環境および、WSL (Windows Subsystem for Linux) や Git Bash を導入したWindows環境で動作します。

## 主な機能

- **設定ファイルベース**: `backup_list.csv` にバックアップしたい内容を記述するだけで、複数のバックアップを一括で実行できます。
- **差分バックアップ**: `rsync` を利用しているため、変更があったファイルのみを転送する高速な差分バックアップが可能です。
- **柔軟な削除オプション**: バックアップ元で削除されたファイルを、バックアップ先からも削除するかどうか（ミラーリングするかどうか）を設定ごとに選択できます。
- **移動モード**: バックアップ完了後に、元のファイルを削除する「移動モード」をサポートします。

## セットアップ

このプロジェクトを使用するには、以下の手順に従ってください。

### 1. リポジトリのクローン

まず、このリポジトリをローカルにクローンします。

```bash
git clone https://github.com/s191049/backup-with-rsync.git
cd backup-with-rsync
```

### 2. 前提条件

このスクリプトは `rsync` コマンドと `bash` シェルに依存しています。ほとんどのLinux環境にはこれらがデフォルトでインストールされていますが、もしインストールされていない場合は、お使いのOSのパッケージマネージャーを使用してインストールしてください。

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install rsync
```

**CentOS/RHEL:**
```bash
sudo yum install rsync
```

**Windows (WSLまたはGit Bash):**
WSLを使用している場合は、上記Linuxのコマンドを使用できます。Git Bashを使用している場合は、Git for Windowsのインストール時に`rsync`がバンドルされていることがあります。

### 3. 実行権限の付与

`backup.sh` スクリプトを実行可能にするために、権限を付与します。

```bash
chmod +x backup.sh
```

## 使い方

1. **設定ファイルの準備**

   `backup_list.csv.sample` ファイルをコピーして、`backup_list.csv` という名前のファイルを作成します。

   ```bash
   cp backup_list.csv.sample backup_list.csv
   ```

2. **バックアップ設定の編集**

   `backup_list.csv` を開き、バックアップしたいディレクトリの情報を記述します。ファイルの書式は以下の通りです。

   ```csv
   # バックアップ元,バックアップ先,削除オプション,移動オプション
   ```

   - **バックアップ元/先**: 
     - **ディレクトリの中身をバックアップしたい場合**: パスの末尾に `/` を付けてください (例: `/path/to/dir/`)
     - **ディレクトリ自体をバックアップしたい場合**: パスの末尾に `/` を付けないでください (例: `/path/to/dir`)
     - **ファイルをバックアップしたい場合**: ファイル名まで含めて指定し、末尾に `/` を付けないでください (例: `/path/to/file.txt`)
   - **削除オプション** (`true`/`false`):
     - `true`: バックアップ元にないファイルをバックアップ先から削除します（同期）。
     - `false` (または空欄): バックアップ先のファイルは削除しません（追加）。
   - **移動オプション** (`true`/`false`):
     - `true`: バックアップ成功後、バックアップ元のファイルを削除します。
     - `false` (または空欄): バックアップ元のファイルは保持されます。

   ### !!! 警告: 移動オプションについて !!!

   **移動オプションを `true` に設定すると、`rsync` による転送が成功したファイルはバックアップ元から完全に削除されます。** これは、ファイルの「移動」に相当する破壊的な操作です。意図しないデータ損失を防ぐため、このオプションは十分に理解した上で、慎重に使用してください。

   **設定例:**
   ```csv
   # Documentsフォルダの中身を外付けHDDに同期する（元ファイルは保持）
   /home/user/Documents/,/media/user/backup_hdd/Documents/,true,false

   # Picturesフォルダ自体をNASにバックアップする（古い写真は消さない）
   /home/user/Pictures,/mnt/nas/Pictures,false,false

   # Downloadsフォルダの中身をアーカイブ用ディスクに移動する（元ファイルは削除）
   /home/user/Downloads/,/mnt/archive/Downloads/,true,true

   # 特定のファイルをバックアップする
   /home/user/notes.txt,/mnt/backup/my_notes.txt,false,false

   # リモートのファイルをローカルにバックアップする
   user@remote-server:/var/log/syslog,/home/user/backup/syslog.log,false,false
   ```

3. **バックアップの実行**

   以下のコマンドを実行して、バックアップを開始します。

   ```bash
   ./backup.sh
   ```

   スクリプトは `backup_list.csv` の内容を上から順に実行します。

- **リモートバックアップ**: SFTP/SSH経由でリモートサーバー上のファイルやディレクトリをバックアップ元またはバックアップ先として指定できます。

## リモートバックアップの利用

`rsync` はSSHプロトコルを利用してリモートサーバーとの間でファイルを転送できます。これにより、SFTPやSSHでアクセス可能なサーバー上のファイルをバックアップ対象とすることができます。

### パスの指定方法

`backup_list.csv` 内で、バックアップ元またはバックアップ先にリモートパスを指定する場合、以下の形式を使用します。

```
ユーザー名@ホスト名:/path/to/directory
```

**例:**
- ローカルの `Documents` フォルダをリモートサーバーの `/backup/docs` にバックアップ:
  `/home/user/Documents,user@remote-server:/backup/docs,true,false`
- リモートサーバーの `/var/log` をローカルの `backup/logs` にバックアップ:
  `user@remote-server:/var/log,/home/user/backup/logs,false,false`

### 認証について

リモートサーバーへの接続には、SSHキー認証の利用を強く推奨します。これにより、スクリプト実行時にパスワード入力を求められることなく、自動的にバックアップを実行できます。

SSHキー認証を設定するには、お使いのデバイスの公開鍵をリモートサーバーの `~/.ssh/authorized_keys` ファイルに追加する必要があります。通常は `ssh-copy-id user@remote-server` コマンドを使用すると便利です。

---

## 今後の開発予定

- [ ] ログ機能の追加
- [ ] エラーハンドリングの強化
- [ ] dry-run（テスト実行）オプションの追加
- [ ] バックアップ対象除外リストのサポート
