// The one wallet the page talks to. Runes in a module so every component
// sees the same address and the same signer-bound contract.
import { BrowserProvider, type Contract } from 'ethers'
import { CHAIN_ID, CHAIN_ID_HEX, CHAIN_NAME, withSigner, describe } from './munt'

interface Eip1193 {
  request(args: { method: string; params?: unknown[] }): Promise<unknown>
  on(event: string, handler: (payload: unknown) => void): void
}

function injected(): Eip1193 | null {
  const w = window as unknown as { ethereum?: Eip1193 }
  return w.ethereum ?? null
}

export const wallet = $state({
  address: '',
  busy: false,
  error: '',
  munt: null as Contract | null,
})

let listening = false

export function hasWallet(): boolean {
  return injected() !== null
}

export async function connect(): Promise<void> {
  const eth = injected()
  if (!eth) { wallet.error = 'no wallet in this browser'; return }
  wallet.busy = true
  wallet.error = ''
  try {
    const provider = new BrowserProvider(eth)
    await provider.send('eth_requestAccounts', [])
    let net = await provider.getNetwork()
    if (net.chainId !== CHAIN_ID) {
      // Ask the wallet to move, the way the current page only tells you to.
      await provider.send('wallet_switchEthereumChain', [{ chainId: CHAIN_ID_HEX }])
      net = await provider.getNetwork()
      if (net.chainId !== CHAIN_ID) throw new Error(`still on chain ${net.chainId}, need ${CHAIN_NAME}`)
    }
    const signer = await provider.getSigner()
    wallet.address = await signer.getAddress()
    wallet.munt = withSigner(signer)
    if (!listening) {
      listening = true
      // A change of account or chain in the wallet is a change of who can
      // cut and strike. Reconnect rather than keep a stale signer.
      eth.on('accountsChanged', () => { void connect() })
      eth.on('chainChanged', () => { void connect() })
    }
  } catch (err) {
    wallet.address = ''
    wallet.munt = null
    wallet.error = describe(err)
  } finally {
    wallet.busy = false
  }
}
