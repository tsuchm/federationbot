# -*- Makefile -*-

all: idp-metadata.xml fed-metadata.xml

update:
	$(MAKE) FORCETARGET=FORCE all

fed-metadata.xml: fed-unsigned.xml example-shib-signer.key example-shib-signer.cer
	sh sign.sh $< $@
	xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$'

fed-unsigned.xml: $(FORCETARGET)
	perl federationbot --output $@
	xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$'

FORCE:

idp-metadata.xml: idp-metadata.tmpl
	perl federationbot --output $@ --template $<
	xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$'

install: fed-metadata.xml
	scp -p $^ idp.example.jp:/var/www/html/metadata/example-federation.xml
