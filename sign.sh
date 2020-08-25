#!/bin/sh

basename=example-shib-signer
encrypted_keyfile=`dirname $0`/${basename}.key
cerfile=`dirname $0`/${basename}.cer
schemadir=`dirname $0`/schema

PATH=/usr/bin:/bin

if ( ! xmllint --schema saml-schema-metadata-2.0.xsd --path ${schemadir} --valid --noout ${1} 2>&1 | egrep -q "^${1} validates\$" )
then
    echo ${1} fails to validate 1>&2
    exit 1
fi

tmpdir=`mktemp -d --tmpdir=/dev/shm signXXXXXXXX`
test -d ${tmpdir} || exit 2
trap "rm -rf ${tmpdir}" 0

keyfile=${tmpdir}/`basename ${encrypted_keyfile}`
openssl rsa -in ${encrypted_keyfile} -out ${keyfile}
test -f ${keyfile} || exit 3

if [ -z "${2}" ]; then
    samlsign -s -k ${keyfile} -c ${cerfile} -f ${1}
else
    samlsign -s -k ${keyfile} -c ${cerfile} -f ${1} > ${2}
fi
echo ${1} is successfully signed 1>&2
