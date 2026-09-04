#!/usr/bin/env sh
# Register label.eth on Sepolia through the ENSv2 registrar, to the address
# of $PRIVATE_KEY. Usage: PRIVATE_KEY=0x... script/register-name.sh muntje
set -eu

LABEL="$1"
RPC="${RPC:-https://ethereum-sepolia-rpc.publicnode.com}"
REGISTRAR=0xa88553f454b77203b0d036a05c894d555eaaa2cc
USDC=0x768f42455a2d082e23ceef7d51e5787c82d67a39
YEAR=31536000
NONE=0x0000000000000000000000000000000000000000
ZERO32=0x0000000000000000000000000000000000000000000000000000000000000000

OWNER=$(cast wallet address --private-key "$PRIVATE_KEY")
echo "owner  $OWNER"
echo "name   $LABEL.eth"

SECRET_FILE="register-$LABEL.secret"
if [ -f "$SECRET_FILE" ]; then
  SECRET=$(cat "$SECRET_FILE")
  echo "secret resumed from $SECRET_FILE"
else
  SECRET=0x$(head -c 32 /dev/urandom | xxd -p -c 64)
  echo "$SECRET" > "$SECRET_FILE"
  echo "secret $SECRET_FILE (kept until success)"
fi

PRICE=$(cast call "$REGISTRAR" 'getRegisterPrice(string,uint64,address)(uint256,uint256)' "$LABEL" "$YEAR" "$USDC" --rpc-url "$RPC" \
  | head -1 | cut -d' ' -f1)
echo "price  $PRICE (mock USDC, 6 decimals)"

# The Sepolia payment token is a mock with a public mint.
cast send "$USDC" 'mint(address,uint256)' "$OWNER" "$PRICE" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | jq -r '"mint   " + .transactionHash'
cast send "$USDC" 'approve(address,uint256)' "$REGISTRAR" "$PRICE" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | jq -r '"approve " + .transactionHash'

COMMITMENT=$(cast call "$REGISTRAR" \
  'makeCommitment(string,address,bytes32,address,address,uint64,bytes32)(bytes32)' \
  "$LABEL" "$OWNER" "$SECRET" "$NONE" "$NONE" "$YEAR" "$ZERO32" --rpc-url "$RPC")
echo "commit $COMMITMENT"

AT=$(cast call "$REGISTRAR" 'commitmentAt(bytes32)(uint64)' "$COMMITMENT" --rpc-url "$RPC")
if [ "$AT" = "0" ]; then
  cast send "$REGISTRAR" 'commit(bytes32)' "$COMMITMENT" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | jq -r '"tx     " + .transactionHash'
else
  echo "commit already on chain at $AT"
fi

SIG='register(string,address,bytes32,address,address,uint64,address,bytes32)'
for attempt in 1 2 3 4 5 6 7 8; do
  if OUT=$(cast call "$REGISTRAR" "$SIG" "$LABEL" "$OWNER" "$SECRET" "$NONE" "$NONE" "$YEAR" "$USDC" "$ZERO32" --from "$OWNER" --rpc-url "$RPC" 2>&1); then
    break
  fi
  echo "refuse $OUT"
  echo "retry  $attempt in 20s"
  sleep 20
done

SENT=$(cast send "$REGISTRAR" "$SIG" "$LABEL" "$OWNER" "$SECRET" "$NONE" "$NONE" "$YEAR" "$USDC" "$ZERO32" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json)
echo "$SENT" | jq -r '"tx     " + .transactionHash'
rm -f "$SECRET_FILE"

echo "owner of $LABEL.eth: $(cast call 0xBDC85dD5b15D7ecb354cd7cb6f2c50b4f2c4F0E2 'findOwner(string)(address)' "$LABEL" --rpc-url "$RPC")"
