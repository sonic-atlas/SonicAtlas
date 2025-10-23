import type { Request, Response, NextFunction } from 'express';
import { verifyJwt } from '../utils/jwt.js';
import { db } from '../../db/db.js';
import { eq } from 'drizzle-orm';
import { users } from '../../db/schema.js';

export async function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return res.status(401).json({ code: 'AUTH_001' });

    const decoded = verifyJwt(token);
    if (!decoded) return res.status(403).json({ code: 'AUTH_003' });

    const user = await db.query.users.findFirst({
        where: eq(users.id, decoded.id)
    });

    if (!user) return res.status(403).json({ code: 'AUTH_003' });

    req.user = decoded;
    next();
}

export async function uploaderPerms(req: Request, res: Response, next: NextFunction) {
    const user = await db.query.users.findFirst({
        where: eq(users.id, req.user!.id)
    });

    if (!user || user.role === 'viewer') return res.status(403).json({ code: 'AUTH_003' });

    next();
}

export async function adminPerms(req: Request, res: Response, next: NextFunction) {
    const user = await db.query.users.findFirst({
        where: eq(users.id, req.user!.id)
    });

    if (!user || user.role !== 'admin') return res.status(403).json({ code: 'AUTH_003' });

    next();
}