<script lang="ts">
  import type { Tx } from './tx'
  import { ETHERSCAN } from './munt'

  let { tx }: { tx: Tx } = $props()
</script>

{#if tx.stage !== 'idle'}
  <p class="tx" class:bad={tx.stage === 'failed'}>
    {#if tx.stage === 'signing'}
      <span class="dot pulse"></span> waiting for your signature
    {:else if tx.stage === 'pending'}
      <span class="dot pulse"></span> sent, waiting for a block
      <a href="{ETHERSCAN}/tx/{tx.hash}" target="_blank" rel="noopener noreferrer">{tx.hash}</a>
    {:else if tx.stage === 'mined'}
      <span class="dot done"></span> mined
      <a href="{ETHERSCAN}/tx/{tx.hash}" target="_blank" rel="noopener noreferrer">{tx.hash}</a>
    {:else if tx.stage === 'failed'}
      <span class="dot fail"></span> {tx.message}
      {#if tx.hash}
        <a href="{ETHERSCAN}/tx/{tx.hash}" target="_blank" rel="noopener noreferrer">{tx.hash}</a>
      {/if}
    {/if}
  </p>
{/if}

<style>
  .tx {
    margin-top: var(--gap);
    font-size: var(--font-size-sm);
    color: var(--text-secondary);
    overflow-wrap: anywhere;
  }
  .tx.bad { color: var(--bad); }
  .tx a { color: var(--accent); text-decoration: none; }
  .tx a:hover { text-decoration: underline; }
  .dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 4px;
    background: var(--text-tertiary);
    vertical-align: middle;
  }
  .dot.done { background: var(--accent); }
  .dot.fail { background: var(--bad); }
  .pulse { animation: pulse 1.2s ease-in-out infinite; }
  @keyframes pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 1; }
  }
  @media (prefers-reduced-motion: reduce) {
    .pulse { animation: none; }
  }
</style>
