import type { Request, Response, NextFunction } from 'express';
import { verifyJwt } from '../utils/jwt.js';

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
    const token = req.cookies?.jwt || req.headers['authorization']?.split(' ')[1];
    if (!token) return res.status(401);

    const decoded = verifyJwt(token);
    if (!decoded) return res.status(403);

    req.user = decoded;
    next();
}