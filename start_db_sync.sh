#!/bin/bash


function usage()
{
    cat << HEREDOC

    arguments:
      -n --network        network - possible options: allegra, launchpad, mary-qa, shelley-qa, mainnet, staging, testnet

    optional arguments:
      -h --help           show this help message and exit

Example:

./db.sh -n shelley-qa

DO NOT USE UNDERSCORES IN NETWORK NAMES FOR THIS SCRIPT !!!
HEREDOC
}

function show_tips()
{
cat << EOF

Useful Information:

Before starting db-sync or db-sync-extended you might need to drop database first:

psql -U postgres

List DBs:
\l

Get the name from the list and drop DB:
DROP DATABASE db_name

Exit from postgresql:
\q


In order to create DB and run it for specified network use:

MAINNET:

PGPASSFILE=config/pgpass-mainnet scripts/postgresql-setup.sh --createdb

PGPASSFILE=config/pgpass-mainnet db-sync-node/bin/cardano-db-sync \
--config config/mainnet-config.yaml \
--socket-path ../cardano-node/mainnet/node.socket \
--state-dir ledger-state/mainnet \
--schema-dir schema/


SHELLEY QA :

PGPASSFILE=config/pgpass-shelley-qa scripts/postgresql-setup.sh --createdb

PGPASSFILE=config/pgpass-shelley-qa db-sync-node-extended/bin/cardano-db-sync-extended \
--config config/shelley-qa-config.yaml \
--socket-path ../cardano-node/shelley_qa/node.socket \
--state-dir ledger-state/shelley_qa \
--schema-dir schema/


MARY QA :

PGPASSFILE=config/pgpass-mary-qa scripts/postgresql-setup.sh --createdb

PGPASSFILE=config/pgpass-mary-qa db-sync-node-extended/bin/cardano-db-sync-extended \
--config config/mary-qa-config.yaml \
--socket-path ../cardano-node/mary_qa/node.socket \
--state-dir ledger-state/mary_qa \
--schema-dir schema/


To build with cabal you might need first run:

cabal update

It is only needed ocassionally (once a month or so), then build:

cabal build all

and run executable with:

PGPASSFILE=config/pgpass-mainnet cabal run cardano-db-sync-extended -- \
--config config/mainnet-config.yaml \
--socket-path ../cardano-node/mainnet/node.socket \
--state-dir ledger-state/mainnet \
--schema-dir schema/

//////////////////////////////

MODIFIED_NETWORK_NAME=$(echo "${network}" | sed 's/-/_/')

PGPASSFILE=config/pgpass-${network} scripts/postgresql-setup.sh --createdb

PGPASSFILE=config/pgpass-${network} db-sync-node-extended/bin/cardano-db-sync-extended \
--config config/${network}-config.yaml \
--socket-path ../cardano-node/${MODIFIED_NETWORK_NAME}/node.socket \
--state-dir ledger-state/${MODIFIED_NETWORK_NAME} \
--schema-dir schema/

//////////////////////////////

EOF
}


environment=$1


function get_network_value()
{

if [ "$environment" = "mainnet"  ] 
then
    echo "--mainnet"

elif [ "$environment" = "testnet" ]
then
    echo "--testnet-magic 1097911063"

elif [ "$environment" = "staging" ]
then    
    echo "--testnet-magic 633343913"

elif [ "$environment" = "shelley_qa" ]
then
    echo "--testnet-magic 3"

else:
    echo "" 

fi
}

network_param=$(get_network_value)

echo "network_param: $network_param"


cd ../cardano-db-sync
mkdir logs

cardano_db_sync_exe="$(cat $CABAL_BUILDDIR/cache/plan.json | jq -r '."install-plan"[] | select(."component-name" == "exe:cardano-db-sync") | ."bin-file"' | head)"
echo "Executable found at: $cardano_db_sync_exe"

chmod 600 config/pgpass-${environment}
PGPASSFILE=config/pgpass-${environment} scripts/postgresql-setup.sh --createdb

#echo "checking above dir structure:"
#ls -l ../

#echo "checking 2x above dir structure:"
#ls -l ../../



db_sync_start_time=$(echo "$(date +'%d/%m/%Y %H:%M:%S')")
echo "db_sync_start_time: $db_sync_start_time"
# 17/02/2021 23:42:12

PGPASSFILE=config/pgpass-${environment} cabal run cardano-db-sync-extended -- \
--config config/${environment}-config.yaml \
--socket-path ../cardano-node/${environment}/node.socket \
--state-dir ledger-state/${environment} \
--schema-dir schema/ >> logs/db_sync_logfile.log & 

# If this is commented db-sync will start
# >> logs/db_sync_logfile.log & 

# wait for db-sync to start
sleep 60

echo "Before cat logs/db_sync_logfile.log"
ls -l
cat logs/db_sync_logfile.log
echo "After cat logs/db_sync_logfile.log"


#echo "Before tail"
#tail -n 1 logs/db_sync_logfile.log
#echo "After tail"


