<script lang="ts">
    import { apiPatch } from '$lib/api';
    import { socket } from '$lib/stores/socket.svelte';
    import { dndzone, type DndEvent } from 'svelte-dnd-action';
    import { flip } from 'svelte/animate';
    import '@material/web/textfield/outlined-text-field.js';
    import '@material/web/button/filled-button.js';
    import '@material/web/button/outlined-button.js';
    import '@material/web/select/outlined-select.js';
    import '@material/web/select/select-option.js';
    import '@material/web/icon/icon.js';
    import '@material/web/progress/linear-progress.js';
    import '@material/web/progress/circular-progress.js';

    let {
        release: initialRelease,
        tracks: initialTracks,
        isExistingRelease = false
    } = $props<{
        release: any;
        tracks: any[];
        isExistingRelease?: boolean;
    }>();

    let release = $state(initialRelease);

    const processedTracks = initialTracks.map((t: any) => {
        if (isExistingRelease && !t.transcodeStatus) {
            return { ...t, transcodeStatus: 'done' };
        }
        return t;
    });

    type Disc = {
        id: number;
        items: any[];
    };

    function groupTracks(flatTracks: any[]): Disc[] {
        const groups: Record<number, any[]> = {};
        flatTracks.forEach((t) => {
            const disc = t.discNumber || 1;
            if (!groups[disc]) groups[disc] = [];
            groups[disc].push(t);
        });

        if (Object.keys(groups).length === 0) {
            groups[1] = [];
        }

        return Object.entries(groups)
            .map(([k, v]) => ({
                id: parseInt(k),
                items: v.sort((a, b) => (a.trackNumber || 0) - (b.trackNumber || 0))
            }))
            .sort((a, b) => a.id - b.id);
    }

    let discs = $state<Disc[]>(groupTracks(processedTracks));
    let saving = $state(false);
    let message = $state<string | null>(null);

    let totalTracks = $derived(discs.reduce((acc, d) => acc + d.items.length, 0));
    let completedTracks = $derived(
        discs.reduce(
            (acc, d) => acc + d.items.filter((t: any) => t.transcodeStatus === 'done').length,
            0
        )
    );

    $effect(() => {
        if (!socket.socket) return;

        const findTrack = (id: string) => {
            for (const disc of discs) {
                const t = disc.items.find((x) => x.id === id);
                if (t) return t;
            }
            return null;
        };

        const onStart = (data: { trackId: string }) => {
            const track = findTrack(data.trackId);
            if (track) track.transcodeStatus = 'processing';
        };

        const onDone = (data: { trackId: string }) => {
            const track = findTrack(data.trackId);
            if (track) track.transcodeStatus = 'done';
        };

        const onError = (data: { trackId: string; error: string }) => {
            const track = findTrack(data.trackId);
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

    function handleDndConsider(discId: number, e: CustomEvent<DndEvent<any>>) {
        const discIndex = discs.findIndex((d) => d.id === discId);
        if (discIndex !== -1) {
            discs[discIndex].items = e.detail.items;
        }
    }

    function handleDndFinalize(discId: number, e: CustomEvent<DndEvent<any>>) {
        const discIndex = discs.findIndex((d) => d.id === discId);
        if (discIndex !== -1) {
            discs[discIndex].items = e.detail.items;
            updateTrackOrder(discId);
        }
    }

    async function updateTrackOrder(discId: number) {
        const disc = discs.find((d) => d.id === discId);
        if (!disc) return;

        for (let i = 0; i < disc.items.length; i++) {
            const track = disc.items[i];
            const newTrackNum = i + 1;

            if (track.trackNumber !== newTrackNum || track.discNumber !== discId) {
                track.trackNumber = newTrackNum;
                track.discNumber = discId;
                await saveTrack(track);
            }
        }
    }

    function addDisc() {
        const nextDiscNum = Math.max(0, ...discs.map((d) => d.id)) + 1;
        discs.push({ id: nextDiscNum, items: [] });
    }

    function removeDisc(discId: number) {
        const discIndex = discs.findIndex((d) => d.id === discId);
        if (discIndex !== -1 && discs[discIndex].items.length === 0) {
            discs.splice(discIndex, 1);
        } else {
            alert('Cannot remove disc with tracks. Move tracks first.');
        }
    }

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
            console.warn('Failed to save track sync');
        }
    }
</script>

<div class="editor">
    <div class="releaseInfo">
        <h2>Edit Release</h2>
        {#if totalTracks > 0}
            <div class="transcodeProgress">
                <div class="progressLabel">
                    {completedTracks === totalTracks ? 'Completed' : 'Processing'}
                    {completedTracks} / {totalTracks} tracks
                </div>
                <md-linear-progress value={completedTracks / totalTracks}></md-linear-progress>
            </div>
        {/if}
        <div class="formGroup">
            <md-outlined-text-field
                label="Title"
                value={release.title}
                oninput={(e: Event) => (release.title = (e.target as HTMLInputElement).value)}
            ></md-outlined-text-field>
        </div>
        <div class="formGroup">
            <md-outlined-text-field
                label="Artist"
                value={release.primaryArtist}
                oninput={(e: Event) =>
                    (release.primaryArtist = (e.target as HTMLInputElement).value)}
            ></md-outlined-text-field>
        </div>
        <div class="row">
            <div class="formGroup">
                <md-outlined-text-field
                    label="Year"
                    type="number"
                    value={release.year}
                    oninput={(e: Event) => (release.year = (e.target as HTMLInputElement).value)}
                ></md-outlined-text-field>
            </div>
            <div class="formGroup">
                <md-outlined-select
                    label="Type"
                    value={release.releaseType}
                    onchange={(e: Event) =>
                        (release.releaseType = (e.target as HTMLSelectElement).value)}
                >
                    <md-select-option value="album"
                        ><div slot="headline">Album</div></md-select-option
                    >
                    <md-select-option value="ep"><div slot="headline">EP</div></md-select-option>
                    <md-select-option value="single"
                        ><div slot="headline">Single</div></md-select-option
                    >
                    <md-select-option value="compilation"
                        ><div slot="headline">Compilation</div></md-select-option
                    >
                </md-outlined-select>
            </div>
        </div>
        <md-filled-button
            onclick={saveRelease}
            disabled={saving}
            onkeydown={(e: KeyboardEvent) => {
                if (e.key === 'Enter' || e.key === ' ') saveRelease();
            }}
            role="button"
            tabindex="0">Save Release</md-filled-button
        >
        {#if message}
            <span class="message">{message}</span>
        {/if}
    </div>

    <div class="trackList">
        <div class="headerRow">
            <h3>Tracks</h3>
            <md-filled-button
                onclick={addDisc}
                onkeydown={(e: KeyboardEvent) => {
                    if (e.key === 'Enter' || e.key === ' ') addDisc();
                }}
                role="button"
                tabindex="0">Add Disc</md-filled-button
            >
        </div>

        {#each discs as disc (disc.id)}
            <div class="discSection">
                <div class="discHeader">
                    <h4>Disc {disc.id}</h4>
                    {#if discs.length > 1}
                        <md-outlined-button
                            onclick={() => removeDisc(disc.id)}
                            onkeydown={(e: KeyboardEvent) => {
                                if (e.key === 'Enter' || e.key === ' ') removeDisc(disc.id);
                            }}
                            role="button"
                            tabindex="0"
                            class="removeDiscButton">Remove Disc</md-outlined-button
                        >
                    {/if}
                </div>

                <section
                    use:dndzone={{
                        items: disc.items,
                        flipDurationMs: 300,
                        dropTargetStyle: { outline: '2px dashed var(--primary-color)' }
                    }}
                    onconsider={(e) => handleDndConsider(disc.id, e)}
                    onfinalize={(e) => handleDndFinalize(disc.id, e)}
                    class="dndZone"
                >
                    {#each disc.items as track (track.id)}
                        <div class="trackItem" animate:flip={{ duration: 300 }}>
                            <div class="dragHandle">
                                <md-icon>drag_indicator</md-icon>
                            </div>
                            <div
                                class="status"
                                class:done={track.transcodeStatus === 'done'}
                                class:processing={track.transcodeStatus === 'processing'}
                                class:error={track.transcodeStatus === 'error'}
                            >
                                {#if track.transcodeStatus === 'done'}
                                    <md-icon class="iconDone">check_circle</md-icon>
                                {:else if track.transcodeStatus === 'processing'}
                                    <md-circular-progress indeterminate class="processingSpinner"
                                    ></md-circular-progress>
                                {:else if track.transcodeStatus === 'error'}
                                    <md-icon class="iconError">error</md-icon>
                                {:else}
                                    <md-icon class="iconPending">radio_button_unchecked</md-icon>
                                {/if}
                            </div>
                            <div class="inputs">
                                <md-outlined-text-field
                                    label="Title"
                                    value={track.title}
                                    oninput={(e: Event) => {
                                        track.title = (e.target as HTMLInputElement).value;
                                    }}
                                    onchange={() => saveTrack(track)}
                                ></md-outlined-text-field>
                                <md-outlined-text-field
                                    label="Artist"
                                    value={track.artist}
                                    onchange={() => saveTrack(track)}
                                    oninput={(e: Event) =>
                                        (track.artist = (e.target as HTMLInputElement).value)}
                                ></md-outlined-text-field>
                            </div>
                        </div>
                    {/each}
                </section>
                {#if disc.items.length === 0}
                    <div class="emptyDiscPlaceholder">Drag tracks here</div>
                {/if}
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
        background: var(--surface-dim);
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

    .headerRow {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1rem;
    }

    .discSection {
        background: var(--surface-base);
        border: 1px solid var(--border-color);
        border-radius: 8px;
        padding: 1rem;
        margin-bottom: 1rem;
    }

    .discHeader {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1rem;
    }

    .discHeader h4 {
        margin: 0;
    }

    .dndZone {
        min-height: 50px;
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .dragHandle {
        cursor: grab;
        color: var(--text-secondary-color);
        display: flex;
        align-items: center;
    }

    .trackItem {
        background: var(--surface-color);
        border: 1px solid var(--border-color);
    }

    .emptyDiscPlaceholder {
        padding: 2rem;
        text-align: center;
        color: var(--text-secondary-color);
        border: 2px dashed var(--border-color);
        border-radius: 4px;
    }

    .transcodeProgress {
        background: var(--surface-base);
        padding: 1rem;
        border-radius: 8px;
        margin-bottom: 1rem;
        border: 1px solid var(--border-color);
    }

    .progressLabel {
        margin-bottom: 0.5rem;
        font-size: 0.875rem;
        color: var(--text-secondary-color);
    }

    md-linear-progress {
        width: 100%;
        --md-linear-progress-track-shape: 4px;
        --md-linear-progress-active-indicator-height: 8px;
        --md-linear-progress-track-height: 8px;
    }

    .status md-icon {
        font-size: 18px;
    }

    .iconDone {
        color: var(--success-color);
    }
    .iconError {
        color: var(--error-color);
    }
    .iconPending {
        color: var(--text-secondary-color);
        opacity: 0.5;
    }

    .removeDiscButton {
        --md-outlined-button-label-text-color: var(--error-color);
    }

    .processingSpinner {
        --md-circular-progress-size: 24px;
    }
</style>
