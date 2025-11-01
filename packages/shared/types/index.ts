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
