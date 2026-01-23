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

    function formatDuration(seconds: number): string {
        const min = Math.floor(seconds / 60);
        const sec = Math.floor(seconds % 60);
        return `${min}:${sec.toString().padStart(2, '0')}`;
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
    <div slot="start" class="startSlot">
        <div class="trackIndex">
            {#if isPlaying}
                <md-icon class="playingIcon">equalizer</md-icon>
            {:else}
                <span class="number">{track.trackNumber || '-'}</span>
            {/if}
        </div>
        <div class="thumbnail">
            {#if track.coverArtPath}
                <img use:lazyLoad={`${API_BASE_URL}${track.coverArtPath}?size=small`} alt="Cover" />
            {:else}
                <div class="placeholder">
                    <md-icon>music_note</md-icon>
                </div>
            {/if}
        </div>
    </div>

    <div slot="headline" class="headline">
        <span class:active={isPlaying}
            >{track.metadata?.title || track.originalFilename || track.filename}</span
        >
    </div>
    <div slot="supporting-text" class="supportingText">
        {track.metadata?.artist || track.releaseArtist}
    </div>

    <div slot="end" class="endSlot">
        <div class="techInfo">
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
        </div>
        <div class="duration">
            {formatDuration(track.duration || 0)}
        </div>
    </div>
</md-list-item>

<style>
    md-list-item {
        border-radius: 4px;
        margin-bottom: 0;
        --md-list-item-leading-space: 16px;
        --md-list-item-trailing-space: 16px;
        --md-list-item-list-item-container-color: transparent;
        --md-list-item-hover-state-layer-color: var(--on-surface);
        --md-list-item-hover-state-layer-opacity: 0.08;
    }

    .playing {
        --md-list-item-label-text-color: var(--primary-color);
        --md-list-item-leading-icon-color: var(--primary-color);
        background-color: var(--surface-container-highest);
    }

    .active {
        color: var(--primary-color);
    }

    .startSlot {
        display: flex;
        align-items: center;
        gap: 16px;
    }

    .trackIndex {
        width: 24px;
        display: flex;
        justify-content: center;
        align-items: center;
        color: var(--text-secondary-color);
        font-family: var(--md-sys-typescale-body-medium-font);
        font-feature-settings: 'tnum';
    }

    .thumbnail {
        width: 40px;
        height: 40px;
        border-radius: 4px;
        overflow: hidden;
        background: var(--surface-variant);
        flex-shrink: 0;
    }

    .thumbnail img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .placeholder {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--text-secondary-color);
    }

    .placeholder md-icon {
        font-size: 20px;
    }

    .number {
        font-size: 14px;
    }

    .playingIcon {
        font-size: 18px;
        color: var(--primary-color);
    }

    .headline {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        font-family: var(--md-sys-typescale-body-large-font);
        font-size: 1rem;
        color: var(--text-primary-color);
    }

    .supportingText {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        color: var(--text-secondary-color);
    }

    .endSlot {
        display: flex;
        align-items: center;
        gap: 16px;
    }

    .techInfo {
        display: flex;
        gap: 6px;
        align-items: center;
    }

    .badge {
        font-size: 11px;
        font-weight: 500;
        color: var(--text-secondary-color);
        background: var(--surface-variant);
        padding: 2px 6px;
        border-radius: 4px;
        font-family: var(--md-sys-typescale-label-small-font);
        opacity: 0.8;
    }

    .duration {
        font-family: var(--md-sys-typescale-body-medium-font);
        color: var(--text-secondary-color);
        font-feature-settings: 'tnum';
        font-size: 14px;
        min-width: 40px;
        text-align: right;
    }
</style>
