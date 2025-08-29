# ===============================
# NGINXリバースプロキシ用Dockerfile
# ===============================
# non-rootで動作するように、nginx-unprivilegedイメージを使用します
# なお、uid=101(nginx) gid=101(nginx) groups=101(nginx)です
# 各種ディレクトリにの書き込み権限が必要な場合は、uid=101に付与してください
FROM nginxinc/nginx-unprivileged:stable-alpine3.21-perl

# NGINXの設定ファイルをコンテナにコピー
COPY nginx.conf /etc/nginx/nginx.conf

# NGINXのデフォルトのHTTPポート8080を公開
# ⚠️ nginxはnon-rootユーザーなので、80は使えず、8080を代わりに使います。
EXPOSE 8080

# コンテナ起動時にnginxをフォアグラウンドで起動
CMD ["nginx", "-g", "daemon off;"]

#  === 必要に応じて以下に追加のセットアップを記入してください。===


# =======================================================