# ===============================
# PostgreSQL用Dockerfile
# ===============================
# 公式i2b2 postgresイメージでは、Docker imageの最後のレイヤーに CMD["supervisord"] があるため、
# entrypoint.sh使ったり、CMDを上書きしたりするには注意が必要です。基本的にこれらは上書きしない方が安全です。
# もし必要な場合、元のイメージのコマンドが実行されるよう注意してください。
# (これはタグ=v1.8.1a-20250421で確認しています。将来のバージョンで変更される可能性があります。)

# 公式i2b2 DockerイメージをベースにしたPostgreSQL用のDockerfileを作成します
ARG I2B2_DATA_PGSQL_TAG=latest
FROM i2b2/i2b2-data-pgsql:${I2B2_DATA_PGSQL_TAG}

# Postgresの追加設定ファイルをコンテナにコピー
# (/etc/postgresql/16/main/conf.dはtag=v1.8.1a-20250421で存在を確認しています。違うimageを使う場合は、一応確認してください。)
COPY custom_postgresql.conf /etc/postgresql/16/main/conf.d/custom_postgresql.conf

# Postgresのログ保存用ディレクトリを作成
RUN mkdir -p /var/log/postgresql

#  === 必要に応じて以下に追加のセットアップを記入してください。===


# =======================================================

# ベースイメージは以下のCMDを持っていることを忘れずに。
# CMD["supervisord"]