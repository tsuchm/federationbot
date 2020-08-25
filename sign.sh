#!/bin/sh

# Invoke the following commands to prepare the key to sign your metadata:
#     openssl req -newkey rsa:2048 -keyout example-shib-signer.key -keyform PEM -out example-shib-signer.req -outform PEM
#     openssl x509 -in example-shib-signer.req -out example-shib-signler.pem -req -signkey example-shib-signer.key -days 3650

basename=example-shib-signer
encrypted_keyfile=`dirname $0`/${basename}.key
cerfile=`dirname $0`/${basename}.cer
schemadir=`dirname $0`/schema

PATH=/usr/bin:/bin

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
