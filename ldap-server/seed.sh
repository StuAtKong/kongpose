#!bin/bash

# If you wish to add more users/groups, modify the script below
set -e

orgUnits=(mathematicians scientists)
for i in "${orgUnits[@]}"
do
    samba-tool ou create "OU=$i"
done

for i in $( seq 1 5 )
do
   samba-tool group add "test-group-$i"
done

samba-tool group add "oligarchs"

samba-tool user create euclid --uid euclid --surname euclid --userou OU=mathematicians K1ngK0ng
samba-tool user create einstein --surname einstein --uid einstein --userou OU=scientists K1ngK0ng

#samba-tool user create kong_admin --surname kong_admin --uid kong_admin --userou OU=oligarchs K1ngK0ng
#samba-tool user create super --surname super --uid super --userou OU=oligarchs K1ngK0ng

samba-tool user create kong_admin K1ngK0ng
samba-tool user create super K1ngK0ng


users=(User1 User2 Ophelia Desdemona Katherina Hamlet Othello Petruchio MacBeth)
for i in "${users[@]}"
do
    samba-tool user create $i K1ngK0ng
done

samba-tool group addmembers test-group-1 User1,User2,MacBeth
samba-tool group addmembers test-group-2 Ophelia,Desdemona,Katherina
samba-tool group addmembers test-group-3 Hamlet,Othello,Petruchio,MacBeth,Desdemona
samba-tool group addmembers test-group-4 euclid,einstein
samba-tool group addmembers oligarchs kong_admin,super
