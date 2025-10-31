import type { Request, Response, NextFunction } from 'express';
import { verifyJwt } from '../utils/jwt.js';

export async function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const decoded = verifyJwt(token);
        
        if (decoded && decoded.authenticated) {
            req.user = decoded;
            return next();
        }
    }
    const password = req.headers['x-server-password'] || req.query.password;
    const serverPassword = process.env.SERVER_PASSWORD;

    if (!serverPassword) {
        return next();
    }

    if (!password) {
        return res.status(401).json({
            error: 'UNAUTHORIZED',
            code: 'AUTH_001',
            message: 'Authentication required'
        });
    }

    if (password !== serverPassword) {
        return res.status(403).json({
            error: 'FORBIDDEN',
            code: 'AUTH_002',
            message: 'Invalid credentials'
        });
    }

    next();
}

// keeping this for idk, future use?
export async function uploaderPerms(req: Request, res: Response, next: NextFunction) {
    next();
}

export async function adminPerms(req: Request, res: Response, next: NextFunction) {
    next();
}