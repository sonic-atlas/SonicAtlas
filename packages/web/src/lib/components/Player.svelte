<script lang="ts">
    import type { Track, TrackMetadata, Quality, QualityInfo } from '$lib/types';
    import QualitySelector from './QualitySelector.svelte';
    import { apiGet, getStreamUrl, API_BASE_URL } from '$lib/api';

    interface Props {
        track: Track;
        quality: Quality;
    }

    let { track, quality = $bindable() }: Props = $props();

    let audio: HTMLAudioElement;
    let isPlaying = $state(false);
    let currentTime = $state(0);
    let duration = $state(0);
    let loading = $state(false);
    let metadata = $state<TrackMetadata | null>(null);

    $effect(() => {
        console.log('Loading state changed:', loading);
    });

    let streamUrl = $state('');
    
    $effect(() => {
        try {
            console.log('Getting stream URL for track:', track.id, 'quality:', quality);
            streamUrl = getStreamUrl(track.id, quality);
            console.log('Stream URL generated:', streamUrl);
        } catch (err) {
            console.error('Failed to get stream URL:', err);
            streamUrl = '';
        }
    });

    const qualityInfoMap: Record<Quality, QualityInfo> = {
        efficiency: { label: 'Efficiency', codec: 'AAC', bitrate: '128k' },
        high: { label: 'High', codec: 'AAC', bitrate: '320k' },
        cd: { label: 'CD', codec: 'FLAC', sampleRate: '44.1kHz' },
        hires: { label: 'Hi-Res', codec: 'FLAC', sampleRate: 'Original' }
    };

    let currentQualityInfo = $derived(qualityInfoMap[quality]);

    async function loadMetadata() {
        const res = await apiGet(`/api/metadata/${track.id}`);
        if (res.ok) {
            metadata = await res.json();
        }
    }

    function togglePlay() {
        if (!audio) {
            console.error('Audio element not bound');
            return;
        }

        console.log('Toggle play:', { isPlaying, streamUrl, quality });

        if (isPlaying) {
            audio.pause();
        } else {
            loading = true;
            audio.play().catch(err => {
                console.error('Play failed:', err);
                loading = false;
            });
        }
    }

    function handlePlay() {
        isPlaying = true;
        loading = false;
    }

    function handlePause() {
        isPlaying = false;
    }

    function handleTimeUpdate() {
        if (audio) {
            currentTime = audio.currentTime;
        }
    }

    function handleLoadedMetadata() {
        if (audio) {
            duration = track?.duration || audio.duration;
        }
        loading = false;
    }

    function handleLoadStart() {
        console.log('handleLoadStart called');
    }

    function handleCanPlay() {
        console.log('handleCanPlay called');
        loading = false;
    }

    function handleError(e: Event) {
        loading = false;
        console.error('Audio error:', audio?.error);
        console.error('Stream URL:', streamUrl);
    }

    function handleSeek(e: Event) {
        const target = e.target as HTMLInputElement;
        if (audio) {
            audio.currentTime = parseFloat(target.value);
        }
    }

    function formatTime(seconds: number): string {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    $effect(() => {
        loadMetadata();
        if (track && audio) {
            audio.load();
            isPlaying = false;
            currentTime = 0;
            duration = track.duration || 0;
        }
    });
</script>

<div class="player">
    <h2>Now Playing</h2>

    <div class="cover">
        {#if track.coverArtPath}
            <img src={`${API_BASE_URL}${track.coverArtPath}`} alt="Album cover" />
        {:else}
            <div class="icon">🎵</div>
        {/if}
    </div>

    <div class="trackInfo">
        <div class="title">{metadata?.title || track.originalFilename || track.filename}</div>
        <div class="info">{metadata?.artist || 'Unknown Artist'}</div>
        {#if metadata?.album}
            <div class="info">{metadata.album}</div>
        {/if}
        {#if metadata?.year}
            <div class="info">{metadata.year}</div>
        {/if}
    </div>

    <QualitySelector bind:quality {metadata} trackId={track.id} />

    <div class="quality-badge">
        <strong>{currentQualityInfo.label}</strong>
        <div class="quality-details">
            {currentQualityInfo.codec}
            {#if currentQualityInfo.bitrate}
                · {currentQualityInfo.bitrate}
            {/if}
            {#if currentQualityInfo.sampleRate}
                · {currentQualityInfo.sampleRate}
            {/if}
        </div>
    </div>

    <audio
        bind:this={audio}
        src={streamUrl}
        onplay={handlePlay}
        onpause={handlePause}
        ontimeupdate={handleTimeUpdate}
        onloadedmetadata={handleLoadedMetadata}
        onloadstart={handleLoadStart}
        oncanplay={handleCanPlay}
        onerror={handleError}
        preload="none"
    ></audio>

    <div class="controls">
        <button 
            onclick={(e) => {
                togglePlay();
            }} 
            disabled={loading}
        >
            {loading ? '⏳' : isPlaying ? '⏸' : '▶'}
        </button>
    </div>

    <div class="progress">
        <input
            type="range"
            min="0"
            max={duration || 100}
            value={currentTime}
            oninput={handleSeek}
        />
        <div class="time">
            <span>{formatTime(currentTime)}</span>
            <span>{formatTime(duration)}</span>
        </div>
    </div>
</div>

<style>
    .player {
        border: 1px solid var(--text-secondary-color);
        padding: 20px;
        border-radius: 8px;
        position: sticky;
        top: 20px;
        background: var(--background);
    }

    h2 {
        margin-top: 0;
        color: var(--text-primary-color);
    }

    .cover {
        width: 100%;
        aspect-ratio: 1;
        background: var(--surface-color);
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-bottom: 20px;
    }

    .cover img {
        width: 100%;
        height: 100%;
        object-fit: cover;
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

    .quality-badge {
        background: var(--surface-color);
        border: 1px solid var(--primary-color);
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 20px;
    }

    .quality-badge strong {
        display: block;
        color: var(--primary-color);
        margin-bottom: 4px;
    }

    .quality-details {
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
    }

    .controls button:hover:not(:disabled) {
        opacity: 0.9;
    }

    .controls button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .progress {
        margin-top: 20px;
    }

    .progress input[type="range"] {
        width: 100%;
        margin-bottom: 8px;
    }

    .time {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        color: var(--text-secondary-color);
    }
</style>
