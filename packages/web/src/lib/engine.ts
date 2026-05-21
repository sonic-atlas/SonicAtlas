import Hls from 'hls.js';
import { auth } from './stores/auth.svelte';
import type { Quality, Track } from './types';
import { engineState, type EngineState } from './stores/engineStore';
import { get } from 'svelte/store';
import { API_BASE_URL, apiGet } from '$lib/api';

export class AudioPlayer {
    #hls: Hls | null = null;
    #audio?: HTMLAudioElement;
    #maxErrors: number = 2;
    #url: string = '';
    #oncloseplayer: (() => void) | null = null;
    #previousVolume: number = 100;

    setLoading = (loading: boolean) => engineState.update(s => ({ ...s, loading }));
    setIsPlaying = (isPlaying: boolean) => engineState.update(s => ({ ...s, isPlaying }));
    setCurrentTime = (currentTime: number) => engineState.update(s => ({ ...s, currentTime }));
    setDuration = (duration: number) => engineState.update(s => ({ ...s, duration }));
    setNativeErrorCount = (nativeErrorCount: number) => engineState.update(s => ({ ...s, nativeErrorCount }));
    setIsAdaptive = (isAdaptive: boolean) => engineState.update(s => ({ ...s, isAdaptive }));
    setStreamUrl = (streamUrl: string) => engineState.update(s => ({ ...s, streamUrl }));
    setQuality = (quality: Quality) => engineState.update(s => ({ ...s, quality }));
    setTrack = (track: Track | null) => engineState.update(s => ({ ...s, track }));
    #setVolume = (volume: number) => engineState.update(s => ({ ...s, volume }));
    #setIsMuted = (isMuted: boolean) => engineState.update(s => ({ ...s, isMuted }));
    #setMetadata = (metadata: any) => engineState.update(s => ({ ...s, metadata }));

    init(audio: HTMLAudioElement, opts?: { maxErrors: number, oncloseplayer: () => void }) {
        this.#audio = audio;
        this.#attachOnError();

        this.#maxErrors = opts?.maxErrors || 2;
        this.#oncloseplayer = opts?.oncloseplayer || null;

        this.#setupMediaSessionHandlers();
        // Could also make this.#updatePositionState an arrow func instead of bind
        this.#audio.addEventListener('timeupdate', this.#updatePositionState.bind(this));

        console.log('AudioPlayer initialised');
    }

    #setupMediaSessionHandlers() {
        if (!('mediaSession' in navigator) || !this.#audio) return;

        navigator.mediaSession.setActionHandler('pause', () => {
            this.#audio!.pause();
        });

        navigator.mediaSession.setActionHandler('play', () => {
            this.#audio!.play();
        });

        navigator.mediaSession.setActionHandler('seekbackward', (e) => {
            const skipTime = e.seekOffset || 10;
            this.#audio!.currentTime = Math.max(this.#audio!.currentTime - skipTime, 0);
        });

        navigator.mediaSession.setActionHandler('seekforward', (e) => {
            const skipTime = e.seekOffset || 10;
            this.#audio!.currentTime = Math.min(this.#audio!.currentTime + skipTime, this.#audio!.duration);
        });

        navigator.mediaSession.setActionHandler('seekto', (e) => {
            if (e.fastSeek && 'fastSeek' in this.#audio!) {
                this.#audio!.fastSeek(e.seekTime!);
            } else {
                this.#audio!.currentTime = e.seekTime!;
            }
        });
    }

    #updatePositionState() {
        if (!('setPositionState' in navigator.mediaSession) || !this.#audio) return;

        try {
            navigator.mediaSession.setPositionState({
                duration: this.#audio.duration || 0,
                position: this.#audio.currentTime || 0
            });
        } catch (err) {
            console.warn('Failed to update position state:', err);
        }
    }

    updateMediaSessionMetadata() {
        if (!('mediaSession' in navigator) || !this.state.track) return;

        let metadata = this.state.metadata;
        let track = this.state.track;

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

    async loadMetadata() {
        const res = await apiGet(`/api/metadata/${this.state.track!.id}`);
        if (res.ok) {
            this.#setMetadata(await res.json());
            this.updateMediaSessionMetadata();
        }
    }

    load(url: string, useHlsjs?: boolean) {
        if (this.#hls || this.#audio) this.destroy();
        if (!this.#audio) return;

        if (useHlsjs && Hls.isSupported()) {
            console.log('Using HLS.js for playback');
            this.#hls = new Hls({
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
                },
                // Just in case I have no idea bro it sends xhr now
                // Maybe this will fix a few edge cases?
                fetchSetup: (ctx, params) => {
                    params.headers['Authorization'] = `Bearer ${auth.token}`;
                    return new Request(ctx.url, params);
                }
            });

            this.#hls.attachMedia(this.#audio);

            this.#hls.on(Hls.Events.LEVEL_SWITCHED, (event, data) => {
                console.log(`ABR switched to level index: ${data.level}`);
            });

