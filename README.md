# federationbot

証明書の有効期限の短縮により，SP の key rollover 頻度が増大しつつある．また，組織内ユーザに対するアクセス制限を，簡易にアクセス元 IP アドレス範囲で済ませていたサーバが，正確に認証を行う SP として参加する事例が増えつつある．以上の2点より，IdP 運用管理者の作業コストは増大する一方であり，IdP 運用管理作業の自動化が必要である．

## Status of this package

本パッケージは，現在 proof of concept の状態である．

## Install

### Install for SP

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
idpid=https://idp.example.jp/idp/shibboleth
metadataurl=https://idp.example.jp/metadata/example-federation.xml

/usr/local/bin/federationbot --sphostname ${hostname} --idpid ${idpid} --metadata ${metadataurl} --template ${templatefile} --output ${xmlfile}.$$
if ( cmp ${xmlfile} ${xmlfile}.$$ >/dev/null ); then
	rm ${xmlfile}.$$
else
	mv ${xmlfile}.$$ ${xmlfile}
	systemctl restart shibd
fi
```

### Install for IdP

最初に，必要なパッケージをインストールする．

* libhtml-template-perl
* libtime-parsedate-perl
* libxml-simple-perl
* libwww-perl
* libxml2-utils (xmllint を利用する場合)
* opensaml-tools (samlsign を利用する場合)

次に，サンプルの `federationbot.sample-conf` を各自の環境に合わせて編集し，`federationbot.conf` という名前で保存する．
この段階で，`federationbot` が実行できるようになっているはずである．

```
federationbot
```

この実行結果が，現用中のメタデータと一致するように `fed-metadata.tmpl` を修正する．

最後に，生成されたメタデータを実際の IdP に配置するスクリプトを書く．
筆者のサイトで使っているスクリプトを単純化したバージョンが `Makefile` にある．


## Maintenance of Metadata

定期的(例えば，毎月1日と15日)に `federationbot` を実行して，メタデータを更新する，という使い方が想定されている．

SP の証明書が Let's Encrypt で定期的に更新されている場合は，自動的に新バージョンの証明書を検出し，旧バージョンの証明書は破棄される．

SP の証明書が手動更新されている場合は，適当なオプションを指定して `federationbot` を手動実行する必要がある．

* `--addcert FILE`
  * 指定された証明書を，当該証明書の主体者名と同一の主体者名の証明書を使っている SP に追加する．すなわち，`<KeyDescriptor>` が2つ並列に存在している状態になる．
* `--removecert FILE`
  * 指定された証明書を，当該証明書の主体者名と同一の主体者名の証明書を使っている SP から削除する．

また，組織内フェデレーションの SP が変化する場合は，以下のオプションが利用できる．

* `--addsp ID`
  * 指定された ID を持つ SP を追加する．証明書は，SP 上で動作しているウェブサーバからダウンロードする．
* `--removesp ID`
  * 指定された ID を持つ SP を削除する．

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

## TODO

1世代前の秘密鍵で，最新の公開鍵を署名する[対策](https://eclipsesource.com/blogs/2016/09/07/tutorial-code-signing-and-verification-with-openssl/)は必要だろうか．
