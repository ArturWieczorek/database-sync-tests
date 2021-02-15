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

EOF
}


MODIFIED_NETWORK_NAME=$(echo "${network}" | sed 's/-/_/')

PGPASSFILE=config/pgpass-${network} scripts/postgresql-setup.sh --createdb

PGPASSFILE=config/pgpass-${network} db-sync-node-extended/bin/cardano-db-sync-extended \
--config config/${network}-config.yaml \
--socket-path ../cardano-node/${MODIFIED_NETWORK_NAME}/node.socket \
--state-dir ledger-state/${MODIFIED_NETWORK_NAME} \
--schema-dir schema/

fi
