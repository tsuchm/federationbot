# federationbot

証明書の有効期限の短縮により，SP の key rollover 頻度が増大しつつある．また，組織内ユーザに対するアクセス制限を，簡易にアクセス元 IP アドレス範囲で済ませていたサーバが，正確に認証を行う SP として参加する事例が増えつつある．以上の2点より，IdP 運用管理者の作業コストは増大する一方であり，IdP 運用管理作業の自動化が必要である．

## Status of this package

本パッケージは，現在 proof of concept の状態である．

## Assumption of this package

SP は，Let's Encrypt を利用して，サーバ証明書の取得・更新を自動化していること．

## Automatic Procedure of Key Rollover

### Phase 0

* SP の `shibboleth2.xml` は以下の状態である．

```
<CredentialResolver type="File" key="sp-key.pem" certificate="sp-cert.pem"/>
```

### Phase 1

* SP 上で動作する federationbot は `/etc/letsencrypt/archive/hostname/` 以下を検索し，最新のサーバ証明書を得る．
* SP のウェブサーバは，最新のサーバ証明書を使う，
* 最新のサーバ証明書が IdP からダウンロードしたメタデータに含まれていない場合は，`shibboleth2.xml` を以下の状態にする．

```
<CredentialResolver type="Chaining">
     <CredentialResolver type="File" key="new-key.pem" certificate="new-cert.pem" use="encryption"/>
     <CredentialResolver type="File" key="sp-key.pem" certificate="sp-cert.pem"/>
</CredentialResolver>
```

### Phase 2

* 管理者の管理端末上で動作する federationbot は，IdP からダウンロードしたメタデータと，SP からダウンロードしたサーバ証明書を比較する．
* SP が，メタデータに未登録のサーバ証明書を使っている場合は，メタデータに `<KeyDescriptor>` を2つ並列に登録する．

### Phase 3

* SP 上で動作する federationbot は `/etc/letsencrypt/archive/hostname/` 以下を検索し，最新のサーバ証明書を得る．
* Phase 2 により，最新のサーバ証明書と1世代前のサーバ証明書の両方が，IdP からダウンロードしたメタデータに含まれているはずである．その場合，`shibboleth2.xml` を以下の状態にする．

```
<CredentialResolver type="Chaining">
     <CredentialResolver type="File" key="new-key.pem" certificate="new-cert.pem"/>
     <CredentialResolver type="File" key="sp-key.pem" certificate="sp-cert.pem" use="encryption"/>
</CredentialResolver>
```

### Phase 4

* 管理者の管理端末上で動作する federationbot は，IdP からダウンロードしたメタデータの登録内容をチェックし，1週間以内に有効期限が切れる証明書を `<KeyDescriptor>` から削除する．

### Phase 5

* SP 上で動作する federationbot は `/etc/letsencrypt/archive/hostname/` 以下を検索し，最新のサーバ証明書を得る．
* Phase 4 により，1世代前のサーバ証明書はメタデータから削除され，最新のサーバ証明書のみがメタデータに含まれているはずである．その場合，`shibboleth2.xml` を以下の状態にする．

```
<CredentialResolver type="File" key="new-key.pem" certificate="new-cert.pem"/>
```

## Install

### SP

1. 必要なパッケージをインストールする．
   * libhtml-template-perl
   * libtime-parsedate-perl
   * libxml-simple-perl
   * libwww-perl
   * libapache2-mod-shib2
1. スクリプト本体とテンプレートファイルをインストールする．
   * federationbot -> /usr/local/bin/federationbot
   * shibboleth2.tmpl -> /etc/shibboleth/shibboleth2.tmpl
1. 以下のような内容の `/etc/cron.daily/federationbot` を用意する．


```
#!/bin/sh

set -e

hostname=`hostname --fqdn`
confdir=/etc/shibboleth/
templatefile=${confdir}/shibboleth2.tmpl
xmlfile=${confdir}/shibboleth2.xml

/usr/local/bin/federationbot --sphostname ${hostname} --template ${templatefile} --output ${xmlfile}.$$
if ( cmp ${xmlfile} ${xmlfile}.$$ >/dev/null ); then
	rm ${xmlfile}.$$
else
	mv ${xmlfile}.$$ ${xmlfile}
	systemctl restart shibd
fi
```

### IdP


## TODO

1世代前の秘密鍵で，最新の公開鍵を署名する[対策](https://eclipsesource.com/blogs/2016/09/07/tutorial-code-signing-and-verification-with-openssl/)は必要だろうか．