function get_latest_db_synced_slot()
{
IN=$(tail -n 1 logs/db_sync_logfile.log)
preformated_string=$(echo "$IN" | sed 's/^.*slot/slot/') # this will return this: slot 19999, block 20000, hash 683be7324c47df71e2a234639a26d7747f1501addbba778636e66f3a18a46db7
IFS=' ' read -ra ADDR <<< "$preformated_string"
for i in "${!ADDR[@]}"; do
    if [[ "${ADDR[$i]}" == *"slot"* ]]; then # check for this: "slot 19999," - from this we need to get the second part - slot number and remove comma
       slot_number=$(echo "${ADDR[$((i+1))]}"| sed 's/.$//') # use sed to remove comma at the end of slot number
       echo $slot_number
    fi
done
}


function get_block_from_tip()
 {
 ./../cardano-node/cardano-cli query tip ${network_param} |
 
 while read -r line
 do
   if [[ $line == *"block"* ]]; then
      IFS=' ' read -ra ADDR <<< "$line"
      echo "${ADDR[1]}" | sed 's/.$//'
   fi
 done
 }


function calculate_slot_for_environment()
 {


if [ "$environment" = "mainnet"  ] 
then
        byron_start_time_in_seconds=1506203091 # 2017-09-23 21:44:51 
        shelley_start_time_in_seconds=1596059091 # 2020-07-29 21:44:51
        allegra_start_time_in_seconds=1608155091 # 2020-12-16 21:44:51 
        
elif [ "$environment" = "testnet" ]
then
        byron_start_time_in_seconds=1563999616  # 2019-07-24 20:20:16
        shelley_start_time_in_seconds=1595967616  # 2020-07-28 20:20:16
        allegra_start_time_in_seconds=1608063616  # 2020-12-15 20:20:16

elif [ "$environment" = "staging" ]
then    
        byron_start_time_in_seconds=1506450213  # 2017-09-26 18:23:33
        shelley_start_time_in_seconds=1596306213  # 2020-08-01 18:23:33
        allegra_start_time_in_seconds=1608402213  # 2020-12-19 18:23:33

elif [ "$environment" = "shelley_qa" ]
then
        byron_start_time_in_seconds=1597669200  # 2020-08-17 13:00:00
        shelley_start_time_in_seconds=1597683600  # 2020-08-17 17:00:00
        allegra_start_time_in_seconds=1607367600  # 2020-12-07 19:00:00
else:
    echo "" 
fi

current_time=$(date +'%s')
current_slot=$(( (shelley_start_time_in_seconds - byron_start_time_in_seconds)/20  + current_time - shelley_start_time_in_seconds ))
echo $current_slot

}

export CARDANO_NODE_SOCKET_PATH=/home/runner/work/database-sync-tests/database-sync-tests/cardano-node/${environment}/node.socket

 ./../cardano-node/cardano-cli query tip ${network_param}
#node_block_tip=$(./../cardano-node/cardano-cli query tip ${network_param} |awk {'print $2'} | head -n 2 | tail -n 1| sed 's/.$//')
node_block_tip=$(get_block_from_tip)
echo "node_block_tip: $node_block_tip"

latest_db_synced_slot=$(get_latest_db_synced_slot)

echo "latest_db_synced_slot: $latest_db_synced_slot"

re='^[0-9]+$'
while ! [[ $latest_db_synced_slot =~ $re ]] ; do
   echo "Not a block number, waiting for proper log line that contains block number..." 
   sleep 20
   latest_db_synced_slot=$(get_latest_db_synced_slot)
done


current_node_slot=$(calculate_slot_for_environment)
echo "current_node_slot: $current_node_slot"

while [ $latest_db_synced_slot -lt 300000 ]
do
sleep 20
latest_db_synced_slot=$(get_latest_db_synced_slot)

if ! [[ $latest_db_synced_slot =~ $re ]] ; then
	latest_db_synced_slot=0
    continue
fi

echo "latest_db_synced_slot: $latest_db_synced_slot"
done

db_sync_end_time=$(echo "$(date +'%d/%m/%Y %H:%M:%S')")

echo "db_sync_start_time: $db_sync_start_time" >> logs/db_sync_summary.log
echo "db_sync_end_time: $db_sync_end_time" >> logs/db_sync_summary.log
echo "latest_db_synced_slot: $latest_db_synced_slot" >> logs/db_sync_summary.log


# GET THE TIP FROM MAINNET USING GQL
#curl \
#-X POST \
#-H "Content-Type: application/json" \
#--data '{ "query": "{  blocks(order_by: {number: desc_nulls_last}, where: {number: {_gte: $lower, _lte: $upper}}) {    BlockOverview  }} fragment BlockOverview on Block {  forgedAt  slotLeader {    description  }  epochNo  hash  number  size slotInEpoch  transactions_aggregate {   aggregate {      count     sum {        totalOutput      }    }  }}" }' \
#https://explorer.cardano.org/graphql
