<script lang="ts">
    import { apiDelete, API_BASE_URL } from '$lib/api';
    import { invalidateAll } from '$app/navigation';

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

<div class="manage-page">
    <h1>Manage Releases</h1>

    <div class="release-list">
        {#each releases as release (release.id)}
            <div class="release-item">
                <div class="release-content">
                    {#if release.coverArtPath}
                        <img
                            src="{API_BASE_URL}{release.coverArtPath}"
                            alt={release.title}
                            class="cover-art"
                        />
                    {:else}
                        <div class="cover-placeholder">💿</div>
                    {/if}
                    <div class="info">
                        <h3>{release.title}</h3>
                        <p>{release.primaryArtist} • {release.year} • {release.releaseType}</p>
                    </div>
                </div>
                <div class="actions">
                    <a href="/upload?id={release.id}" class="editButton">Edit</a>
                    <button
                        class="deleteButton"
                        onclick={() => deleteRelease(release.id)}
                        disabled={deleting === release.id}
                    >
                        {deleting === release.id ? 'Deleting...' : 'Delete'}
                    </button>
                </div>
            </div>
        {/each}

        {#if releases.length === 0}
            <p class="empty">No releases found.</p>
        {/if}
    </div>
</div>

<style>
    .manage-page {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
    }

    h1 {
        margin-bottom: 2rem;
    }

    .release-list {
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .release-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 1rem;
        border-radius: 8px;
        background: var(--surface-color);
    }

    .release-content {
        display: flex;
        align-items: center;
        gap: 1rem;
    }

    .cover-art {
        width: 60px;
        height: 60px;
        object-fit: cover;
        border-radius: 4px;
    }

    .cover-placeholder {
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
        padding: 8px 16px;
        background: #f44336;
        color: var(--text-primary-color);
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-size: 14px;
        transition: opacity 0.2s;
    }

    .deleteButton:hover {
        opacity: 0.9;
    }

    .deleteButton:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .editButton {
        padding: 8px 16px;
        background: var(--primary-color);
        color: var(--text-primary-color);
        border: none;
        border-radius: 6px;
        cursor: pointer;
        text-decoration: none;
        font-size: 14px;
        transition: opacity 0.2s;
    }

    .editButton:hover {
        opacity: 0.9;
    }

    .editButton:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .empty {
        text-align: center;
        color: var(--text-secondary-color);
        margin-top: 2rem;
    }
</style>
