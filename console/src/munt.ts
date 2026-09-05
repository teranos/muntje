// Everything that touches the chain. The rest of the app never imports
// ethers directly; it goes through here so what we ask of Sepolia is in one
// file a person can read top to bottom.
import { Contract, JsonRpcProvider, keccak256, hexlify, randomBytes, isError, type Signer } from 'ethers'

export const CONTRACT = '0xdfc33798720367f430fc58d662f56a3edf5e00c3'
export const CHAIN_ID = 11155111n
export const CHAIN_ID_HEX = '0xaa36a7'
export const CHAIN_NAME = 'Sepolia'
export const RPC = 'https://ethereum-sepolia-rpc.publicnode.com'
export const ETHERSCAN = 'https://sepolia.etherscan.io'
export const SOURCE = 'https://github.com/teranos/muntje'

export const ABI = [
  'function ens() view returns (address)',
  'function cut(string label, string[] gezichten, uint64 endDate, uint64 ink) returns (uint256)',
  'function read(uint256 number) view returns (string label, string[] gezichten, uint64 endDate, uint64 ink)',
  'function strike(uint256 stempel, uint256 gezicht, bytes32 hash)',
  'function coin(bytes32 hash) view returns (uint256 stempel, uint256 gezicht, bool spent)',
]

// The registry the contract itself consults in cut() and strike(). We ask it
// the same question the contract will, so the page can say up front which
// Stempels the connected address controls.
const ENS_ABI = ['function findOwner(string label) view returns (address)']

export interface Stempel {
  number: number
  label: string
  gezichten: string[]
  endDate: Date
  ink: bigint
}

export interface Coin {
  stempel: bigint
  gezicht: bigint
  spent: boolean
}

const provider = new JsonRpcProvider(RPC, CHAIN_ID, { staticNetwork: true })
export const reader = new Contract(CONTRACT, ABI, provider)

export function withSigner(signer: Signer): Contract {
  return new Contract(CONTRACT, ABI, signer)
}

// The contract has no count. read(n) reverts past the end, so we probe in
// parallel batches and stop at the first number that reverts.
const BATCH = 8
const CEILING = 512

export async function readStempels(): Promise<Stempel[]> {
  const out: Stempel[] = []
  for (let start = 0; start < CEILING; start += BATCH) {
    const numbers: number[] = []
    for (let n = start; n < start + BATCH; n++) numbers.push(n)
    const results = await Promise.allSettled(numbers.map((n) => reader.read(n)))
    let ended = false
    for (let i = 0; i < results.length; i++) {
      const r = results[i]
      if (r.status === 'rejected') {
        // A revert is the end of the array. Anything else is the RPC
        // failing, and that must surface, not shorten the list.
        if (!isError(r.reason, 'CALL_EXCEPTION')) throw r.reason
        ended = true
        break
      }
      out.push({
        number: numbers[i],
        label: r.value.label,
        gezichten: Array.from(r.value.gezichten),
        endDate: new Date(Number(r.value.endDate) * 1000),
        ink: r.value.ink,
      })
    }
    if (ended) break
  }
  return out
}

export async function readCoin(hash: string): Promise<Coin> {
  const c = await reader.coin(hash)
  return { stempel: c.stempel, gezicht: c.gezicht, spent: c.spent }
}

let registry: Contract | null = null

async function ens(): Promise<Contract> {
  if (registry) return registry
  const address: string = await reader.ens()
  registry = new Contract(address, ENS_ABI, provider)
  return registry
}

// Who controls label.eth right now, per the registry the contract uses.
export async function ownerOf(label: string): Promise<string> {
  const r = await ens()
  return await r.findOwner(label)
}

// The coin: a secret drawn here, and the hash that goes on chain.
export function drawCoin(): { id: string; hash: string } {
  const id = hexlify(randomBytes(32))
  return { id, hash: keccak256(id) }
}

// One place that turns whatever ethers or the wallet threw into a sentence.
// Revert reasons come out verbatim: they are the contract's own words.
export function describe(err: unknown): string {
  if (isError(err, 'ACTION_REJECTED')) return 'you rejected it in the wallet'
  if (isError(err, 'CALL_EXCEPTION') && err.reason) return err.reason
  if (isError(err, 'INSUFFICIENT_FUNDS')) return 'not enough Sepolia ETH for gas'
  if (typeof err === 'object' && err !== null) {
    const e = err as { shortMessage?: string; message?: string }
    if (e.shortMessage) return e.shortMessage
    if (e.message) return e.message
  }
  return String(err)
}
