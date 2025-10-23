import jwt, { type SignOptions, type JwtPayload } from 'jsonwebtoken';
import type { JwtUser } from '../../types/index.js';

const SECRET = process.env.JWT_SECRET || 'super-secret-key';
export const JWT_EXPIRY = process.env.JWT_EXPIRY as SignOptions['expiresIn'] || '7d';

export function signJwt(payload: JwtUser, expiresIn: SignOptions['expiresIn'] = JWT_EXPIRY) {
    return jwt.sign(payload, SECRET, { expiresIn });
}

export function verifyJwt(token: string): (JwtUser & JwtPayload) | null {
    try {
        return jwt.verify(token, SECRET) as JwtUser & JwtPayload;
    } catch {
        return null;
    }
}