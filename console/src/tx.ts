// The life of one transaction as the page shows it. Every stage is visible
// and the hash is a link to the explorer from the moment the wallet returns it.
import type { ContractTransactionResponse } from 'ethers'
import { describe } from './munt'

export type Tx =
  | { stage: 'idle' }
  | { stage: 'signing' }
  | { stage: 'pending'; hash: string }
  | { stage: 'mined'; hash: string }
  | { stage: 'failed'; message: string; hash?: string }

// Runs `send`, reports each stage through `set`, resolves true when mined.
export async function run(
  send: () => Promise<ContractTransactionResponse>,
  set: (tx: Tx) => void,
): Promise<boolean> {
  set({ stage: 'signing' })
  let hash: string | undefined
  try {
    const response = await send()
    hash = response.hash
    set({ stage: 'pending', hash })
    await response.wait()
    set({ stage: 'mined', hash })
    return true
  } catch (err) {
    set({ stage: 'failed', message: describe(err), hash })
    return false
  }
}
