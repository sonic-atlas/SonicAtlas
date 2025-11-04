<script lang="ts">
    import '@material/web/progress/linear-progress.js';
    import "@material/web/progress/circular-progress.js";
    import type { Track, TrackMetadata, Quality, QualityInfo } from '$lib/types';
    import QualitySelector from './QualitySelector.svelte';
    import { apiGet, getStreamUrl, API_BASE_URL } from '$lib/api';
    import { auth } from '$lib/stores/auth.svelte';
    import Hls from 'hls.js';

    interface Props {
        track: Track;
        quality: Quality;
    }

    let { track, quality = $bindable() }: Props = $props();

    let audio: HTMLAudioElement;
    let hls: Hls | null = null;
    let isPlaying = $state(false);
    let currentTime = $state(0);
    let duration = $state(0);
    let isScrubbing = false;
    let lastUpdate = 0;
    let loading = $state(false);
    let metadata = $state<TrackMetadata | null>(null);

    let isAdaptive = $state(false);

    $effect(() => {
        console.log('Loading state changed:', loading);
    });

    let streamUrl = $state('');

    const qualityInfoMap: Record<Quality, QualityInfo> = {
        auto: { label: 'Auto (ABR)', codec: 'Adaptive', bitrate: 'Varies' },
        efficiency: { label: 'Efficiency', codec: 'AAC', bitrate: '128k' },
        high: { label: 'High', codec: 'AAC', bitrate: '320k' },
        cd: { label: 'CD', codec: 'FLAC', sampleRate: '44.1kHz' },
        hires: { label: 'Hi-Res', codec: 'FLAC', sampleRate: 'Original' }
    }

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
        if (!audio || isScrubbing) return;

        const now = performance.now();
        if (now - lastUpdate < 250) return;
        lastUpdate = now;

        currentTime = audio.currentTime;
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

    function handleScrub(e: Event) {
        const target = e.target as HTMLInputElement;
        const value = parseFloat(target.value);
        isScrubbing = true;
        currentTime = value;
    }

    function handleSeekCommit(e: Event) {
        const target = e.target as HTMLInputElement;
        const value = parseFloat(target.value);

        if (!audio || isNaN(value)) return;

        isScrubbing = false;

        try {
            audio.currentTime = value;
            if (hls) {
                hls.startLoad();
            }
        } catch (err) {
            console.warn('Seek failed, retrying once...', err);
            setTimeout(() => (audio.currentTime = value), 200);
        }
    }

    function formatTime(seconds: number): string {
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return `${mins}:${secs.toString().padStart(2, '0')}`;
    }

    // HLS
    function loadHlsStream(url: string, useHlsjs: boolean) {
        if (hls) {
            hls.destroy();
            hls = null;
        }

        if (audio) {
            audio.pause();
            audio.removeAttribute('src');
            audio.load();
        }

        const isHlsNativelySupported = audio.canPlayType('application/vnd.apple.mpegurl') !== '';

        if (useHlsjs && Hls.isSupported()) {
            hls = new Hls({
                lowLatencyMode: true,
                /* maxBufferLength: 15,
                maxMaxBufferLength: 30, */
                xhrSetup: (xhr) => {
                    console.log(auth.token);
                    xhr.setRequestHeader('Authorization', `Bearer ${auth.token}`);
                }
            });
            hls.attachMedia(audio);

            hls.on(Hls.Events.LEVEL_SWITCHED, (event, data) => {
                console.log(`ABR switch to level index: ${data.level}`);
            });

            hls.on(Hls.Events.MEDIA_ATTACHED, function () {
                console.log('HLS media attached, loading manifest:', url);
                hls?.loadSource(url);
            });
            hls.on(Hls.Events.ERROR, function (event, data) {
                if (data.fatal) {
                    console.error('HLS Fatal Error:', data.details, data.error);
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            console.log('Trying to recover from network error...');
                            hls?.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            console.log('Trying to recover from media error...');
                            hls?.recoverMediaError();
                            break;
                        default:
                            hls?.destroy();
                            loading = false;
                            break;
                    }
                }
            });
        } else if (isHlsNativelySupported) {
            console.log('Using native HLS support');
            audio.src = url;
            audio.load();
        } else {
            console.error('HLS is not supported in this environment.');
            audio.src = '';
        }
    }

    $effect(() => {
        if (!track || !audio) return;

        isAdaptive = quality === 'auto';
        streamUrl = getStreamUrl(track.id, quality);
        const museUseHlsJs = isAdaptive || !audio.canPlayType('application/vnd.apple.mpegurl');

        console.log(`Loading Stream. Quality: ${quality}, Adaptive: ${isAdaptive}, URL: ${streamUrl}`);

        loadHlsStream(streamUrl, museUseHlsJs);

        isPlaying = false;
        currentTime = 0;
        duration = track.duration || 0;
    });

    $effect(() => {
        if (track) loadMetadata();
    });

    $effect(() => {
        return () => {
            if (hls) {
                hls.destroy();
                hls = null;
            }

            if (audio) {
                audio.pause();
                audio.removeAttribute('src');
                audio.load();
            }
        }
    });

    // PWA metadata, like bluetooth control via car or speaker
    function setupMediaSessionHandlers() {
        if (!('mediaSession' in navigator) || !audio) return;

        navigator.mediaSession.setActionHandler('pause' ,() => {
            audio.pause();
        });

        navigator.mediaSession.setActionHandler('play', () => {
            audio.play();
        });

        navigator.mediaSession.setActionHandler('seekbackward', (event) => {
            const skipTime = event.seekOffset || 10;
            audio.currentTime = Math.max(audio.currentTime - skipTime, 0);
        });

        navigator.mediaSession.setActionHandler('seekforward', (event) => {
            const skipTime = event.seekOffset || 10;
            audio.currentTime = Math.min(audio.currentTime + skipTime, audio.duration);
        });

        navigator.mediaSession.setActionHandler('seekto', (event) => {
            if (event.fastSeek && ('faskSeek' in audio)) {
                audio.fastSeek(event.seekTime!);
            } else {
                audio.currentTime = event.seekTime!;
            }
        });
    }

    function updateMediaSessionMetadata() {
        if (!('mediaSession' in navigator) || !track) return;

        const title = metadata?.title || track.originalFilename || track.filename;
        const artist = metadata?.artist || 'Unknown Artist';
        const album = metadata?.album || '';

        const artwork: MediaImage[] = track.coverArtPath ? [{
            src: track.coverArtPath,
            sizes: '512x512',
            type: 'image/jpeg'
        }] : [];

        navigator.mediaSession.metadata = new MediaMetadata({
            title,
            artist,
            album,
            artwork
        });
    }

    $effect(() => {
        if (track) {
            updateMediaSessionMetadata();
        }
    });

    $effect(() => {
        if (audio) {
            setupMediaSessionHandlers();
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

    <div class="qualityBadge">
        <strong>{currentQualityInfo.label}</strong>
        <div class="quality-details">
            {#if isAdaptive}
                {currentQualityInfo.codec} · ABR Active
            {:else}
                {currentQualityInfo.codec}
                {#if currentQualityInfo.bitrate}
                    · {currentQualityInfo.bitrate}
                {/if}
                {#if currentQualityInfo.sampleRate}
                    · {currentQualityInfo.sampleRate}
                {/if}
            {/if}
        </div>
    </div>

    <audio
        bind:this={audio}
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
            aria-label={isPlaying ? "Pause" : "Play"}
        >
        {#if loading}
            <md-circular-progress 
                indeterminate
                aria-label="Loading"
            ></md-circular-progress>
        {:else}
            {isPlaying ? '⏸' : '▶'}
        {/if}
    </button>
</div>


    <div class="progress">
        <div class="progress-container">
            <!--<md-linear-progress 
                value={progress}
                aria-label="Playback progress"
            ></md-linear-progress> -->
            <input
                type="range"
                min="0"
                max={duration}
                step="0.01"
                value={currentTime}
                oninput={handleScrub}
                onchange={handleSeekCommit}
                aria-label="Seek"
            />
        </div>
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

    .qualityBadge {
        background: var(--surface-color);
        border: 1px solid var(--primary-color);
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 20px;
    }

    .qualityBadge strong {
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
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .controls button md-circular-progress {
        --md-circular-progress-size: 48px;
        --md-circular-progress-active-indicator-color: var(--secondary-color);
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

    .progress-container {
        position: relative;
        margin-bottom: 8px;
        height: 8px;
    }

    /* .progress-container md-linear-progress {
        width: 100%;
        height: 8px;
        border-radius: 4px;
        overflow: hidden;
        --md-linear-progress-track-height: 8px;
        --md-linear-progress-track-shape: 4px;
        --md-linear-progress-track-color: var(--surface-color);
        --md-linear-progress-active-indicator-height: 8px;
        --md-linear-progress-active-indicator-color: var(--primary-color);
    } */

    .progress-container input[type="range"] {
        width: 100%;
        appearance: none;
        height: 8px;
        border-radius: 4px;
        background: var(--surface-color);
        outline: none;
        cursor: pointer;
    }

    .progress-container input[type="range"]::-webkit-slider-thumb {
        appearance: none;
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: var(--primary-color);
        cursor: pointer;
    }

    .progress-container input[type="range"]::-moz-range-thumb {
        width: 14px;
        height: 14px;
        border-radius: 50%;
        background: var(--primary-color);
        cursor: pointer;
    }

    .time {
        display: flex;
        justify-content: space-between;
        font-size: 12px;
        color: var(--text-secondary-color);
    }
</style>
