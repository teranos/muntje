<script lang="ts">
  import { drawCoin, readCoin, describe, type Stempel, type Coin } from './munt'
  import { wallet } from './wallet.svelte'
  import { run, type Tx } from './tx'
  import { localDateTime } from './fmt'
  import TxLine from './TxLine.svelte'

  let { stempel, onstruck }: { stempel: Stempel; onstruck: () => void } = $props()

  let gezicht = $state(0)
  let tx = $state<Tx>({ stage: 'idle' })
  let coin: { id: string; hash: string; gezicht: number; at: Date } | null = $state(null)
  let onChain: Coin | null = $state(null)
  let readBack = $state('')
  let copied = $state(false)

  let inFlight = $derived(tx.stage === 'signing' || tx.stage === 'pending')

  async function strike() {
    if (!wallet.munt) return
    const munt = wallet.munt
    // The ID is on the screen before the wallet is asked, and stays there
    // whatever happens next: once the strike is sent, the ink is spent and
    // this ID is the only copy of the coin (lines 31, 32, 47).
    const drawn = drawCoin()
    coin = { ...drawn, gezicht, at: new Date() }
    onChain = null
    readBack = ''
    copied = false
    const ok = await run(
      () => munt.strike(BigInt(stempel.number), BigInt(gezicht), drawn.hash),
      (t) => { tx = t },
    )
    if (!ok) return
    try {
      onChain = await readCoin(drawn.hash)
    } catch (err) {
      readBack = describe(err)
    }
    onstruck()
  }

  async function copy() {
    if (!coin) return
    try {
      await navigator.clipboard.writeText(coin.id)
      copied = true
    } catch (err) {
      readBack = describe(err)
    }
  }

  function another() {
    coin = null
    onChain = null
    tx = { stage: 'idle' }
    readBack = ''
    copied = false
  }
</script>

{#if !coin}
  <div class="pick no-print">
    <p class="lead">Pick the gezicht. The ID is drawn in this browser and shown once. It is the coin; the chain only gets its hash.</p>
    <div class="gezichten" role="radiogroup" aria-label="gezicht">
      {#each stempel.gezichten as g, i (i)}
        <button
          class:ghost={gezicht !== i}
          role="radio"
          aria-checked={gezicht === i}
          onclick={() => { gezicht = i }}
          disabled={inFlight}
        >
          <span class="idx">{i}</span>{g}
        </button>
      {/each}
    </div>
    <div class="go">
      <button onclick={strike} disabled={inFlight || !wallet.munt}>Strike</button>
      <span class="hint">uses 1 of {stempel.ink} ink</span>
    </div>
    <TxLine {tx} />
  </div>
{:else}
  <div class="coin">
    <div class="paper">
      <div class="paper-hd">
        <span class="name">{stempel.label}.eth</span>
        <span class="face">{stempel.gezichten[coin.gezicht]}</span>
      </div>
      <div class="id-label">ID · keep this secret · showing it is spending it</div>
      <div class="id">{coin.id}</div>
      <dl>
        <dt>stempel</dt><dd>#{stempel.number}</dd>
        <dt>gezicht</dt><dd>{coin.gezicht} {stempel.gezichten[coin.gezicht]}</dd>
        <dt>struck</dt><dd>{localDateTime(coin.at)}</dd>
        <dt>hash</dt><dd>{coin.hash}</dd>
      </dl>
    </div>

    <div class="after no-print">
      <TxLine {tx} />
      {#if onChain}
        <p class="meta">
          read back from chain: stempel {onChain.stempel}, gezicht {onChain.gezicht}, {onChain.spent ? 'spent' : 'not spent'}
        </p>
      {/if}
      {#if readBack}
        <p class="err">{readBack}</p>
      {/if}
      <div class="row">
        <button class="ghost" onclick={copy}>{copied ? 'copied' : 'Copy ID'}</button>
        <button class="ghost" onclick={() => window.print()} disabled={tx.stage !== 'mined'}>Print</button>
        <button class="ghost" onclick={another} disabled={inFlight}>Strike another</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .lead {
    color: var(--text-secondary);
    font-size: var(--font-size-sm);
    margin-bottom: var(--gap);
  }

  .gezichten {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-bottom: var(--gap);
  }

  .idx {
    opacity: 0.6;
    margin-right: 6px;
  }

  .go {
    display: flex;
    align-items: center;
    gap: var(--gap);
  }

  .hint, .meta {
    color: var(--text-tertiary);
    font-size: var(--font-size-sm);
  }

  .err {
    color: var(--bad);
    font-size: var(--font-size-sm);
  }

  .coin {
    display: flex;
    flex-direction: column;
    gap: var(--gap);
  }

  /* The Muntje as it goes on paper (lines 3, 47, 51). Black on white on
     purpose, in every colour scheme: it is the receipt, not the page. */
  .paper {
    background: #fff;
    color: #111;
    border: 1px dashed #999;
    border-radius: var(--border-radius);
    padding: 14px 16px;
    max-width: 420px;
    font-size: var(--font-size-md);
  }

  .paper-hd {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--gap);
    border-bottom: 1px solid #111;
    padding-bottom: 6px;
    margin-bottom: 10px;
  }

  .name { font-size: var(--font-size-lg); font-weight: 600; overflow-wrap: anywhere; }
  .face { font-family: var(--font-serif); font-size: 1.25rem; overflow-wrap: anywhere; }

  .id-label {
    font-size: var(--font-size-xs);
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: #555;
  }

  .id {
    font-size: var(--font-size-lg);
    font-weight: 600;
    overflow-wrap: anywhere;
    margin: 4px 0 10px;
  }

  .paper dl {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 2px 10px;
    font-size: var(--font-size-xs);
    color: #555;
  }
  .paper dd { overflow-wrap: anywhere; }

  .row {
    display: flex;
    gap: var(--gap);
    flex-wrap: wrap;
    margin-top: var(--gap);
  }

  @media print {
    .paper { border: none; padding: 0; max-width: none; }
  }
</style>
