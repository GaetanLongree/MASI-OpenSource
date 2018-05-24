
\c pdns

INSERT INTO pdns.domains (name, type) values ('$TLD_DOMAIN', 'NATIVE');
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$TLD_DOMAIN','$DNS_IP admin.$TLD_DOMAIN 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$TLD_DOMAIN','$DNS_IP','NS',86400,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'mail.$TLD_DOMAIN','$MAIL_IP','A',120,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'webmail.$TLD_DOMAIN','$WEBMAIL_IP','A',120,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$TLD_DOMAIN','mail.$TLD_DOMAIN','MX',120,25);
INSERT INTO pdns.domains (name, type) values ('$TLD_DOMAIN_PTR', 'NATIVE');
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$TLD_DOMAIN_PTR','$TLD_DOMAIN admin.$TLD_DOMAIN 1 10380 3600 604800 3600','SOA',86400,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$TLD_DOMAIN_PTR','$TLD_DOMAIN','NS',86400,NULL);
INSERT INTO pdns.records (domain_id, name, content, type,ttl,prio) VALUES (1,'$MAIL_IP_HOST_ID.$TLD_DOMAIN_PTR','mail.$TLD_DOMAIN','A',120,NULL);