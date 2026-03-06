import type { Request, Response, NextFunction } from 'express';
import { httpRequestsTotal, httpRequestDuration, inflightRequests } from '../services/metrics/httpMetrics.ts';

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
    inflightRequests.inc();

    const end = httpRequestDuration.startTimer({
        method: req.method,
        route: req.route?.path || req.path
    });

    res.on('finish', () => {
        inflightRequests.dec();

        httpRequestsTotal.inc({
            method: req.method,
            route: req.route?.path || req.path,
            status: res.statusCode
        });

        end({
            method: req.method,
            route: req.route?.path || req.path,
            status: res.statusCode
        });
    });

    next();
}