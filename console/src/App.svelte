<script lang="ts">
  import { onMount } from 'svelte'
  import { readStempels, ownerOf, describe, CONTRACT, CHAIN_NAME, ETHERSCAN, SOURCE, type Stempel } from './munt'
  import { wallet, connect, hasWallet } from './wallet.svelte'
  import StempelCard from './StempelCard.svelte'
  import Strike from './Strike.svelte'
  import Cut from './Cut.svelte'

  let stempels: Stempel[] = $state([])
  let reading = $state(false)
  let readError = $state('')
  let readAt: Date | null = $state(null)

  // label -> address that controls label.eth, per the contract's registry.
  // Filled after the list is read; a label missing here is still unknown.
  let owners: Record<string, string> = $state({})

  let selected: number | null = $state(null)
  let selectedStempel = $derived(stempels.find((s) => s.number === selected) ?? null)

  async function reload() {
    reading = true
    readError = ''
    try {
      stempels = await readStempels()
      readAt = new Date()
      if (selected !== null && !stempels.some((s) => s.number === selected)) selected = null
      await resolveOwners()
    } catch (err) {
      readError = describe(err)
    } finally {
      reading = false
    }
  }

  async function resolveOwners() {
    const labels = Array.from(new Set(stempels.map((s) => s.label)))
    const found: Record<string, string> = {}
    const results = await Promise.allSettled(labels.map((l) => ownerOf(l)))
    for (let i = 0; i < labels.length; i++) {
      const r = results[i]
      if (r.status === 'fulfilled') found[labels[i]] = r.value
    }
    owners = found
  }

  // null: not known. true/false: the registry answered.
  function mine(s: Stempel): boolean | null {
    if (!wallet.address) return null
    const owner = owners[s.label]
    if (!owner) return null
    return owner.toLowerCase() === wallet.address.toLowerCase()
  }

  function select(n: number) {
    selected = selected === n ? null : n
  }

  onMount(() => { void reload() })
</script>

