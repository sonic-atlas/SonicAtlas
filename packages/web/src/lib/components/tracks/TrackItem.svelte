<script lang="ts">
    import '@material/web/list/list-item.js';
    import '@material/web/icon/icon.js';
    import type { Track, TrackMetadata } from '$lib/types';
    import { apiGet, API_BASE_URL } from '$lib/api';

    interface Props {
        track: Track;
        isPlaying: boolean;
        onClick: () => void;
    }

    let { track, isPlaying, onClick }: Props = $props();

    let metadata = $state<TrackMetadata | null>(null);
    let releaseYear = $state<number | null>(null);
    let releaseTitle = $state<string | null>(null);

    async function loadMetadata() {
        const res = await apiGet(`/api/metadata/${track.id}`);
        if (res.ok) {
            metadata = await res.json();
        }
    }

    async function loadRelease() {
        if (track.releaseId) {
            const res = await apiGet(`/api/releases/${track.releaseId}`);
            if (res.ok) {
                const data = await res.json();
                if (data.release) {
                    releaseYear = data.release.year;
                    releaseTitle = data.release.title;
                }
            }
        }
    }

    $effect(() => {
        loadMetadata();
        loadRelease();
    });

    function formatFileSize(bytes: number): string {
        const mb = bytes / (1024 * 1024);
        return `${mb.toFixed(2)} MB`;
    }
</script>

<md-list-item
    type="button"
    onclick={onClick}
    onkeydown={(e: KeyboardEvent) => {
        if (e.key === 'Enter' || e.key === ' ') onClick();
    }}
    role="button"
    tabindex="0"
    class:playing={isPlaying}
>
    <div slot="start" class="thumbnail">
        {#if track.coverArtPath}
            <img src={`${API_BASE_URL}${track.coverArtPath}?size=small`} alt="Cover" />
        {:else}
            <md-icon>{isPlaying ? 'equalizer' : 'music_note'}</md-icon>
        {/if}
    </div>

    <div slot="headline" class="headline">
        {metadata?.title || track.originalFilename || track.filename}
    </div>
    <div slot="supporting-text" class="supportingText">
        {metadata?.artist || 'Unknown Artist'}
        · {releaseTitle}
        · {releaseYear}
    </div>

    <div slot="end" class="techInfo">
        {#if metadata?.codec}
            <span class="badge">{metadata.codec.toUpperCase()}</span>
        {/if}
        {#if metadata?.bitrate}
            <span class="badge">{Math.round(metadata.bitrate / 1000)}k</span>
        {/if}
        {#if metadata?.sampleRate}
            <span class="badge">{(metadata.sampleRate / 1000).toFixed(1)}kHz</span>
        {/if}
        {#if metadata?.bitDepth}
            <span class="badge">{metadata.bitDepth}bit</span>
        {/if}
        <span class="badge">{formatFileSize(track.fileSize)}</span>
    </div>
</md-list-item>

<style>
    md-list-item {
        border-radius: 12px;
        margin-bottom: 4px;
        --md-list-item-leading-space: 8px;
        --md-list-item-trailing-space: 16px;
    }

    .playing {
        --md-list-item-container-color: var(--primary-container);
        --md-list-item-label-text-color: var(--on-primary-container);
        --md-list-item-supporting-text-color: var(--on-primary-container);
        --md-list-item-leading-icon-color: var(--on-primary-container);
        --md-list-item-trailing-supporting-text-color: var(--on-primary-container);
    }

    .thumbnail {
        width: 48px;
        height: 48px;
        border-radius: 8px;
        overflow: hidden;
        background: var(--surface-high);
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--text-secondary-color);
    }

    .thumbnail img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .headline {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .supportingText {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .techInfo {
        display: flex;
        gap: 4px;
        align-items: center;
    }

    .badge {
        font-size: 10px;
        padding: 2px 6px;
        border-radius: 4px;
        background: var(--surface-high);
        color: var(--text-secondary-color);
        font-family: var(--md-sys-typescale-label-small-font);
    }

    .playing .badge {
        background: rgba(0, 0, 0, 0.1);
        color: inherit;
    }
</style>
