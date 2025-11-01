// Put into index.ts
/*
import cluster from 'node:cluster';
import os from 'node:os';

const numCPUs = process.env.BACKEND_CORES ? Number(process.env.BACKEND_CORES) > os.cpus().length ? os.cpus().length : Number(process.env.BACKEND_CORES) : 1;

const prefix = numCPUs > 1 ? `[Worker ${process.pid}] ` : '';

if (cluster.isPrimary) {
    logger.info(`Primary ${process.pid} running with ${numCPUs} worker${numCPUs > 1 ? 's' : ''}`);

    for (let i = 0; i < numCPUs; i++) {
        cluster.fork();
    }

    cluster.on('exit', (worker) => {
        logger.warn(`Worker ${worker.process.pid} died. Restarting...`);
        cluster.fork();
    });

    const shutdownWorkers = () => {
        for (const id in cluster.workers) {
            cluster.workers[id]?.kill('SIGTERM');
        }
    }

    process.on('SIGTERM', shutdownWorkers);
    process.on('SIGINT', shutdownWorkers);
} else {
    [ExpressJS server code here. From]
    [const app = express()] [to]
    [const server = ...]
    [Add ${prefix} to start of logs]

    const shutdown = () => {
        server.close(() => process.exit(0));

        setTimeout(() => process.exit(1), 30_000);
    }

    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
}
*/