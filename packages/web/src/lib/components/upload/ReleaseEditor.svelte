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
    <div class="releaseInfo">
        <h2>Edit Release</h2>
        <div class="formGroup">
            <label for="r-title">Title</label>
            <input id="r-title" type="text" bind:value={release.title} />
        </div>
        <div class="formGroup">
            <label for="r-artist">Artist</label>
            <input id="r-artist" type="text" bind:value={release.primaryArtist} />
        </div>
        <div class="row">
            <div class="formGroup">
                <label for="r-year">Year</label>
                <input id="r-year" type="number" bind:value={release.year} />
            </div>
            <div class="formGroup">
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

    <div class="trackList">
        <h3>Tracks</h3>
        {#each tracks as track (track.id)}
            <div class="trackItem">
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
                        class="smallInput"
                        bind:value={track.discNumber}
                        onchange={() => saveTrack(track)}
                        placeholder="Disc"
                        title="Disc Number"
                    />
                    <input
                        type="number"
                        class="smallInput"
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

    .releaseInfo {
        background: var(--surface-color);
        padding: 1.5rem;
        border-radius: 8px;
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .trackList {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .trackItem {
        display: flex;
        align-items: center;
        gap: 1rem;
        background: var(--surface-color);
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
        background: var(--primary-surface-color);
        font-weight: bold;
    }

    .status.done {
        color: var(--success-color);
        background: #00ff0020;
    }
    .status.processing {
        color: var(--primary-color);
        animation: spin 1s linear infinite;
    }
    .status.error {
        color: var(--error-color);
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
        border: 1px solid var(--border-color);
        background: var(--primary-surface-color);
        color: var(--text-primary-color);
    }

    input {
        flex: 1;
    }

    .smallInput {
        flex: 0 0 60px;
        text-align: center;
    }

    .formGroup {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .row {
        display: flex;
        gap: 1rem;
    }

    .row .formGroup {
        flex: 1;
    }

    button {
        padding: 0.75rem;
        background: var(--primary-color);
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
        color: var(--success-color);
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
