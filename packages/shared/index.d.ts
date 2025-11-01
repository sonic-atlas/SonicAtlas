// Types for index.js
declare module '@sonic-atlas/shared' {
    const $rootDir: string;
    const $envPath: string;

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
        fileName: string;
        fileSize: number;
        uploadedAt: string;
        uploadedBy: string;
    }

    export interface TrackMetadata {
        id: string;
        trackId: string;
        title?: string;
        artist?: string;
        album?: string;
        year?: number;
        genre?: string;
        duration?: number;
        bitrate?: number;
        sampleRate?: number;
        channels?: number;
        codec?: string;
    }

    export type Quality = 'efficiency' | 'high' | 'cd' | 'hires';

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