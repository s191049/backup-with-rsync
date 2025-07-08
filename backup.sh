#!/bin/bash

# backup_list.csv ファイルを読み込んで、複数のディレクトリをrsyncでバックアップします。
# Linux、およびWSLやGit Bashを導入したWindowsで動作します。

# --- 定数定義 ---
CONFIG_FILE="backup_list.csv"

# --- 事前チェック ---

# 設定ファイルが存在するか確認
if [ ! -f "$CONFIG_FILE" ]; then
    echo "エラー: 設定ファイルが見つかりません: $CONFIG_FILE"
    echo "backup_list.csv.sample をコピーして、backup_list.csv を作成してください。"
    exit 1
fi

# rsyncコマンドがインストールされているか確認
if ! command -v rsync &> /dev/null; then
    echo "エラー: rsyncがインストールされていません。スクリプトを実行するにはrsyncをインストールしてください。"
    exit 1
fi

# --- バックアップ処理ループ ---

echo "設定ファイル '$CONFIG_FILE' を読み込んでバックアップを開始します..."
echo "--------------------------------------------------"

# CSVファイルを1行ずつ読み込む（ヘッダーと空行は無視）
grep -v -e '^#' -e '^
 "$CONFIG_FILE" | while IFS=, read -r SOURCE_DIR DEST_DIR DELETE_FLAG
do
    # 前後の空白を削除
    SOURCE_DIR=$(echo "$SOURCE_DIR" | xargs)
    DEST_DIR=$(echo "$DEST_DIR" | xargs)
    DELETE_FLAG=$(echo "$DELETE_FLAG" | xargs)

    # バックアップ元ディレクトリの存在チェック
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "[スキップ] バックアップ元が見つかりません: $SOURCE_DIR"
        continue
    fi

    # rsyncのオプションを組み立て
    RSYNC_OPTIONS="-avh"
    if [[ "$DELETE_FLAG" == "true" ]]; then
        RSYNC_OPTIONS="$RSYNC_OPTIONS --delete"
        echo "バックアップを実行します（削除オプション有効）:"
    else
        echo "バックアップを実行します（削除オプション無効）:"
    fi

    echo "  元: $SOURCE_DIR"
    echo "  先: $DEST_DIR"

    # バックアップ先ディレクトリが存在しない場合は作成
    mkdir -p "$DEST_DIR"

    # rsyncの実行
    rsync $RSYNC_OPTIONS "$SOURCE_DIR/" "$DEST_DIR/"

    echo "完了しました。"
    echo "--------------------------------------------------"

done

echo "すべてのバックアップ処理が完了しました。"
