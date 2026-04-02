import fs from 'node:fs';
import { join } from 'node:path';

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

        const msgStr = message instanceof Error ? (message.stack || message.message) : String(message);

        return `${time}${color}[${this.prefix}] ${level.toUpperCase()}:${reset} ${msgStr.replace(/\n(?!$)/g, '\n    ')}`;
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

const logger = new Logger('Shared');

// Crash reporting, also can't be bothered to put in another file

export function writeCrashReport(type, error) {
    const timestamp = new Date().toISOString();
    const filePath = join($rootDir, `crash_report_${Date.now()}.txt`);

    const report = `=== CRASH REPORT ===
Time: ${timestamp}
Type: ${type}

Error: ${error instanceof Error ? error.message : String(error)}
Stack: ${error instanceof Error ? error.stack : 'N/A'}

Node Version: ${process.version}
Platform: ${process.platform} (${process.arch})
Memory Usage: ${JSON.stringify(process.memoryUsage(), null, 2)}
Uptime: ${process.uptime()} seconds
`;

    fs.writeFileSync(filePath, report, 'utf-8');
    logger.error(`Crash report saved to ${filePath}`);
}

process.on('uncaughtException', (err) => {
    writeCrashReport('uncaughtException', err);
    process.exit(1);
});

process.on('unhandledRejection', (reason) => {
    writeCrashReport('unhandledRejection', reason);
    process.exit(1);
});