            this.#hls.on(Hls.Events.MEDIA_ATTACHED, () => {
                console.log('HLS media attached, loading manifest:', url);
                this.#hls?.loadSource(url);
                this.#url = url;
            });

            this.#hls.on(Hls.Events.ERROR, (event, data) => {
                if (data.fatal) {
                    console.error('HLS Fatal Error:', data.details, data.error);
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            console.log('Network error encountered, trying to recover...');
                            this.#hls?.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            console.log('Media error encountered, trying to recover...');
                            this.#hls?.recoverMediaError();
                            break;
                        default:
                            console.error('Unrecoverable error, destroying HLS instance');
                            this.#hls?.destroy();
                            // this.setLoading(false);

                            setTimeout(() => {
                                console.log('Attempting hard reload of stream...');
                                this.load(url, true);
                            }, 5000);
                            break;
                    }
                }
            });
        } else if (this.nativelySupported && !useHlsjs) {
            console.log('Using native HLS support');
            this.#audio.src = url;
            this.#audio.load();
        } else {
            console.error('HLS is not supported in this environment.');
            this.#audio.src = '';
            this.showErrorAndClose('HLS playback is not supported on this device.');
        }
    }

    destroy() {
        if (this.#hls) {
            this.#hls.destroy();
            this.#hls = null;

        }

        if (this.#audio) {
            this.#audio.pause();
            this.#audio.removeAttribute('src');
            this.#audio.load();
        }

        this.setLoading(false);
        this.setIsPlaying(false);
    }

    #attachOnError() {
        if (!this.#audio) return;

        // Could also make this.handleError an arrow func instead of bind
        this.#audio.onerror = this.handleError.bind(this);
    }

    handleError(e: Event | string) {
        this.setLoading(false);
        console.error('Audio error:', this.#audio?.error);
        console.error('Stream URL:', this.#url);

        if (!this.#hls && this.nativelySupported && this.state.quality !== 'auto') {
            this.setNativeErrorCount(this.state.nativeErrorCount + 1);
            console.warn(`Native HLS error count: ${this.state.nativeErrorCount}`);

            if (this.state.nativeErrorCount >= this.#maxErrors) {
                console.error(`Native HLS failed ${this.#maxErrors} time${this.#maxErrors === 1 ? '' : 's'}. Retrying with HLS.js...`);
                this.load(this.#url, true);
            } else {
                console.warn(`Retrying native HLS load (attempt ${this.state.nativeErrorCount + 1})...`);
                setTimeout(() => this.#audio!.load(), 500);
            }
        } else if (this.#hls) {
            console.error('Media element error during hls.js playback.');
        } else {
            this.showErrorAndClose('Playback failed. HLS is not supported or an unknown error occured.');
        }
    }

    showErrorAndClose(message: string) {
        console.error(`Fatal Playback Error: ${message}`);
        alert(`Error: playback failed.\n${message}`);

        if (this.#oncloseplayer) {
            this.#oncloseplayer();
        }

        this.destroy();

        this.setIsPlaying(false);
        this.setLoading(false);
    }

    togglePlay() {
        if (!this.#audio) {
            console.error('Audio element not bound');
            return;
        }

        console.log('Toggle play: ', {
            isPlaying: this.state.isPlaying,
            streamUrl: this.#url,
            quality: this.state.quality
        });

        if (this.state.isPlaying) {
            this.#audio.pause();
        } else {
            this.setLoading(true);
            this.#audio.play().catch((err) => {
                console.error('Play failed:', err);
                this.setLoading(false);
            });
        }
    }

    toggleMute() {
        if (this.state.isMuted) {
            this.#setVolume(this.#previousVolume || 100);
            this.#setIsMuted(false);
        } else {
            this.#previousVolume = this.state.volume;
            this.#setVolume(0);
            this.#setIsMuted(true);
        }

        if (this.#audio) {
            this.#audio.volume = this.state.volume / 100;
        }
    }

    handleVolumeChange(e: Event) {
        const target = e.target as HTMLInputElement;
        this.#setVolume(Number(target.value));
        if (this.#audio) {
            this.#audio.volume = this.state.volume / 100;
            this.#setIsMuted(this.state.volume === 0);
        }
    }

    get nativelySupported(): boolean {
        return this.#audio?.canPlayType('application/vnd.apple.mpegurl') !== '';
    }

    get state(): EngineState {
        return get(engineState);
    }

    get hasAudio(): boolean {
        return !!this.#audio;
    }

    get audioCurrentTime() {
        return this.#audio!.currentTime;
    }

    setAudioCurrentTime(newTime: number) {
        if (!this.#audio) return;
        this.#audio.currentTime = newTime;
    }

    get audioDuration() {
        return this.#audio!.duration
    }

    get audioAddListener() {
        return this.#audio!.addEventListener.bind(this.#audio);
    }
}

export const audioPlayer = new AudioPlayer();