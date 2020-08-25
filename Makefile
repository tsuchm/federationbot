all: idp-metadata.xml fed-metadata.xml

# If you hope to add a SP, invoke the following command:
#	./federationbot --output fed-unsigned.xml --addsp SPID
#
# If you hope to remove a SP, invoke the following command:
#	./federationbot --output fed-unsigned.xml --removesp SPID
#
# If you hope to add a certificate, invoke the following command:
#	./federationbot --output fed-unsigned.xml --addcert CERTFILE
#
# If you hope to remove a certificate, invoke the following command:
#	./federationbot --output fed-unsigned.xml --removecert CERTFILE
#
# After the above process, invoke `make` again.
fed-metadata.xml: fed-unsigned.xml example-shib-signer.key example-shib-signer.cer
	sh sign.sh $< $@

fed-unsigned.xml: FORCE
	perl federationbot --output $@

FORCE:

idp-metadata.xml: idp-metadata.tmpl
	perl federationbot --output $@ --template $<
	xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$'

install: fed-metadata.xml
	scp -p $^ idp.example.jp:/var/www/html/metadata/example-federation.xml
