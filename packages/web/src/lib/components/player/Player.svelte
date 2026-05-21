<script lang="ts">
    import '@material/web/icon/icon.js';
    import '@material/web/progress/linear-progress.js';
    import '@material/web/progress/circular-progress.js';
    import '@material/web/slider/slider.js';
    import type { Quality, QualityInfo } from '$lib/types';
    import QualitySelector from './QualitySelector.svelte';
    import { API_BASE_URL } from '$lib/api';
    import { audioPlayer } from '$lib/engine';
    import { engineState } from '$lib/stores/engineStore';

    interface Props {
        oncloseplayer?: () => void;
    }

    let { oncloseplayer = $bindable() }: Props = $props();

    let hoverTime = $state<number | null>(null);
    let progressBarElement: HTMLDivElement;

    const quality = $derived($engineState.quality);
    const loading = $derived($engineState.loading);
    const track = $derived($engineState.track);
    const metadata = $derived($engineState.metadata);
    const isAdaptive = $derived($engineState.isAdaptive);
    const volume = $derived($engineState.volume);
    const isMuted = $derived($engineState.isMuted);
    const currentTime = $derived($engineState.currentTime);
    const duration = $derived($engineState.duration);
    const isPlaying = $derived($engineState.isPlaying);

    $effect(() => {
        console.log('Loading state changed:', loading);
    });

    const qualityInfoMap: Record<Quality, QualityInfo> = {
        auto: { label: 'Auto (ABR)', codec: 'Adaptive', bitrate: 'Varies' },
        efficiency: { label: 'Efficiency', codec: 'Opus', bitrate: '128k' },
        high: { label: 'High', codec: 'Opus', bitrate: '320k' },
        cd: { label: 'CD', codec: 'FLAC', sampleRate: '44.1kHz' },
        hires: { label: 'Hi-Res', codec: 'FLAC', sampleRate: 'Original' }
    };

    let currentQualityInfo = $derived.by(() => {
        const info = { ...qualityInfoMap[quality] };
        if (quality === 'hires' && metadata?.sampleRate) {
            info.sampleRate = `${metadata.sampleRate / 1000}kHz`;
        }
        return info;
    });

    function preloadImage(url: string) {
        const img = new Image();
        img.src = url;
    }

    function handleProgressHover(e: MouseEvent) {
        if (!progressBarElement || !audioPlayer.state.duration) return;

        const rect = progressBarElement.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const percentage = Math.max(0, Math.min(1, x / rect.width));
        hoverTime = percentage * audioPlayer.state.duration;
    }

    function handleProgressLeave() {
        hoverTime = null;
    }

    function handleProgressClick(e: MouseEvent) {
        if (!progressBarElement || !audioPlayer.hasAudio || !audioPlayer.state.duration) return;

        const rect = progressBarElement.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const percentage = Math.max(0, Math.min(1, x / rect.width));
        const newTime = percentage * audioPlayer.state.duration;

        audioPlayer.setAudioCurrentTime(newTime);
        audioPlayer.setCurrentTime(newTime);
    }

    function handleProgressKeyDown(e: KeyboardEvent) {
        if (!audioPlayer.hasAudio || !audioPlayer.state.duration) return;

        const step = 5;

        switch (e.key) {
            case 'ArrowLeft':
                e.preventDefault();
                audioPlayer.setAudioCurrentTime(Math.max(0, audioPlayer.audioCurrentTime - step));
                break;
            case 'ArrowRight':
                e.preventDefault();
                audioPlayer.setAudioCurrentTime(Math.min(audioPlayer.state.duration, audioPlayer.audioCurrentTime + step));
                break;
            case 'Home':
                e.preventDefault();
                audioPlayer.setAudioCurrentTime(0);
                break;
            case 'End':
                e.preventDefault();
                audioPlayer.setAudioCurrentTime(audioPlayer.state.duration);
                break;
            case ' ':
            case 'Enter':
                e.preventDefault();
                audioPlayer.togglePlay();
                break;
        }
    }

    function formatTime(seconds: number): string {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    $effect(() => {
        if (!track?.coverArtPath) return;
        preloadImage(`${API_BASE_URL}${track.coverArtPath}`);
    });
</script>

<div class="player">
    <h2>Now Playing</h2>

    <div class="cover">
        {#if track?.coverArtPath}
            <img src={`${API_BASE_URL}${track.coverArtPath}`} alt="Album cover" />
        {:else}
            <div class="icon">
                <md-icon class="coverIcon">music_note</md-icon>
            </div>
        {/if}
    </div>

    <div class="trackInfo">
        <div class="title">{metadata?.title || track?.originalFilename || track?.filename}</div>
        <div class="info">{metadata?.artist || 'Unknown Artist'}</div>
        {#if metadata?.album}
            <div class="info">{metadata.album}</div>
        {/if}
        {#if metadata?.year}
            <div class="info">{metadata.year}</div>
        {/if}
    </div>

    <QualitySelector />

    <div class="progress">
        <div
            class="progressContainer"
            bind:this={progressBarElement}
            onmousemove={handleProgressHover}
            onmouseleave={handleProgressLeave}
            onclick={handleProgressClick}
            onkeydown={handleProgressKeyDown}
            role="slider"
            aria-label="Seek"
            aria-valuemin={0}
            aria-valuenow={currentTime}
            tabindex="0"
        >
            <div class="progressTrack">
                {#if loading}
                    <div class="progressBuffering"></div>
                {/if}
                <div class="progressFilled" style="width: {duration > 0 ? (currentTime / duration) * 100 : 0}%"></div>
            </div>
            {#if hoverTime !== null}
                <div class="progressHover" style="left: {duration > 0 ? (hoverTime / duration) * 100 : 0}%">
                    <div class="hoverTimeTooltip">
                        {formatTime(hoverTime)}
                    </div>
                </div>
            {/if}
        </div>
        <div class="time">
            <span>{formatTime(currentTime)}</span>
            <span>{formatTime(duration)}</span>
        </div>
    </div>

    <div class="controls">
        <button
            onclick={(e) => {
                audioPlayer.togglePlay();
            }}
            aria-label={isPlaying ? 'Pause' : 'Play'}
        >
            <md-icon class="playIcon">{isPlaying ? 'pause' : 'play_arrow'}</md-icon>
        </button>
    </div>

    <div class="footerRow">
        <div class="qualityBadge">
            <div class="qualityDetails">
                {#if isAdaptive}
                    {currentQualityInfo.codec} <br /> ABR
                {:else}
                    {currentQualityInfo.codec}
                    {#if currentQualityInfo.bitrate}
                        <br /> {currentQualityInfo.bitrate}
                    {/if}
                    {#if currentQualityInfo.sampleRate}
                        <br />{currentQualityInfo.sampleRate}
                    {/if}
                {/if}
            </div>
        </div>

        <div class="volumeControls">
            <md-icon-button
                onclick={audioPlayer.toggleMute}
                onkeydown={(e: KeyboardEvent) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        audioPlayer.toggleMute();
                        e.preventDefault();
                    }
                }}
                role="button"
                tabindex="0"
            >
                <md-icon>{volume === 0 || isMuted ? 'volume_off' : volume < 50 ? 'volume_down' : 'volume_up'}</md-icon>
            </md-icon-button>
            <md-slider min="0" max="100" value={volume} oninput={audioPlayer.handleVolumeChange}></md-slider>
            <span class="volumeText">{Math.round(volume)}%</span>
        </div>
    </div>
</div>

<style>
    .player {
        display: flex;
        flex-direction: column;
        height: 100%;
        background: transparent;
        overflow: hidden;
    }

    h2 {
        margin-top: 0;
        color: var(--text-primary-color);
        text-align: center;
        flex-shrink: 0;
    }

    .cover {
        flex: 1;
        min-height: 0;
        background: var(--surface-color);
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-bottom: 20px;
        width: 100%;
        overflow: hidden;
    }

    .cover img {
        width: 100%;
        height: 100%;
        object-fit: contain;
        border-radius: 8px;
    }

    .icon {
        font-size: 80px;
    }

    .trackInfo {
        margin-bottom: 20px;
    }

    .title {
        font-size: 20px;
        font-weight: bold;
        margin-bottom: 8px;
        color: var(--text-primary-color);
    }

    .info {
        font-size: 16px;
        color: var(--text-secondary-color);
        margin-bottom: 4px;
    }

    .qualityBadge {
        background: var(--surface-color);
        border: 1px solid var(--secondary-color);
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 20px;
    }

    .qualityDetails {
        font-size: 12px;
        color: var(--text-secondary-color);
    }

    .controls {
        display: flex;
        justify-content: center;
        margin-bottom: 20px;
    }

    .controls button {
        width: 60px;
        height: 60px;
        font-size: 24px;
        border-radius: 50%;
        border: none;
        background: var(--primary-color);
        color: var(--text-primary-color);
        cursor: pointer;
        transition: opacity 0.2s;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .controls button:hover:not(:disabled) {
        opacity: 0.9;
    }

    .controls button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .volumeControls {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 20px;
        padding: 0 10px;
    }

    .volumeControls md-slider {
        flex: 1;
        --md-slider-handle-height: 12px;
        --md-slider-handle-width: 12px;
    }

    .progress {
        margin-top: 20px;
    }

    .progressContainer {
        position: relative;
        margin-bottom: 8px;
        padding: 8px 0;
        cursor: pointer;
    }

    .progressTrack {
        position: relative;
        width: 100%;
        height: 6px;
        background: var(--surface-highest);
        border-radius: 3px;
        overflow: hidden;
    }

    .progressContainer:hover .progressTrack {
        cursor: pointer;
    }

    .progressFilled {
        position: absolute;
        top: 0;
        left: 0;
        height: 100%;
        background: var(--primary-color);
        border-radius: 3px;
        transition: width 0.1s linear;
        pointer-events: none;
        z-index: 2;
    }

    .progressBuffering {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: repeating-linear-gradient(
            to right,
            var(--surface-color) 0%,
            var(--text-secondary-color) 50%,
            var(--surface-color) 100%
        );
        background-size: 50% 100%;
        animation: shimmer 1s infinite linear;
        z-index: 1;
        opacity: 0.3;
    }

    @keyframes shimmer {
        from {
            background-position: -50% 0;
        }
        to {
            background-position: 150% 0;
        }
    }

    .progressHover {
        position: absolute;
        top: 50%;
        transform: translate(-50%, -50%);
        width: 14px;
        height: 14px;
        background: var(--primary-color);
        border-radius: 50%;
        pointer-events: none;
        z-index: 3;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
    }

    .hoverTimeTooltip {
        position: absolute;
        bottom: 24px;
        left: 50%;
        transform: translateX(-50%);
        background: var(--surface-color);
        color: var(--text-primary-color);
        padding: 4px 8px;
        border-radius: 4px;
        font-size: 12px;
        white-space: nowrap;
        border: 1px solid var(--primary-color);
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    }

    .hoverTimeTooltip::after {
        content: '';
        position: absolute;
        top: 100%;
        left: 50%;
        transform: translateX(-50%);
        border: 4px solid transparent;
        border-top-color: var(--surface-color);
    }

    .footerRow {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-top: 10px;
    }

    .footerRow .qualityBadge {
        margin-bottom: 0;
        padding: 8px 12px;
        flex-shrink: 0;
        min-width: 80px;
        height: 52px;
        display: flex;
        align-items: center;
        justify-content: center;
        box-sizing: border-box;
    }

    .footerRow .volumeControls {
        margin-bottom: 0;
        flex: 1;
        padding: 0;
        min-width: 0;
    }

    .footerRow .volumeControls md-slider {
        min-width: 0;
    }

    .volumeText {
        font-size: 12px;
        color: var(--text-secondary-color);
        min-width: 32px;
        text-align: right;
    }

    .time {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        color: var(--text-secondary-color);
    }

    .coverIcon {
        font-size: 80px;
    }

    .trackInfo {
        margin-bottom: 20px;
        text-align: center;
    }

    .playIcon {
        font-size: 32px;
    }
</style>
