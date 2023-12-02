#!/bin/bash

#  _     _            _                             
# | |   | |          | |                            
# | |__ | | ___   ___| | ___ __ ___   _____   _____ 
# | '_ \| |/ _ \ / __| |/ / '_ ` _ \ / _ \ \ / / _ \
# | |_) | | (_) | (__|   <| | | | | | (_) \ V /  __/
# |_.__/|_|\___/ \___|_|\_\_| |_| |_|\___/ \_/ \___|
 
# Variables
NETWORK="holesky"
EXECUTION_CLIENT="geth"
ETHEREUM_DIR="$HOME/ethereum"
CONSENSUS_DIR="$ETHEREUM_DIR/consensus"
EXECUTION_DIR="$ETHEREUM_DIR/execution"
JWT_PATH="$EXECUTION_DIR/jwtsecret"
PRYSM_URL="https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh"

# Create directories
mkdir -p "$CONSENSUS_DIR" "$EXECUTION_DIR"

# Generate JWT Secret file
openssl rand -hex 32 > "$JWT_PATH"

# Install Prysm
curl "$PRYSM_URL" --output "$CONSENSUS_DIR/prysm.sh"
chmod +x "$CONSENSUS_DIR/prysm.sh"

# Fetch the latest release data using GitHub API
echo "Fetching the latest Geth release data..."
TAG_NAME=$(curl -s https://api.github.com/repos/ethereum/go-ethereum/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)

# Fetch commit hash using the tag name
echo "Fetching commit hash for tag: $TAG_NAME..."
COMMIT_HASH=$(curl -s https://api.github.com/repos/ethereum/go-ethereum/git/refs/tags/"$TAG_NAME" | grep '"sha":' | head -n 1 | cut -d '"' -f 4)

# Check if data is empty
if [ -z "$TAG_NAME" ] || [ -z "$COMMIT_HASH" ]; then
    echo "Failed to fetch the latest Geth version or commit hash. Exiting."
    exit 1
fi

# Remove 'v' prefix from version number and extract the first 8 characters of commit hash
VERSION_NUMBER=$(echo "$TAG_NAME" | cut -c 2-)
SHORT_COMMIT_HASH=$(echo "$COMMIT_HASH" | cut -c 1-8)

# Construct download URL
LATEST_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-${VERSION_NUMBER}-${SHORT_COMMIT_HASH}.tar.gz"

# Install and run Geth for the execution client
cd "$EXECUTION_DIR"
wget "$LATEST_URL" -O geth.tar.gz
tar -xzf geth.tar.gz
cd $(tar -tf geth.tar.gz | grep -o '^[^/]\+' | uniq)
screen -dmS geth_session ./geth --$NETWORK --http --http.api eth,net,engine,admin --authrpc.jwtsecret="$JWT_PATH"

# Run the Beacon Node
cd "$CONSENSUS_DIR"
screen -dmS beacon_node_session ./prysm.sh beacon-chain --accept-terms-of-use --execution-endpoint="http://localhost:8551" --$NETWORK --jwt-secret="$JWT_PATH" --checkpoint-sync-url=https://holesky.beaconstate.info --genesis-beacon-api-url=https://holesky.beaconstate.info

echo "Geth, Beacon Node are running in separate screen sessions."
