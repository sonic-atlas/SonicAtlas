<script lang="ts">
  import type { PageData } from './$types';

  let { data }: { data: PageData } = $props();
</script>

<svelte:head>
  <title>Open Source Licenses</title>
</svelte:head>

<div class="licensesContainer">
  <h1>THIRD PARTY NOTICES</h1>

  <div class="licensesList">
    {#each data.licenses as pkg}
      <div class="licensesCard">
        <div class="header">
          <h2>{pkg.name}</h2>
          <span class="licensesType">{pkg.license}</span>
        </div>
        
        <details>
          <summary>View License</summary>
          <pre>{pkg.text}</pre>
        </details>
      </div>
    {/each}
  </div>
</div>

<style>
  .licensesContainer {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem;
  }

  h1 {
    text-align: center;
    color: var(--primary-color);
    margin-bottom: 2rem;
  }

  .licensesList {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .licensesCard {
    background: var(--surface-base);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 1rem;
    overflow: hidden;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  h2 {
    margin: 0;
    font-size: 1.25rem;
    word-break: break-word;
  }

  .licensesType {
    background: var(--primary-container);
    color: var(--on-primary-container);
    padding: 0.25rem 0.5rem;
    border-radius: 16px;
    font-size: 0.875rem;
    font-weight: 500;
  }

  details {
    margin-top: 1rem;
  }

  summary {
    cursor: pointer;
    font-weight: 500;
    color: var(--primary-color);
    user-select: none;
    outline: none;
    border-radius: 4px;
  }
  
  summary:hover {
    text-decoration: underline;
  }

  pre {
    background: var(--surface-dim);
    color: var(--text-secondary-color);
    padding: 1rem;
    border-radius: 8px;
    margin-top: 1rem;
    white-space: pre-wrap;
    font-family: monospace;
    font-size: 0.875rem;
    overflow-x: auto;
    max-height: 400px;
    overflow-y: auto;
  }
</style>
