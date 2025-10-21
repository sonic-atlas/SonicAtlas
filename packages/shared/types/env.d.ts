declare namespace NodeJS {
    interface ProcessEnv {
        NODE_ENV?: 'production' | 'development';
        BACKEND_PORT?: `${number}`;
        JWT_SECRET?: string;
        JWT_EXPIRY?: string;

        ADMIN_USERNAME?: string;
        ADMIN_PASSWORD?: string;

        DATABASE_URL?: `postgresql://${string}`;
        REDIS_URL?: `redis://${string}`;

        STORAGE_PATH?: string;
        CACHE_TTL?: `${number}`;

        TRANSCODER_URL?: string;
        FFMPEG_PATH?: string;
        MAX_CONCURRENT_TRANSCODES?: `${number}`;

        CORS_ORIGIN?: `${'http' | 'https'}://${string}`;
        RATE_LIMIT_PER_MINUTE?: `${number}`;

        MUSICBRAINZ_DELAY?: `${number}`;
    }
}