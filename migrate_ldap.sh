#! /usr/bin/bash

source ./migrate_ldap.conf;


function readData() {

        [ -f domains.txt ] && (rm domains.txt)
        [ -f service_packages.txt ] && (rm service_packages.txt)
        [ -d People ] && (rm -r People)

########## READ DOMAINS ########################
        ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b o=isp -s one sunPreferredDomain=* sunPreferredDomain o sunnumgroups sunnumusers maildomaindiskquota mailclientattachmentquota preferre
dLanguage mailDomainCatchAllAddress associatedDomain sunavailableservices > domains.txt;
        grep ^o: domains.txt | awk '{ print $2 }' > o_list.txt;

########## READ PEOPLE ########################
        mkdir People;
        (while read i; do
                echo "$i";
                j=`echo "$i" | sed -e 's/ //g'`; #jer $i nije zgodan za ime fajla, zbog mogucih razmaka...
                ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b "ou=People,o=$i,o=isp" uid=* > "People/$j";
        done;)< o_list.txt;

########## READ SERVICE PACKAGES #############
        ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b o=cosTemplates,o=isp "(&(cn=adefault*)(|(objectClass=*)(objectClass=ldapsubentry)))" > service_packages.txt
}

function prepareInputFiles() {

        [ -f domain_blocks.txt ] && (rm domain_blocks.txt)
        [ -f domain_blocks_mod.txt ] && (rm domain_blocks_mod.txt)
        [ -f serial_domains.txt ] && (rm serial_domains.txt)
        [ -f ready_domains.txt ] && (rm ready_domains.txt)
        [ -f serial_domains_mod.txt ] && (rm serial_domains_mod.txt)
        [ -f ready_domains_mod.txt ] && (rm ready_domains_mod.txt)
        [ -f ready_service_packages.txt ] && (rm ready_service_packages.txt)

######### DOMAIN INPUT FILES ##################################
        cat domains.txt | sed -e '/^sunavailableservices:\ /d' -e '/^dn:\ /d' -e 's/sunPreferredDomain://g' -e 's/o://g' -e 's/ //g' > domain_blocks.txt;
        cat domains.txt | egrep '^sunPreferredDomain:|^sunavailableservices:|^$' | sed -e 's/sunPreferredDomain://g' -e 's/ //g'> domain_blocks_mod.txt;
        ./create_input_string.sh domain_blocks.txt > serial_domains.txt;
        ./create_input_string_modify.sh domain_blocks_mod.txt > serial_domains_mod.txt;

for j in `iterate $DELETE_DOMAINS`; do
                grep -v ^"-d $j " serial_domains.txt > ready_domains.txt;
                cp ready_domains.txt serial_domains.txt;
                grep -v ^"-d $j " serial_domains_mod.txt > ready_domains_mod.txt;
                cp ready_domains_mod.txt serial_domains_mod.txt;
        done;

######### SERVICE PACKAGES INPUT FILES #############################
        ./addLine.sh < service_packages.txt > ready_service_packages.txt
        #./changeLine.sh < service_packages_tmp.txt > ready_service_packages.txt
        rm service_packages_tmp.txt;
        echo "" >> ready_service_packages.txt
        echo "" >> ready_service_packages.txt

######### PEOPLE INPUT FILES #############################
        for p in `ls People`; do
                deleteLines $REMOVE_USR_ATTR People/$p > People/"ready_$p";
        done;
}

function createSPs() {
  if [ -f ready_service_packages.txt ];
  then
    ldapmodify -h $TARGET_LDAP_HOST -p 389 -D "cn=Directory Manager" -w $TARGET_DM_PWD -f ready_service_packages.txt
  else
    echo "ready_service_packages.txt doesn't exist"
  fi
}

function createDomains() {
if [ -f ready_domains.txt ];
  then
  (while read x; do
    echo $x;
    /opt/SUNWcomm/bin/commadmin domain create -D admin -n comms5.ptt.rs -w $TARGET_DM_PWD -S mail,cal -H shost.comms5.ptt.rs -T "Europe/Paris" $x
  done
  )<ready_domains.txt
  else
    echo "ready_domains.txt doesn't exist"
  fi
}

function modifyDomains() {
if [ -f ready_domains_mod.txt ];
  then
  (while read x; do
    echo $x;
    /opt/SUNWcomm/bin/commadmin domain modify -D admin -n comms5.ptt.rs -w $TARGET_DM_PWD $x
  done
  )<ready_domains_mod.txt
  else
    echo "ready_domains_mod.txt doesn't exist"
  fi
}

function iterate() {
        echo $1 | awk -F: '{ for (i = 0; ++i <= NF;) print $i }';
}

function deleteLines() {
echo $1 | sed -e 's/:/: |/g' | sed -e 's/|/|^/g' | sed -e 's/^/^/g' -e 's/$/: /g' > tmp_pattern
egrep -v -f tmp_pattern  $2
rm tmp_pattern;
}




function process() {
  clear
  echo "1 - all functions\n 2 - preparePackages\n3 - readData\n4 - prepareInputFiles\n5 - createDomains\n6 - modifyDomains . . ."
  read number
  case $number in
  "1") preparePackages; readData; prepareInputFiles; createDomains; modifyDomains; end;;
  "2") preparePackages; end;;
  "3") readData; end;;
  "4") prepareInputFiles; end;;
  "5") createDomains; end;;
  "6") modifyDomains; end;;
  "*") end; end;;
  esac
}

function end() {
        echo "Hoces li da zavrsis? de/ne"
        read EXIT
        if [ $EXIT = "da" ];
then
        return
else
        process
fi
}

main() {
        readData
        prepareInputFiles
  #createSPs
  #createDomains
  #modifyDomains
  #process
}
main "$@"
