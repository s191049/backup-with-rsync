#!/bin/bash

# backup_list.csv ファイルを読み込んで、複数のディレクトリをrsyncでバックアップします。
# Linux、およびWSLやGit Bashを導入したWindowsで動作します。

# --- 設定ファイルの読み込み ---
CONFIG_FILE_NAME="backup_config.sh"
CONFIG_FILE_SAMPLE_NAME="backup_config.sh.sample"
CONFIG_FILE_PATH="$(dirname "$0")"/$CONFIG_FILE_NAME
CONFIG_FILE_SAMPLE_PATH="$(dirname "$0")"/$CONFIG_FILE_SAMPLE_NAME

# 設定ファイルが存在しない場合はサンプルからコピー
if [ ! -f "$CONFIG_FILE_PATH" ]; then
    echo "設定ファイルが見つかりません: $CONFIG_FILE_PATH。サンプルからコピーします。"
    cp "$CONFIG_FILE_SAMPLE_PATH" "$CONFIG_FILE_PATH"
fi

# 設定ファイルを読み込み
if [ -f "$CONFIG_FILE_PATH" ]; then
    source "$CONFIG_FILE_PATH"
else
    echo "エラー: 設定ファイルの読み込みに失敗しました: $CONFIG_FILE_PATH。スクリプトを終了します。"
    exit 1
fi

# --- 定数定義 ---
CONFIG_FILE="backup_list.csv"
SCRIPT_VERSION="0.1.0" # スクリプトのバージョン

# --- 関数定義 ---

# 最新バージョンをチェックし、更新を促す
check_for_updates() {
    if [ -z "$UPDATE_CHECK_URL" ]; then
        echo "警告: UPDATE_CHECK_URLが設定されていません。自動更新チェックをスキップします。"
        return
    fi

    if ! command -v curl &> /dev/null; then
        echo "警告: curlがインストールされていません。自動更新チェックをスキップします。"
        return
    fi
    if ! command -v jq &> /dev/null; then
        echo "警告: jqがインストールされていません。自動更新チェックをスキップします。"
        echo "最新バージョンチェックにはjqが必要です。インストールしてください: sudo apt install jq"
        return
    fi

    echo "最新バージョンをチェックしています..."
    LATEST_RELEASE=$(curl -s "$UPDATE_CHECK_URL")
    if [ $? -ne 0 ]; then
        echo "エラー: 最新リリース情報の取得に失敗しました。"
        return
    fi

    LATEST_VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name // .name' | sed 's/^v//') # 'v'プレフィックスを削除
    if [ -z "$LATEST_VERSION" ]; then
        echo "エラー: 最新バージョン情報の解析に失敗しました。"
        return
    fi

    if [[ "$(printf '%s\n' "$SCRIPT_VERSION" "$LATEST_VERSION" | sort -V | head -n 1)" != "$SCRIPT_VERSION" ]]; then
        echo -e "\n--------------------------------------------------"
        echo -e "\033[0;32m新しいバージョン ($LATEST_VERSION) が利用可能です！\033[0m"
        echo "現在のバージョン: $SCRIPT_VERSION"
        echo "ダウンロードURL: $(echo "$LATEST_RELEASE" | jq -r '.html_url')"
        read -p "今すぐ更新しますか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            perform_update "$LATEST_VERSION"
        fi
        echo "--------------------------------------------------"
    else
        echo "スクリプトは最新バージョンです ($SCRIPT_VERSION)。"
    fi
}

# スクリプトを更新する
perform_update() {
    local LATEST_VERSION_TAG="$1"
    local SCRIPT_URL="https://raw.githubusercontent.com/s191049/backup-with-rsync/$LATEST_VERSION_TAG/backup.sh"
    local TEMP_SCRIPT="/tmp/backup.sh.new"

    echo "スクリプトを更新しています..."
    if curl -s -L "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
        if [ -s "$TEMP_SCRIPT" ]; then # ダウンロードされたファイルが空でないことを確認
            chmod +x "$TEMP_SCRIPT"
            mv "$TEMP_SCRIPT" "$(dirname "$0")"/backup.sh"
            echo -e "\033[0;32mスクリプトがバージョン $LATEST_VERSION_TAG に更新されました！\033[0m"
            echo "更新を適用するため、スクリプトを再実行してください。"
            exit 0 # 更新後、現在のスクリプトは終了
        else
            echo "エラー: ダウンロードされたスクリプトファイルが空です。"
            rm -f "$TEMP_SCRIPT"
        fi
    else
        echo "エラー: 新しいスクリプトのダウンロードに失敗しました。"
    fi
}

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

# 自動更新チェック
if [[ "$AUTO_UPDATE_ENABLED" == "true" ]]; then
    check_for_updates
fi

# --- バックアップ処理ループ ---

echo "設定ファイル '$CONFIG_FILE' を読み込んでバックアップを開始します..."
echo "--------------------------------------------------"

# CSVファイルを1行ずつ読み込む（ヘッダーと空行は無視）
grep -v -e '^#' -e '^$' "$CONFIG_FILE" | while IFS=, read -r SOURCE_DIR DEST_DIR DELETE_FLAG MOVE_FLAG
do
    # 前後の空白を削除
    SOURCE_DIR=$(echo "$SOURCE_DIR" | xargs)
    DEST_DIR=$(echo "$DEST_DIR" | xargs)
    DELETE_FLAG=$(echo "$DELETE_FLAG" | xargs)
    MOVE_FLAG=$(echo "$MOVE_FLAG" | xargs)

    

    # rsyncのオプションを組み立て
    RSYNC_OPTIONS="-avh"
    DESCRIPTION="バックアップ"

    if [[ "$DELETE_FLAG" == "true" ]]; then
        RSYNC_OPTIONS="$RSYNC_OPTIONS --delete"
        DESCRIPTION="$DESCRIPTION（同期）"
    else
        DESCRIPTION="$DESCRIPTION（追加）"
    fi

    if [[ "$MOVE_FLAG" == "true" ]]; then
        RSYNC_OPTIONS="$RSYNC_OPTIONS --remove-source-files"
        DESCRIPTION=""$DESCRIPTION" 後に元ファイルを削除（移動）します"
        if [[ "$CONFIRM_MOVE_MODE" == "true" ]]; then
            printf "\033[0;31m[警告] 移動モードが有効です。処理後に元のファイルが削除されます。\033[0m\n"
            printf "続行しますか？ [y/N]: "
            read -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "移動モードでの処理をキャンセルしました。"
                continue # 次のバックアップ項目へ
            fi
        else
            echo -e "\033[0;31m[警告] 移動モードが有効です。処理後に元のファイルが削除されます。（確認プロンプトは無効）\033[0m"
        fi
    fi

    echo "処理を開始します: $DESCRIPTION"
    echo "  元: $SOURCE_DIR"
    echo "  先: $DEST_DIR"

    

    # rsyncの実行
    rsync $RSYNC_OPTIONS "$SOURCE_DIR" "$DEST_DIR"

    echo "完了しました。"
    echo "--------------------------------------------------"

done

echo "すべてのバックアップ処理が完了しました。"