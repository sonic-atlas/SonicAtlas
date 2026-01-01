<script lang="ts">
    import { apiDelete, API_BASE_URL } from '$lib/api';
    import { invalidateAll } from '$app/navigation';
    import '@material/web/button/filled-button.js';
    import '@material/web/button/outlined-button.js';

    let { data } = $props();
    let releases = $derived(data.releases);
    let deleting = $state<string | null>(null);

    async function deleteRelease(id: string) {
        if (
            !confirm(
                'Are you sure you want to delete this release? This will delete all associated tracks and files.'
            )
        )
            return;

        deleting = id;
        try {
            const res = await apiDelete(`/api/releases/${id}`);
            if (!res.ok) throw new Error('Failed to delete');
            await invalidateAll();
        } catch (err) {
            console.error(err);
            alert('Failed to delete release');
        } finally {
            deleting = null;
        }
    }
</script>

<div class="managePage">
    <h1>Manage Releases</h1>

    <div class="releaseList">
        {#each releases as release (release.id)}
            <div class="releaseItem">
                <div class="releaseContent">
                    {#if release.coverArtPath}
                        <img
                            src="{API_BASE_URL}{release.coverArtPath}?size=small"
                            alt={release.title}
                            class="coverArt"
                        />
                    {:else}
                        <div class="coverPlaceholder">💿</div>
                    {/if}
                    <div class="info">
                        <h3>{release.title}</h3>
                        <p>{release.primaryArtist} • {release.year} • {release.releaseType}</p>
                    </div>
                </div>
                <div class="actions">
                    <md-filled-button href="/upload?id={release.id}">Edit</md-filled-button>
                    <md-outlined-button
                        class="deleteButton"
                        onclick={() => deleteRelease(release.id)}
                        onkeydown={(e: KeyboardEvent) => {
                            if (e.key === 'Enter' || e.key === ' ') deleteRelease(release.id);
                        }}
                        role="button"
                        tabindex="0"
                        disabled={deleting === release.id}
                    >
                        {deleting === release.id ? 'Deleting...' : 'Delete'}
                    </md-outlined-button>
                </div>
            </div>
        {/each}

        {#if releases.length === 0}
            <p class="empty">No releases found.</p>
        {/if}
    </div>
</div>

<style>
    .managePage {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
    }

    h1 {
        margin-bottom: 2rem;
    }

    .releaseList {
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .releaseItem {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1rem;
        border-radius: 8px;
        background: var(--surface-color);
    }

    .releaseContent {
        display: flex;
        align-items: center;
        gap: 1rem;
    }

    .coverArt {
        width: 60px;
        height: 60px;
        object-fit: cover;
        border-radius: 4px;
    }

    .coverPlaceholder {
        width: 60px;
        height: 60px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(255, 255, 255, 0.1);
        border-radius: 4px;
        font-size: 24px;
    }

    .info h3 {
        margin: 0 0 0.25rem 0;
    }

    .info p {
        margin: 0;
        color: var(--text-secondary-color);
        font-size: 0.9rem;
    }

    .actions {
        display: flex;
        gap: 0.5rem;
    }

    .deleteButton {
        --md-outlined-button-label-text-color: var(--error-color);
    }

    .empty {
        text-align: center;
        color: var(--text-secondary-color);
        margin-top: 2rem;
    }
</style>
