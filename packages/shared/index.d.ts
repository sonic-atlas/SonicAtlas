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
}