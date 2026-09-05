<script lang="ts">
  import type { Stempel } from './munt'
  import { localDateTime } from './fmt'

  let {
    stempel,
    mine,
    selected,
    connected,
    onselect,
  }: {
    stempel: Stempel
    mine: boolean | null
    selected: boolean
    connected: boolean
    onselect: () => void
  } = $props()

  // The two ways a Stempel stops striking, in the contract's order.
  let passed = $derived(stempel.endDate.getTime() <= Date.now())
  let dry = $derived(stempel.ink === 0n)
  let live = $derived(!passed && !dry)

  // Strike is offered when the registry says the name is yours, or when it
  // has not answered yet. When it says no, the contract would say no too.
  let canStrike = $derived(connected && live && mine !== false)
</script>

<article class:selected class:dead={!live}>
  <div class="top">
    <span class="number">#{stempel.number}</span>
    <span class="name">{stempel.label}.eth</span>
    {#if mine === true}
      <span class="pill yours">yours</span>
    {/if}
    {#if passed}
      <span class="pill off">passed end-date</span>
    {:else if dry}
      <span class="pill off">out of ink</span>
    {/if}
  </div>

  <div class="gezichten">
    {#each stempel.gezichten as g, i (i)}
      <span class="gezicht"><span class="idx">{i}</span>{g}</span>
    {/each}
  </div>

  <dl>
    <dt>end-date</dt><dd>{localDateTime(stempel.endDate)}</dd>
    <dt>ink</dt><dd>{stempel.ink}</dd>
  </dl>

  <div class="actions">
    <button class:ghost={!selected} onclick={onselect} disabled={!canStrike}>
      {selected ? 'Striking from this' : 'Strike from this'}
    </button>
    {#if !connected}
      <span class="why">connect a wallet to strike</span>
    {:else if mine === false}
      <span class="why">not your name</span>
    {/if}
  </div>
</article>

<style>
  article {
    border: 1px solid var(--border);
    border-radius: var(--border-radius-lg);
    background: var(--bg-secondary);
    padding: 10px 12px;
    display: flex;
    flex-direction: column;
    gap: var(--gap);
    transition: border-color 0.15s ease;
  }

  article.selected { border-color: var(--accent); }
  article.dead { opacity: 0.6; }

  .top {
    display: flex;
    align-items: baseline;
    gap: var(--gap);
    flex-wrap: wrap;
  }

  .number { color: var(--text-tertiary); font-size: var(--font-size-sm); }
  .name { font-size: var(--font-size-lg); font-weight: 500; overflow-wrap: anywhere; }

  .pill {
    font-size: var(--font-size-xs);
    border-radius: var(--border-radius);
    padding: 0 6px;
    border: 1px solid currentColor;
  }
  .pill.yours { color: var(--accent); }
  .pill.off { color: var(--warn); }

  .gezichten {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .gezicht {
    font-size: var(--font-size-sm);
    border: 1px solid var(--border);
    border-radius: var(--border-radius);
    padding: 1px 6px;
    background: var(--bg);
    overflow-wrap: anywhere;
  }

  .idx {
    color: var(--text-tertiary);
    margin-right: 5px;
  }

  dl {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 2px var(--gap);
    font-size: var(--font-size-sm);
  }
  dt { color: var(--text-tertiary); }
  dd { color: var(--text-secondary); }

  .actions {
    display: flex;
    align-items: center;
    gap: var(--gap);
    flex-wrap: wrap;
  }

  .why {
    font-size: var(--font-size-xs);
    color: var(--text-tertiary);
  }
</style>
