PERL = perl

all: idp-metadata.xml fed-metadata.xml

# In order to update fed-unsigned.xml, remove the existing version of
# fed-unsigned.xml and invoke `make`.
#
# If you hope to add a SP, invoke the following command:
#	perl fed-metadata-update --output fed-unsigned.xml --add SPID
#
# If you hope to remove a SP, invoke the following command:
#	perl fed-metadata-update --output fed-unsigned.xml --remove SPID
#
# After the above process, invoke `make` again.
fed-metadata.xml: fed-unsigned.xml federationbot-shib-signer.key federationbot-shib-signer.cer
	test ! -f $@ || chmod +w $@
	sh sign.sh $< $@
	( xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$' )||\
	( rm -f $@ ; exit 1 )

fed-unsigned.xml:
	$(PERL) federationbot --output $@
	( xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$' )||\
	( rm -f $@ ; exit 1 )

idp-metadata.xml: ../etc/ssl/certs/federationbot-idp.pem idp-metadata.tmpl
	$(PERL) federationbot --output $@ --template idp-metadata.tmpl
	( xmllint --schema saml-schema-metadata-2.0.xsd --path `pwd`/schema --valid --noout $@ 2>&1 | egrep '^$@ validates$$' )||\
	( rm -f $@ ; exit 1 )
