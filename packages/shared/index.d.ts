// Types for index.js
declare module '@sonic-atlas/shared' {
    const $rootDir: string;

    // Logger
    interface LogOptions {
        timestamp?: boolean;
        color?: boolean;
    }
    class Logger {
        private prefix;
        private options;
        constructor(prefix: string, options?: LogOptions);
        private format;
        info(msg: string): void;
        warn(msg: string): void;
        error(msg: string): void;
        debug(msg: string): void;
    }

    // API Types
    export interface Track {
        id: string;
        filename: string;
        originalFilename: string;
        fileSize: number;
        uploadedAt: string;
        coverArtPath?: string;
        format?: string;
        duration?: number;
        sampleRate?: number;
        bitDepth?: number;
        metadata?: TrackMetadata;
        album?: string;
        releaseId: string;
        releaseTitle: string;
        releaseArtist: string;
        releaseYear: number;
    }

    export interface TrackMetadata {
        id: string;
        trackId: string;
        title?: string;
        artist?: string;
        album?: string;
        year?: number;
        genre?: string;
        genres?: string[];
        duration?: number;
        bitrate?: number;
        sampleRate?: number;
        bitDepth?: number;
        channels?: number;
        codec?: string;
        sourceQuality?: 'efficiency' | 'high' | 'cd' | 'hires';
    }

    export type Quality = 'auto' | 'efficiency' | 'high' | 'cd' | 'hires';

    export interface QualityInfo {
        label: string;
        codec: string;
        bitrate?: string;
        sampleRate?: string;
    }

    export interface ApiError {
        error: string;
        code?: string;
        message: string;
    }

}