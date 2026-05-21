import { writable } from 'svelte/store';
import type { Quality, Track, TrackMetadata } from '$lib/types';

export interface EngineState {
    loading: boolean;
    isPlaying: boolean;
    quality: Quality;
    nativeErrorCount: number;
    currentTime: number;
    isScrubbing: boolean;
    track?: Track | null;
    duration: number;
    volume: number;
    isMuted: boolean;
    metadata: TrackMetadata | null;
    isAdaptive: boolean;
    streamUrl: string;
}

export const engineState = writable<EngineState>({
    loading: false,
    isPlaying: false,
    quality: 'efficiency',
    nativeErrorCount: 0,
    currentTime: 0,
    isScrubbing: false,
    duration: 0,
    volume: 100,
    isMuted: false,
    metadata: null,
    isAdaptive: false,
    streamUrl: ''
});