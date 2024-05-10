#!/usr/bin/env sh

# Description:
# Support pfSense certificate updates

# Required:
#PFSENSE_CERTIFICATE_NAME=""

pfsense_send() {
  _subject="$1"
  _content="$2"
  _statusCode="$3" #0: success, 1: error 2($RENEW_SKIP): skipped
  _debug "_statusCode" "$_statusCode"

  PFSENSE_CERTIFICATE_NAME="${PFSENSE_CERTIFICATE_NAME:-$(_readaccountconf_mutable PFSENSE_CERTIFICATE_NAME)}"
  if [ -z "$PFSENSE_CERTIFICATE_NAME" ]; then
    PFSENSE_CERTIFICATE_NAME=""
    _err "You didn't specify a pfSense certificate name PFSENSE_CERTIFICATE_NAME yet."
    return 1
  fi
  _saveaccountconf_mutable PFSENSE_CERTIFICATE_NAME "$PFSENSE_CERTIFICATE_NAME"

# BEGIN NEW CODE HERE



  export _H1="Content-Type: application/json"

  _content="$(printf "**%s**\n%s" "$_subject" "$_content" | _json_encode)"
  _data="{\"content\": \"$_content\" "
  if [ "$PFSENSE_CONFIG_XML_PATH" ]; then
    _data="$_data, \"username\": \"$PFSENSE_CONFIG_XML_PATH\" "
  fi
  if [ "$PFSENSE_CONFIG_CACHE_PATH" ]; then
    _data="$_data, \"avatar_url\": \"$PFSENSE_CONFIG_CACHE_PATH\" "
  fi
  _data="$_data}"

  if _post "$_data" "$PFSENSE_CERTIFICATE_NAME?wait=true"; then
    # shellcheck disable=SC2154
    if [ "$response" ]; then
      _info "pfsense send success."
      return 0
    fi
  fi
  _err "pfsense send error."
  _err "$response"
  return 1
}
















#!/bin/bash
host="ipaddress"
username="username"
password="password"
certificate="certificate.pem"
privatekey="privatekey.pem"
oldcertificate=$(<certificate.crt.old.txt)
oldprivatekey=$(<certificate.key.old.txt)

mv $certificate $certificate.combo
csplit -f $certificate.part $certificate.combo '/-----BEGIN CERTIFICATE-----/' '{*}'

for file in $certificate.part*;
do echo "Processing $file file..";
output=$(openssl x509 -noout -subject -in $file);
if [[ $output = *CN=*.* ]]
then
        mv $file certificate.pem
fi
if [[ $output = *Authority* ]]
then
        mv $file CA_LetsEncrypt.pem
fi
done

cert=$(base64 $certificate)
cert=$(echo $cert | sed "s/ //g")
key=$(base64 $privatekey)
key=$(echo $key | sed "s/ //g")

sshpass -p $password scp $username@$host:/conf/config.xml config.xml

if grep "$cert" config.xml > /dev/null
then
    echo "Identical certificate found, renewal not required"
else
    echo "Certificate not found, renewal required"
    sed -i -e "s|$oldcertificate|$cert|g" config.xml
    sed -i -e "s|$oldprivatekey|$key|g" config.xml
    echo $cert > certificate.crt.old.txt
    echo $key > certificate.key.old.txt
    sshpass -p $password scp config.xml $username@$host:/conf/config.xml
    sshpass -p $password ssh $username@$host rm /tmp/config.cache
    sshpass -p $password ssh $username@$host /etc/rc.restart_webgui
    find . -size  0 -name $certificate.part* -print0 |xargs -0 rm --
    rm $certificate.combo
    rm certificate.pem
    rm privatekey.pem
    rm CA_LetsEncrypt.pem
    rm config.xml
fi