<script lang="ts">
  import { wallet } from './wallet.svelte'
  import { run, type Tx } from './tx'
  import { inputDateTime } from './fmt'
  import TxLine from './TxLine.svelte'

  let { oncut }: { oncut: () => void } = $props()

  const tomorrow = new Date(Date.now() + 86400000)
  tomorrow.setSeconds(0, 0)

  let name = $state('')
  let gezichten: string[] = $state(['beer', 'coat'])
  let draft = $state('')
  let end = $state(inputDateTime(tomorrow))
  let ink = $state(100)
  let tx = $state<Tx>({ stage: 'idle' })

  // The contract wants the label, so a pasted "muntje.eth" loses its suffix.
  let label = $derived.by(() => {
    const t = name.trim()
    return t.endsWith('.eth') ? t.slice(0, t.length - 4) : t
  })
  let endDate = $derived(new Date(end))
  let endOk = $derived(!Number.isNaN(endDate.getTime()) && endDate.getTime() > Date.now())
  let inkOk = $derived(Number.isInteger(ink) && ink >= 1)
  let inFlight = $derived(tx.stage === 'signing' || tx.stage === 'pending')
  let ready = $derived(wallet.munt !== null && label !== '' && gezichten.length > 0 && endOk && inkOk && !inFlight)

  function addGezicht() {
    // One box, comma or not: "beer, coat" and "beer" both work.
    for (const part of draft.split(',')) {
      const g = part.trim()
      if (g !== '' && !gezichten.includes(g)) gezichten.push(g)
    }
    draft = ''
  }

  function removeGezicht(i: number) {
    gezichten.splice(i, 1)
  }

  function onDraftKey(e: KeyboardEvent) {
    if (e.key === 'Enter') { e.preventDefault(); addGezicht() }
  }

  async function cut() {
    if (!wallet.munt) return
    const munt = wallet.munt
    const endSeconds = BigInt(Math.floor(endDate.getTime() / 1000))
    const faces = gezichten.slice()
    const ok = await run(
      () => munt.cut(label, faces, endSeconds, BigInt(ink)),
      (t) => { tx = t },
    )
    if (ok) oncut()
  }
</script>

<form onsubmit={(e) => { e.preventDefault(); void cut() }}>
  <div class="field">
    <label for="name">ENS name you control</label>
    <div class="suffixed">
      <input id="name" bind:value={name} placeholder="muntje" autocomplete="off" spellcheck="false" disabled={inFlight}>
      <span class="suffix">.eth</span>
    </div>
  </div>

  <div class="field">
    <label for="gezicht">Gezichten, fixed the moment the Stempel is cut</label>
    <div class="chips">
      {#each gezichten as g, i (g)}
        <span class="chip">
          <span class="idx">{i}</span>{g}
          <button type="button" class="x" aria-label="remove {g}" onclick={() => removeGezicht(i)} disabled={inFlight}>×</button>
        </span>
      {/each}
    </div>
    <div class="add">
      <input id="gezicht" bind:value={draft} placeholder="add a gezicht, Enter to add" autocomplete="off" onkeydown={onDraftKey} disabled={inFlight}>
      <button type="button" class="ghost" onclick={addGezicht} disabled={inFlight || draft.trim() === ''}>Add</button>
    </div>
  </div>

  <div class="row">
    <div class="field">
      <label for="end">End-date, local time</label>
      <input id="end" type="datetime-local" bind:value={end} disabled={inFlight}>
      {#if !endOk}
        <span class="why">must be in the future</span>
      {/if}
    </div>
    <div class="field">
      <label for="ink">Ink, one per strike</label>
      <input id="ink" type="number" bind:value={ink} min="1" step="1" disabled={inFlight}>
      {#if !inkOk}
        <span class="why">a whole number, at least 1</span>
      {/if}
    </div>
  </div>

  <div class="go">
    <button type="submit" disabled={!ready}>Cut</button>
    {#if !wallet.munt}
      <span class="hint">connect a wallet to cut</span>
    {:else if label !== ''}
      <span class="hint">the contract checks that {wallet.address} controls {label}.eth</span>
    {/if}
  </div>
  <TxLine {tx} />
</form>

<style>
  form {
    display: flex;
    flex-direction: column;
    gap: 12px;
    max-width: 560px;
  }

  .field { display: flex; flex-direction: column; }

  .suffixed {
    display: flex;
    align-items: center;
  }
  .suffixed input { border-radius: var(--border-radius) 0 0 var(--border-radius); }
  .suffix {
    padding: 6px 8px;
    border: 1px solid var(--border);
    border-left: none;
    border-radius: 0 var(--border-radius) var(--border-radius) 0;
    background: var(--bg-secondary);
    color: var(--text-secondary);
  }

  .chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-bottom: 4px;
    min-height: 1.5em;
  }

  .chip {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    font-size: var(--font-size-sm);
    border: 1px solid var(--border);
    border-radius: var(--border-radius);
    padding: 1px 2px 1px 6px;
    background: var(--bg-secondary);
  }

  .idx { color: var(--text-tertiary); margin-right: 5px; }

  .x {
    background: transparent;
    border: none;
    color: var(--text-tertiary);
    padding: 0 5px;
    line-height: 1;
    font-size: var(--font-size-lg);
  }
  .x:hover:not(:disabled) { background: transparent; color: var(--bad); }

  .add {
    display: flex;
    gap: 4px;
  }

  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--gap);
  }

  @media (max-width: 480px) {
    .row { grid-template-columns: 1fr; }
  }

  .go {
    display: flex;
    align-items: center;
    gap: var(--gap);
    flex-wrap: wrap;
  }

  .hint, .why {
    font-size: var(--font-size-xs);
    color: var(--text-tertiary);
    overflow-wrap: anywhere;
  }
  .why { color: var(--warn); }
</style>
