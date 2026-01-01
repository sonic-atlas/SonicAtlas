<script lang="ts">
    import '@material/web/list/list.js';
    import type { Track } from '$lib/types';
    import TrackItem from './TrackItem.svelte';

    interface Props {
        tracks: Track[];
        onTrackSelect: (track: Track) => void;
        currentTrackId?: string;
    }

    let { tracks, onTrackSelect, currentTrackId }: Props = $props();
</script>

<div class="trackListContainer">
    <h2>Tracks</h2>

    {#if tracks.length === 0}
        <p>No tracks uploaded yet</p>
    {:else}
        <md-list>
            {#each tracks as track (track.id)}
                <TrackItem
                    {track}
                    isPlaying={currentTrackId === track.id}
                    onClick={() => onTrackSelect(track)}
                />
            {/each}
        </md-list>
    {/if}
</div>

<style>
    .trackListContainer {
        padding: 0;
    }

    h2 {
        margin: 0 0 16px 16px;
        color: var(--text-primary-color);
        font-family: var(--md-sys-typescale-title-large-font);
        font-weight: 500;
    }

    md-list {
        background: transparent;
        --md-list-container-color: transparent;
        padding-bottom: 80px;
    }

    p {
        margin-left: 16px;
        color: var(--text-secondary-color);
        font-family: var(--md-sys-typescale-body-medium-font);
    }
</style>
