#! /usr/bin/bash

source ./migrate_ldap.conf;


function readData() {

        [ -f domains.txt ] && (rm domains.txt)
        [ -f service_packages.txt] && (rm service_packages.txt)
        [ -d People ] && (rm -r People)

########## READ DOMAINS ########################
        ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b o=isp -s one sunPreferredDomain=* sunPreferredDomain o sunnumgroups sunnumusers maildomaindiskquota mailclientattachmentquota preferre
dLanguage mailDomainCatchAllAddress associatedDomain sunavailableservices > domains.txt;

########## READ PEOPLE ########################
        mkdir People;
        (while read i; do
                echo "$i";
                j=`echo "$i" | sed -e 's/ //g'`; #jer $i nije zgodan za ime fajla, zbog mogucih razmaka...
                ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b "ou=People,o=$i,o=isp" uid=* > "People/$j";
        done;)< o_list.txt;

########## READ SERVICE PACKAGES #############
        ldapsearch -h $SOURCE_LDAP_HOST -p 389 -1 -T -D "cn=Directory Manager" -w $SOURCE_DM_PWD -b o=mailcalendaruser,o=cosTemplates,o=isp "(&(cn=adefault*)(|(objectClass=*)(objectClass=ldapsubentry)))" > service_packages.txt
}

function prepareInputFiles() {

        [ -f domain_blocks.txt ] && (rm domain_blocks.txt)
        [ -f domain_blocks_mod.txt ] && (rm domain_blocks_mod.txt)
        [ -f serial_domains.txt ] && (rm serial_domains.txt)
        [ -f ready_domains.txt ] && (rm ready_domains.txt)
        [ -f serial_domains_mod.txt ] && (rm serial_domains_mod.txt)
        [ -f ready_domains_mod.txt ] && (rm ready_domains_mod.txt)
        [ -f ready_service_packages.txt] && (rm ready_service_packages.txt)

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
        ./addLine.sh < service_packages.txt > service_packages_tmp.txt
        ./changeLine.sh< service_packages_tmp.txt > ready_service_packages.txt
        rm service_packages_tmp.txt;
        echo "" >> ready_service_packages.txt
        echo "" >> ready_service_packages.txt

}
