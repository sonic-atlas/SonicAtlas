<script lang="ts">
    import '@material/web/icon/icon.js';
    import '@material/web/progress/linear-progress.js';
    import '@material/web/progress/circular-progress.js';
    import '@material/web/slider/slider.js';
    import type { Track, TrackMetadata, Quality, QualityInfo } from '$lib/types';
    import QualitySelector from './QualitySelector.svelte';
    import { apiGet, getStreamUrl, API_BASE_URL } from '$lib/api';
    import { auth } from '$lib/stores/auth.svelte';
    import Hls from 'hls.js';

    interface Props {
        track: Track;
        quality: Quality;
        oncloseplayer?: () => void;
    }

    let {
        track = $bindable(),
        quality = $bindable(),
        oncloseplayer = $bindable()
    }: Props = $props();

    let audio: HTMLAudioElement;
    let hls: Hls | null = null;
    let isPlaying = $state<boolean>(false);
    let currentTime = $state<number>(0);
    let duration = $state<number>(0);
    let isScrubbing = false;
    let lastUpdate = 0;
    let loading = $state<boolean>(false);
    let metadata = $state<TrackMetadata | null>(null);

    let isAdaptive = $state<boolean>(false);
    let hoverTime = $state<number | null>(null);
    let progressBarElement: HTMLDivElement;

    let nativeHlsErrorCount = $state<number>(0);
    const MAX_NATIVE_HLS_ERRORS = 2;

    $effect(() => {
        console.log('Loading state changed:', loading);
    });

    let streamUrl = $state<string>('');

    const qualityInfoMap: Record<Quality, QualityInfo> = {
        auto: { label: 'Auto (ABR)', codec: 'Adaptive', bitrate: 'Varies' },
        efficiency: { label: 'Efficiency', codec: 'AAC', bitrate: '128k' },
        high: { label: 'High', codec: 'AAC', bitrate: '320k' },
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

    async function loadMetadata() {
        const res = await apiGet(`/api/metadata/${track.id}`);
        if (res.ok) {
            metadata = await res.json();
        }
    }

    function preloadImage(url: string) {
        const img = new Image();
        img.src = url;
    }

    let volume = $state(100);
    let isMuted = $state(false);
    let previousVolume = 100;

    function handleVolumeChange(e: Event) {
        const target = e.target as HTMLInputElement;
        volume = Number(target.value);
        if (audio) {
            audio.volume = volume / 100;
            isMuted = volume === 0;
        }
    }

    function toggleMute() {
        if (isMuted) {
            volume = previousVolume || 100;
            isMuted = false;
        } else {
            previousVolume = volume;
            volume = 0;
            isMuted = true;
        }
        if (audio) {
            audio.volume = volume / 100;
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
            audio.play().catch((err) => {
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

    function showErrorAndClose(message: string) {
        console.error(`Fatal Playback Error: ${message}`);
        alert(`Error: Playback failed.\n${message}`);

        if (oncloseplayer) {
            oncloseplayer();
        }

        if (hls) {
            hls.destroy();
            hls = null;
        }
        if (audio) {
            audio.pause();
            audio.removeAttribute('src');
            audio.load();
        }
        isPlaying = false;
        loading = false;
    }

    function handleError(e: Event) {
        loading = false;
        console.error('Audio error:', audio?.error);
        console.error('Stream URL:', streamUrl);

        const isHlsNativelySupported = audio.canPlayType('application/vnd.apple.mpegurl') !== '';

        if (!hls && isHlsNativelySupported && quality !== 'auto') {
            nativeHlsErrorCount++;
            console.warn(`Native HLS error count: ${nativeHlsErrorCount}`);

            if (nativeHlsErrorCount >= MAX_NATIVE_HLS_ERRORS) {
                console.error('Native HLS failed 2 times. Retrying with hls.js...');
                loadHlsStream(streamUrl, true);
            } else {
                console.warn('Retrying native HLS load...');
                setTimeout(() => audio.load(), 500);
            }
        } else if (hls) {
            console.error('Media element error during hls.js playback.');
        } else {
            showErrorAndClose(
                'Playback failed. HLS is not supported or an unknown error occurred.'
            );
        }
    }

    function handleProgressHover(e: MouseEvent) {
        if (!progressBarElement || !duration) return;

        const rect = progressBarElement.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const percentage = Math.max(0, Math.min(1, x / rect.width));
        hoverTime = percentage * duration;
    }

    function handleProgressLeave() {
        hoverTime = null;
    }

    function handleProgressClick(e: MouseEvent) {
        if (!progressBarElement || !audio || !duration) return;

        const rect = progressBarElement.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const percentage = Math.max(0, Math.min(1, x / rect.width));
        const newTime = percentage * duration;

        audio.currentTime = newTime;
        currentTime = newTime;
    }

    function handleProgressKeyDown(e: KeyboardEvent) {
        if (!audio || !duration) return;

        const step = 5;

        switch (e.key) {
            case 'ArrowLeft':
                e.preventDefault();
                audio.currentTime = Math.max(0, audio.currentTime - step);
                break;
            case 'ArrowRight':
                e.preventDefault();
                audio.currentTime = Math.min(duration, audio.currentTime + step);
                break;
            case 'Home':
                e.preventDefault();
                audio.currentTime = 0;
                break;
            case 'End':
                e.preventDefault();
                audio.currentTime = duration;
                break;
            case ' ':
            case 'Enter':
                e.preventDefault();
                togglePlay();
                break;
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
            console.log('Using hls.js for playback');
            hls = new Hls({
                lowLatencyMode: true,
                maxBufferLength: 30,
                maxMaxBufferLength: 60,
                manifestLoadingTimeOut: 10000,
                manifestLoadingMaxRetry: 10,
                manifestLoadingRetryDelay: 1000,
                levelLoadingTimeOut: 10000,
                levelLoadingMaxRetry: 10,
                levelLoadingRetryDelay: 1000,
                fragLoadingTimeOut: 20000,
                fragLoadingMaxRetry: 20,
                fragLoadingRetryDelay: 500,
                xhrSetup: (xhr) => {
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
                            console.log('Network error encountered, trying to recover...');
                            hls?.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            console.log('Media error encountered, trying to recover...');
                            hls?.recoverMediaError();
                            break;
                        default:
                            console.error('Unrecoverable error, destroying HLS instance');
                            hls?.destroy();
                            loading = false;

                            setTimeout(() => {
                                console.log('Attempting hard reload of stream...');
                                loadHlsStream(streamUrl, true);
                            }, 5000);
                            break;
                    }
                }
            });
        } else if (isHlsNativelySupported && !useHlsjs) {
            console.log('Using native HLS support');
            audio.src = url;
            audio.load();
        } else {
            console.error('HLS is not supported in this environment.');
            audio.src = '';
            showErrorAndClose('HLS playback is not supported on this device.');
        }
    }

    $effect(() => {
        if (!track || !audio) return;

        nativeHlsErrorCount = 0;

        isAdaptive = quality === 'auto';
        streamUrl = getStreamUrl(track.id, quality);

        if (track.coverArtPath) {
            preloadImage(`${API_BASE_URL}${track.coverArtPath}`);
        }

        const isHlsNativelySupported = audio.canPlayType('application/vnd.apple.mpegurl') !== '';
        const museUseHlsJs = isAdaptive || !isHlsNativelySupported;

        console.log(
            `Loading Stream. Quality: ${quality}, Adaptive: ${isAdaptive}, URL: ${streamUrl}, UseHlsJS: ${museUseHlsJs}, NativeSupport: ${isHlsNativelySupported}`
        );

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
        };
    });

    // Metadata, like control via bluetooth speaker
    function setupMediaSessionHandlers() {
        if (!('mediaSession' in navigator) || !audio) return;

        navigator.mediaSession.setActionHandler('pause', () => {
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
            if (event.fastSeek && 'faskSeek' in audio) {
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

        const artwork: MediaImage[] = track.coverArtPath
            ? [
                  {
                      src: `${API_BASE_URL}${track.coverArtPath}`
                  }
              ]
            : [];

        navigator.mediaSession.metadata = new MediaMetadata({
            title,
            artist,
            album,
            artwork
        });
    }

    function updatePositionState() {
        if (!('setPositionState' in navigator.mediaSession) || !audio) return;

        try {
            navigator.mediaSession.setPositionState({
                duration: audio.duration || 0,
                position: audio.currentTime || 0
            });
        } catch (err) {
            console.warn('Failed to update position state:', err);
        }
    }

    $effect(() => {
        if (track) {
            updateMediaSessionMetadata();
        }
    });

    $effect(() => {
        if (audio) {
            setupMediaSessionHandlers();
            audio.addEventListener('timeupdate', updatePositionState);
        }
    });
</script>

<div class="player">
    <h2>Now Playing</h2>

    <div class="cover">
        {#if track.coverArtPath}
            <img src={`${API_BASE_URL}${track.coverArtPath}`} alt="Album cover" />
        {:else}
            <div class="icon">
                <md-icon class="coverIcon">music_note</md-icon>
            </div>
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
                <div
                    class="progressFilled"
                    style="width: {duration > 0 ? (currentTime / duration) * 100 : 0}%"
                ></div>
            </div>
            {#if hoverTime !== null}
                <div
                    class="progressHover"
                    style="left: {duration > 0 ? (hoverTime / duration) * 100 : 0}%"
                >
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

    <audio
        bind:this={audio}
        onplay={handlePlay}
        onpause={handlePause}
        ontimeupdate={handleTimeUpdate}
        onloadedmetadata={handleLoadedMetadata}
        onloadstart={handleLoadStart}
        oncanplay={handleCanPlay}
        onwaiting={() => {
            console.log('Playback waiting/buffering...');
            loading = true;
        }}
        onplaying={() => {
            console.log('Playback resumed');
            loading = false;
        }}
        onerror={handleError}
        preload="none"
    ></audio>

    <div class="controls">
        <button
            onclick={(e) => {
                togglePlay();
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
                onclick={toggleMute}
                onkeydown={(e: KeyboardEvent) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        toggleMute();
                        e.preventDefault();
                    }
                }}
                role="button"
                tabindex="0"
            >
                <md-icon
                    >{volume === 0 || isMuted
                        ? 'volume_off'
                        : volume < 50
                          ? 'volume_down'
                          : 'volume_up'}</md-icon
                >
            </md-icon-button>
            <md-slider min="0" max="100" value={volume} oninput={handleVolumeChange}></md-slider>
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
