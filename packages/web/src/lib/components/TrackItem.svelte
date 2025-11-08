<script lang="ts">
    import type { Track, TrackMetadata } from '$lib/types';
    import { apiGet, API_BASE_URL } from '$lib/api';

    interface Props {
        track: Track;
        isPlaying: boolean;
        onClick: () => void;
    }

    let { track, isPlaying, onClick }: Props = $props();

    let metadata = $state<TrackMetadata | null>(null);

    async function loadMetadata() {
        const res = await apiGet(`/api/metadata/${track.id}`);
        if (res.ok) {
            metadata = await res.json();
        }
    }

    $effect(() => {
        loadMetadata();
    });

    function formatFileSize(bytes: number): string {
        const mb = bytes / (1024 * 1024);
        return `${mb.toFixed(2)} MB`;
    }
</script>

<button class="trackItem" class:playing={isPlaying} onclick={onClick}>
    <div class="thumbnail">
        {#if track.coverArtPath}
            <img src={`${API_BASE_URL}${track.coverArtPath}`} alt="Cover" />
        {:else}
            <div class="icon">{isPlaying ? '▶' : '🎵'}</div>
        {/if}
    </div>

    <div class="info">
        <div class="title">
            {metadata?.title || track.originalFilename || track.filename}
        </div>
        <div class="details">
            <span>{metadata?.artist || 'Unknown Artist'}</span>
            {#if metadata?.album}
                <span>· {metadata.album}</span>
            {/if}
        </div>
        <div class="techInfo">
            {#if metadata?.codec}
                <span class="badge">{metadata.codec.toUpperCase()}</span>
            {/if}
            {#if metadata?.bitrate}
                <span class="badge">{Math.round(metadata.bitrate / 1000)}kbps</span>
            {/if}
            {#if metadata?.sampleRate}
                <span class="badge">{(metadata.sampleRate / 1000).toFixed(1)}kHz</span>
            {/if}
            <span class="badge">{formatFileSize(track.fileSize)}</span>
        </div>
    </div>
</button>

<style>
    .trackItem {
        display: flex;
        gap: 12px;
        padding: 12px;
        border: 1px solid var(--text-secondary-color);
        border-radius: 8px;
        background: var(--background);
        cursor: pointer;
        text-align: left;
        transition: all 0.2s;
        width: 100%;
    }

    .trackItem:hover {
        background: var(--surface-color);
    }

    .trackItem.playing {
        border-color: var(--primary-color);
        background: var(--surface-color);
    }

    .thumbnail {
        width: 60px;
        height: 60px;
        flex-shrink: 0;
        border-radius: 6px;
        overflow: hidden;
        background: var(--surface-color);
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .thumbnail img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .icon {
        font-size: 24px;
    }

    .info {
        flex: 1;
        min-width: 0;
    }

    .title {
        font-weight: bold;
        margin-bottom: 4px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        color: var(--text-primary-color);
    }

    .details {
        font-size: 13px;
        color: var(--text-secondary-color);
        margin-bottom: 6px;
    }

    .techInfo {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
    }

    .badge {
        font-size: 10px;
        background: var(--surface-color);
        padding: 2px 6px;
        border-radius: 3px;
        color: var(--text-secondary-color);
        font-weight: 500;
    }

    .playing .badge {
        background: var(--primary-color);
        color: var(--text-primary-color);
    }
</style>
