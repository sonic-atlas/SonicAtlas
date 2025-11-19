<script lang="ts">
    import { apiPatch } from '$lib/api';
    import { socket } from '$lib/stores/socket.svelte';

    let { release: initialRelease, tracks: initialTracks } = $props<{
        release: any;
        tracks: any[];
    }>();

    let release = $state(initialRelease);
    let tracks = $state(initialTracks);
    let saving = $state(false);
    let message = $state<string | null>(null);

    $effect(() => {
        if (!socket.socket) return;

        const onStart = (data: { trackId: string }) => {
            const track = tracks.find((t: any) => t.id === data.trackId);
            if (track) track.transcodeStatus = 'processing';
        };

        const onDone = (data: { trackId: string }) => {
            const track = tracks.find((t: any) => t.id === data.trackId);
            if (track) track.transcodeStatus = 'done';
        };

        const onError = (data: { trackId: string; error: string }) => {
            const track = tracks.find((t: any) => t.id === data.trackId);
            if (track) {
                track.transcodeStatus = 'error';
                track.error = data.error;
            }
        };

        socket.socket.on('transcode:started', onStart);
        socket.socket.on('transcode:done', onDone);
        socket.socket.on('transcode:error', onError);

        return () => {
            socket.socket?.off('transcode:started', onStart);
            socket.socket?.off('transcode:done', onDone);
            socket.socket?.off('transcode:error', onError);
        };
    });

    async function saveRelease() {
        saving = true;
        message = null;
        try {
            const res = await apiPatch(
                `/api/releases/${release.id}`,
                JSON.stringify({
                    title: release.title,
                    primaryArtist: release.primaryArtist,
                    year: release.year,
                    releaseType: release.releaseType
                }),
                { 'Content-Type': 'application/json' }
            );

            if (!res.ok) throw new Error('Failed to save release');

            message = 'Release saved!';
            setTimeout(() => (message = null), 3000);
        } catch (err) {
            console.error(err);
            message = 'Error saving release';
        } finally {
            saving = false;
        }
    }

    async function saveTrack(track: any) {
        try {
            const res = await apiPatch(
                `/api/metadata/${track.id}`,
                JSON.stringify({
                    title: track.title,
                    artist: track.artist,
                    discNumber: track.discNumber ? parseInt(track.discNumber) : 1,
                    trackNumber: track.trackNumber ? parseInt(track.trackNumber) : null,
                    releaseId: release.id
                }),
                { 'Content-Type': 'application/json' }
            );

            if (!res.ok) throw new Error('Failed to save track');
        } catch (err) {
            console.error(err);
            alert('Failed to save track');
        }
    }
</script>

<div class="editor">
    <div class="release-info">
        <h2>Edit Release</h2>
        <div class="form-group">
            <label for="r-title">Title</label>
            <input id="r-title" type="text" bind:value={release.title} />
        </div>
        <div class="form-group">
            <label for="r-artist">Artist</label>
            <input id="r-artist" type="text" bind:value={release.primaryArtist} />
        </div>
        <div class="row">
            <div class="form-group">
                <label for="r-year">Year</label>
                <input id="r-year" type="number" bind:value={release.year} />
            </div>
            <div class="form-group">
                <label for="r-type">Type</label>
                <select id="r-type" bind:value={release.releaseType}>
                    <option value="album">Album</option>
                    <option value="ep">EP</option>
                    <option value="single">Single</option>
                    <option value="compilation">Compilation</option>
                </select>
            </div>
        </div>
        <button onclick={saveRelease} disabled={saving}>Save Release</button>
        {#if message}
            <span class="message">{message}</span>
        {/if}
    </div>

    <div class="track-list">
        <h3>Tracks</h3>
        {#each tracks as track (track.id)}
            <div class="track-item">
                <div
                    class="status"
                    class:done={track.transcodeStatus === 'done'}
                    class:processing={track.transcodeStatus === 'processing'}
                    class:error={track.transcodeStatus === 'error'}
                >
                    {#if track.transcodeStatus === 'done'}
                        ✓
                    {:else if track.transcodeStatus === 'processing'}
                        ⟳
                    {:else if track.transcodeStatus === 'error'}
                        ⚠
                    {:else}
                        •
                    {/if}
                </div>
                <div class="inputs">
                    <input
                        type="text"
                        bind:value={track.title}
                        onchange={() => saveTrack(track)}
                        placeholder="Title"
                    />
                    <input
                        type="text"
                        bind:value={track.artist}
                        onchange={() => saveTrack(track)}
                        placeholder="Artist"
                    />
                    <input
                        type="number"
                        class="small-input"
                        bind:value={track.discNumber}
                        onchange={() => saveTrack(track)}
                        placeholder="Disc"
                        title="Disc Number"
                    />
                    <input
                        type="number"
                        class="small-input"
                        bind:value={track.trackNumber}
                        onchange={() => saveTrack(track)}
                        placeholder="#"
                        title="Track Number"
                    />
                </div>
            </div>
        {/each}
    </div>
</div>

<style>
    .editor {
        display: flex;
        flex-direction: column;
        gap: 2rem;
        max-width: 800px;
    }

    .release-info {
        background: var(--surface-1);
        padding: 1.5rem;
        border-radius: 8px;
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .track-list {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .track-item {
        display: flex;
        align-items: center;
        gap: 1rem;
        background: var(--surface-1);
        padding: 0.75rem;
        border-radius: 4px;
    }

    .status {
        width: 24px;
        height: 24px;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
        background: var(--surface-2);
        font-weight: bold;
    }

    .status.done {
        color: var(--success);
        background: #00ff0020;
    }
    .status.processing {
        color: var(--primary);
        animation: spin 1s linear infinite;
    }
    .status.error {
        color: var(--error);
        background: #ff000020;
    }

    .inputs {
        display: flex;
        gap: 1rem;
        flex: 1;
    }

    input,
    select {
        padding: 0.5rem;
        border-radius: 4px;
        border: 1px solid var(--border);
        background: var(--surface-2);
        color: var(--text);
    }

    input {
        flex: 1;
    }

    .small-input {
        flex: 0 0 60px;
        text-align: center;
    }

    .form-group {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .row {
        display: flex;
        gap: 1rem;
    }

    .row .form-group {
        flex: 1;
    }

    button {
        padding: 0.75rem;
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-weight: bold;
        width: fit-content;
    }

    button:disabled {
        opacity: 0.7;
        cursor: not-allowed;
    }

    .message {
        color: var(--success);
        margin-left: 1rem;
    }

    @keyframes spin {
        from {
            transform: rotate(0deg);
        }
        to {
            transform: rotate(360deg);
        }
    }
</style>
