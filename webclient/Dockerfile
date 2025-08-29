# **************************************************************************
# i2b2 Webclient Dockerfile
# **************************************************************************
# ベースイメージの指定
ARG I2B2_WEBCLIENT_TAG=latest
FROM i2b2/i2b2-webclient:${I2B2_WEBCLIENT_TAG}

# curlを追加インストールする (ヘルスチェック用)
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# shに実行権限を付与
RUN chmod +x /run-httpd.sh

# Silence AH00558
RUN printf "ServerName localhost\n" > /etc/apache2/conf-available/zz-servername.conf \
 && a2enconf zz-servername