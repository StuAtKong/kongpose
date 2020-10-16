# LDAP AD Server

### Commands
Start/stop the AD Server:
```shell
make up
make down
```

Perform a search
```
ldapsearch -H "ldap://localhost:389" -D "cn=ophelia,cn=users,dc=ldap,dc=kong,dc=com" -w "damng00dcoffEE" -b "cn=MacBeth,cn=Users,dc=ldap,dc=kong,dc=com"

# extended LDIF
#
# LDAPv3
# base <cn=MacBeth,cn=Users,dc=ldap,dc=kong,dc=com> with scope subtree
# filter: (objectclass=*)
# requesting: ALL
#

# MacBeth, Users, ldap.kong.com
dn: CN=MacBeth,CN=Users,DC=ldap,DC=kong,DC=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: user
cn: MacBeth
instanceType: 4
whenCreated: 20190924172721.0Z
whenChanged: 20190924172721.0Z
uSNCreated: 3884
name: MacBeth
objectGUID:: 3RhUDawOq0yWkKC77G0GlQ==
badPwdCount: 0
codePage: 0
countryCode: 0
badPasswordTime: 0
lastLogoff: 0
lastLogon: 0
primaryGroupID: 513
objectSid:: AQUAAAAAAAUVAAAAKCD1TTHFz4sOegpIXgQAAA==
accountExpires: 9223372036854775807
logonCount: 0
sAMAccountName: MacBeth
sAMAccountType: 805306368
userPrincipalName: MacBeth@ldap.kong.com
objectCategory: CN=Person,CN=Schema,CN=Configuration,DC=ldap,DC=kong,DC=com
pwdLastSet: 132138196411166930
userAccountControl: 512
uSNChanged: 3886
memberOf: CN=test-group-1,CN=Users,DC=ldap,DC=kong,DC=com
memberOf: CN=test-group-3,CN=Users,DC=ldap,DC=kong,DC=com
distinguishedName: CN=MacBeth,CN=Users,DC=ldap,DC=kong,DC=com

# search result
search: 2
result: 0 Success

# numResponses: 2
# numEntries: 1
```
