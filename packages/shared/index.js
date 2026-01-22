import { join, resolve } from 'node:path';

/**
 * @
 * @deprecated Just use `import.meta.dirname` bro since idk if this works man
 */
const __dirname = import.meta.dirname;

export const $rootDir = join(import.meta.dirname, '..', '..');

// Logger. I can't be bothered to put in another file right now
const colors = {
    info: '\x1b[36m',
    warn: '\x1b[33m',
    error: '\x1b[31m',
    debug: '\x1b[35m',
    reset: '\x1b[0m'
}

export class Logger {
    constructor(prefix, options = {}) {
        this.prefix = prefix;
        this.options = { timestamp: true, color: true, ...options };
    }

    format(level, message) {
        const time = this.options.timestamp
            ? `[${new Date().toLocaleTimeString()}] `
            : '';
        const color = this.options.color ? colors[level] : '';
        const reset = this.options.color ? colors.reset : '';
        return `${time}${color}[${this.prefix}] ${level.toUpperCase()}:${reset} ${message.replace(/\n(?!$)/g, '\n    ')}`;
    }

    info(msg) {
        console.log(this.format('info', msg));
    }

    warn(msg) {
        console.warn(this.format('warn', msg));
    }

    error(msg) {
        console.error(this.format('error', msg));
    }

    debug(msg) {
        if (process.env.NODE_ENV === 'development') {
            console.debug(this.format('debug', msg));
        }
    }
}