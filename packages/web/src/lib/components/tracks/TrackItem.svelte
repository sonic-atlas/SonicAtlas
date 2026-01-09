<script lang="ts">
    import '@material/web/list/list-item.js';
    import '@material/web/icon/icon.js';
    import type { Track } from '$lib/types';
    import { API_BASE_URL } from '$lib/api';

    interface Props {
        track: Track;
        isPlaying: boolean;
        onClick: () => void;
    }

    let { track, isPlaying, onClick }: Props = $props();

    function formatFileSize(bytes: number): string {
        const mb = bytes / (1024 * 1024);
        return `${mb.toFixed(2)} MB`;
    }

    function lazyLoad(node: HTMLImageElement, src: string) {
        const observer = new IntersectionObserver((entries) => {
            if (entries[0].isIntersecting) {
                node.src = src;
                observer.disconnect();
            }
        });

        observer.observe(node);

        return {
            destroy() {
                observer.disconnect();
            }
        };
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
            <img use:lazyLoad={`${API_BASE_URL}${track.coverArtPath}?size=small`} alt="Cover" />
        {:else}
            <md-icon>{isPlaying ? 'equalizer' : 'music_note'}</md-icon>
        {/if}
    </div>

    <div slot="headline" class="headline">
        {track.metadata?.title || track.originalFilename || track.filename}
    </div>
    <div slot="supporting-text" class="supportingText">
        {track.metadata?.artist || track.releaseArtist}
        · {track.releaseTitle}
        · {track.releaseYear}
    </div>

    <div slot="end" class="techInfo">
        {#if track.metadata?.codec}
            <span class="badge">{track.metadata.codec.toUpperCase()}</span>
        {/if}
        {#if track.metadata?.bitrate}
            <span class="badge">{Math.round(track.metadata.bitrate / 1000)}k</span>
        {/if}
        {#if track.sampleRate}
            <span class="badge">{(track.sampleRate / 1000).toFixed(1)}kHz</span>
        {/if}
        {#if track.bitDepth}
            <span class="badge">{track.bitDepth}bit</span>
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