<main>
  <header class="no-print">
    <div class="title">
      <h1>De Vrije Munt</h1>
      <p class="tagline">A Stempel is cut by an ENS name. Only that name strikes from it.</p>
    </div>
    <div class="wallet">
      {#if wallet.address}
        <span class="addr">{wallet.address}</span>
        <span class="chain">{CHAIN_NAME}</span>
      {:else}
        <button onclick={connect} disabled={wallet.busy}>
          {wallet.busy ? 'connecting' : 'Connect wallet'}
        </button>
      {/if}
      {#if wallet.error}
        <span class="err">{wallet.error}</span>
      {:else if !wallet.address && !hasWallet()}
        <span class="hint">no wallet in this browser; reading still works</span>
      {/if}
    </div>
  </header>

  <section class="no-print">
    <div class="section-hd">
      <h2>Stempels</h2>
      <span class="meta">
        {#if reading}
          reading
        {:else if readAt}
          {stempels.length} on chain
        {/if}
      </span>
      <button class="ghost" onclick={reload} disabled={reading}>Read again</button>
    </div>
    {#if readError}
      <p class="err">{readError}</p>
    {/if}
    {#if !reading && !readError && stempels.length === 0}
      <p class="hint">No Stempel has been cut yet.</p>
    {/if}
    <div class="cards">
      {#each stempels as s (s.number)}
        <StempelCard
          stempel={s}
          mine={mine(s)}
          selected={selected === s.number}
          connected={wallet.address !== ''}
          onselect={() => select(s.number)}
        />
      {/each}
    </div>
  </section>

  {#if selectedStempel}
    <section>
      <div class="section-hd no-print">
        <h2>Strike</h2>
        <span class="meta">from #{selectedStempel.number} {selectedStempel.label}.eth</span>
      </div>
      {#key selectedStempel.number}
        <Strike stempel={selectedStempel} onstruck={reload} />
      {/key}
    </section>
  {/if}

  <section class="no-print">
    <div class="section-hd">
      <h2>Cut a Stempel</h2>
      <span class="meta">as a name you control</span>
    </div>
    <Cut oncut={reload} />
  </section>

  <footer class="no-print">
    Contract <a href="{ETHERSCAN}/address/{CONTRACT}" target="_blank" rel="noopener noreferrer">{CONTRACT}</a>
    on {CHAIN_NAME} · <a href={SOURCE} target="_blank" rel="noopener noreferrer">teranos/muntje</a>
  </footer>
</main>

<style>
  main {
    max-width: 760px;
    margin: 0 auto;
    padding: 2rem 1rem 4rem;
    display: flex;
    flex-direction: column;
    gap: 2.5rem;
  }

  header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 1rem;
    flex-wrap: wrap;
  }

  h1 {
    font-family: var(--font-serif);
    font-size: 2rem;
    font-weight: 400;
    letter-spacing: 0.02em;
    line-height: 1.2;
  }

  .tagline {
    color: var(--text-secondary);
    margin-top: 0.25rem;
  }

  .title { flex: 1 1 340px; }

  .wallet {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
    max-width: 100%;
    margin-left: auto;
  }

  .addr {
    font-size: var(--font-size-sm);
    overflow-wrap: anywhere;
    text-align: right;
  }

  .chain {
    font-size: var(--font-size-xs);
    color: var(--accent);
    border: 1px solid var(--accent);
    border-radius: var(--border-radius);
    padding: 0 6px;
  }

  h2 {
    font-size: var(--font-size-lg);
    font-weight: 500;
  }

  .section-hd {
    display: flex;
    align-items: baseline;
    gap: var(--gap);
    margin-bottom: var(--gap);
    border-bottom: 1px solid var(--border);
    padding-bottom: 4px;
  }

  .section-hd .meta {
    color: var(--text-tertiary);
    font-size: var(--font-size-sm);
    flex: 1;
  }

  .cards {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: var(--gap);
  }

  .meta, .hint {
    color: var(--text-tertiary);
    font-size: var(--font-size-sm);
  }

  .err {
    color: var(--bad);
    font-size: var(--font-size-sm);
    overflow-wrap: anywhere;
  }

  footer {
    color: var(--text-tertiary);
    font-size: var(--font-size-sm);
    border-top: 1px solid var(--border);
    padding-top: var(--gap);
    overflow-wrap: anywhere;
  }

  footer a {
    color: var(--text-secondary);
    text-decoration: none;
  }

  footer a:hover {
    color: var(--text);
    text-decoration: underline;
  }

  :global(button) {
    font: inherit;
    font-size: var(--font-size-md);
    padding: 6px 12px;
    border: 1px solid var(--accent);
    border-radius: var(--border-radius);
    background: var(--accent);
    color: var(--accent-text);
    cursor: pointer;
    transition: background 0.15s ease;
  }

  :global(button:hover:not(:disabled)) {
    background: var(--accent-hover);
    border-color: var(--accent-hover);
  }

  :global(button:disabled) {
    opacity: 0.4;
    cursor: default;
  }

  :global(button.ghost) {
    background: transparent;
    color: var(--text-secondary);
    border-color: var(--border);
  }

  :global(button.ghost:hover:not(:disabled)) {
    background: var(--bg-secondary);
    color: var(--text);
    border-color: var(--border);
  }

  :global(input) {
    font: inherit;
    padding: 6px 8px;
    border: 1px solid var(--border);
    border-radius: var(--border-radius);
    background: var(--bg);
    color: var(--text);
    width: 100%;
  }

  :global(input:focus) {
    outline: none;
    border-color: var(--accent);
  }

  :global(label) {
    display: block;
    font-size: var(--font-size-sm);
    color: var(--text-secondary);
    margin-bottom: 3px;
  }

  /* The paper. Everything but the struck coin leaves the page when printed. */
  @media print {
    :global(.no-print) { display: none; }
    main { padding: 0; gap: 0; }
  }
</style>
