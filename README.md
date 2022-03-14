# ruby-oauth-google-gmail

GMail api を使うために Google Account をOAuthして、access_tokenを取得する

## start

```shell
bundle install 
bundle exec ruby oauth-gmail-localhost.rb
```


## GCP のアプリケーション制限事項

認証情報→OAuthのDesktop クライアントを作成で、Client Secretは生成される。

CopyCodeでコピペで動かす方式は、非推奨になった。

`OOB_URI = "urn:ietf:wg:oauth:2.0:oob"`

```
bundle exec ruby oauth-gmail-copy-code.rb
```
ただし、OAuth同意画面で「内部」で「テスト」で「テストユーザ」を指定すると動く。

コピーコードで動かす場合の情報は、なかなかたどり着かないのでメモとして残す。

