#!/bin/bash

function usage() {
    cat << HEREDOC

    arguments:
    -n          network - possible options: allegra, launchpad, mary_qa, mainnet, staging, testnet, shelley_qa
    -t          tag

    optional arguments:
      -h, --help           show this help message and exit

Example:

./start_node.sh -n shelley_qa -t 1.25.0

USE UNDERSCORES IN NETWORK NAMES !!!
HEREDOC
}

while getopts ":h:n:t:" o; do
    case "${o}" in
        h)
            usage
            ;;
        n)
            network=${OPTARG}
            ;;
        t)
            tag=${OPTARG}
            ;;
        *)
            echo "NO SUCH ARGUMENT: ${OPTARG}"
            usage
            ;;
    esac
done
if [ $? != 0 ] || [ $# == 0 ] ; then
    echo "ERROR: Error in command line arguments." >&2 ; usage; exit 1 ;
fi
shift $((OPTIND-1))

IOHK_ROOT_REPO="input-output-hk"
NODE_REPO="${IOHK_ROOT_REPO}/cardano-node"
NODE_LOGFILEPATH="node_logfile.log"

get_latest_release() {
    curl --silent "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name
}

echo "We are here: ${PWD}, script name is $0"
echo ""
echo "Creating cardano-node directory and entering it ..."

mkdir cardano-node
cd cardano-node

REPO_LATEST_TAG=$(get_latest_release ${NODE_REPO})
NODE_LATEST_TAG=${tag:-"${REPO_LATEST_TAG}"}


echo ""
echo "Downloading latest version of cardano-node tag: $NODE_LATEST_TAG"

wget -q --show-progress "https://hydra.iohk.io/job/Cardano/cardano-node/cardano-node-linux/latest-finished/download/1/cardano-node-$NODE_LATEST_TAG-linux.tar.gz"

echo ""
echo "Unpacking and removing archive ..."

tar -xf "cardano-node-$NODE_LATEST_TAG-linux.tar.gz"
rm "cardano-node-$NODE_LATEST_TAG-linux.tar.gz"

NODE_CONFIGS_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | sed 's|\(.*\)/.*|\1|')

echo ""
echo "Downloading node configuration files from $NODE_CONFIGS_URL for networks specified in script ..."
echo ""

# Get latest configs for network(s) you need:
# List of all current networks: "allegra" "launchpad" "mainnet" "mary_qa" "shelley_qa" "staging" "testnet"

for _network in ${network}
do
	mkdir ${_network}
	cd ${_network}
	echo "${PWD}"
	wget -q --show-progress $NODE_CONFIGS_URL/${_network}-config.json
	wget -q --show-progress $NODE_CONFIGS_URL/${_network}-byron-genesis.json
	wget -q --show-progress $NODE_CONFIGS_URL/${_network}-shelley-genesis.json
	wget -q --show-progress $NODE_CONFIGS_URL/${_network}-topology.json
	wget -q --show-progress $NODE_CONFIGS_URL/${_network}-db-sync-config.json
	echo ""
	cd ..
done

echo ""
echo "Node configuration files located in ${PWD}:"
echo ""

ls -1

echo ""
echo "Node version: "
echo ""
./cardano-node --version

echo ""
echo "CLI version: "
echo ""
./cardano-cli --version


echo ""
echo ""
echo "Starting node."

./cardano-node run --topology ${network}/${network}-topology.json --database-path ${network}/db --socket-path ${network}/node.socket --config ${network}/${network}-config.json >> $NODE_LOGFILEPATH &