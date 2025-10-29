import type { Request, Response, NextFunction } from 'express';
import { verifyJwt } from '../utils/jwt.js';
import { db } from '../../db/db.js';
import { eq } from 'drizzle-orm';
import { users } from '../../db/schema.js';

export async function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return res.status(401).json({
        error: 'UNAUTHORIZED',
        code: 'AUTH_001',
        message: 'Authorization token missing'
    });

    const decoded = verifyJwt(token);
    if (!decoded) return res.status(403).json({
        error: 'FORBIDDEN',
        code: 'AUTH_002',
        message: 'Invalid or expired token'
    });

    const user = await db.query.users.findFirst({
        where: eq(users.id, decoded.id)
    });

    if (!user) return res.status(403).json({
        error: 'FORBIDDEN',
        code: 'AUTH_003',
        message: 'User not found'
    });

    req.user = decoded;
    next();
}

export async function uploaderPerms(req: Request, res: Response, next: NextFunction) {
    const user = await db.query.users.findFirst({
        where: eq(users.id, req.user!.id)
    });

    if (!user || user.role === 'viewer') {
        return res.status(403).json({
            error: 'FORBIDDEN',
            code: 'AUTH_004',
            message: 'Insufficient permissions'
        });
    }

    next();
}

export async function adminPerms(req: Request, res: Response, next: NextFunction) {
    const user = await db.query.users.findFirst({
        where: eq(users.id, req.user!.id)
    });

    if (!user || user.role !== 'admin') {
        return res.status(403).json({
            error: 'FORBIDDEN',
            code: 'AUTH_005',
            message: 'Insufficient permissions'
        });
    }

    next();
}