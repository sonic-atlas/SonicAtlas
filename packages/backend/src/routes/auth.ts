import { Router } from 'express';
import { db } from '../../db/db.js';
import { invites, users } from '../../db/schema.js';
import { eq } from 'drizzle-orm';
import bcrypt from 'bcrypt';
import { signJwt, JWT_EXPIRY } from '../utils/jwt.js';
import { logger } from '../utils/logger.js';

const router = Router();

router.post('/login', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'AUTH_008',
            message: 'Username and password are required'
        });
    }

    try {
        const user = await db.query.users.findFirst({
            where: eq(users.username, username)
        });

        if (!user) {
            return res.status(401).json({
                error: 'UNAUTHORIZED',
                code: 'AUTH_006',
                message: 'Invalid username or password'
            });
        }

        const passwordMatch = await bcrypt.compare(password, user.passwordHash);
        if (!passwordMatch) {
            return res.status(401).json({
                error: 'UNAUTHORIZED',
                code: 'AUTH_006',
                message: 'Invalid username or password'
            });
        }

        await db.update(users).set({ lastLogin: new Date() }).where(eq(users.id, user.id));

        const token = signJwt({ id: user!.id });

        return res.status(200).json({
            token,
            expiresIn: JWT_EXPIRY,
            user: {
                id: user.id,
                username: user.username,
                role: user.role,
            }
        });
    } catch (err) {
        logger.error(`(POST /api/auth/login) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Login failed due to an internal error'
        });
    }
});

router.post('/register', async (req, res) => {
    const { inviteToken, username, password } = req.body;

    if (!inviteToken || !username || !password) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'AUTH_009',
            message: 'Invite token, username and password are required'
        });
    }

    try {
        const invite = await db.query.invites.findFirst({
            where: eq(invites.token, inviteToken)
        });

        if (!invite || invite.expiresAt! < new Date() || invite.usedAt) {
            return res.status(400).json({
                error: 'BAD_REQUEST',
                code: 'AUTH_007',
                message: 'Invite token expired or already used'
            });
        }

        const existingUser = await db.query.users.findFirst({
            where: eq(users.username, username)
        });

        if (existingUser) {
            return res.status(409).json({
                error: 'CONFLICT',
                code: 'AUTH_010',
                message: 'Username already taken'
            });
        }

        const passwordHash = await bcrypt.hash(password, process.env.BCRYPT_SALT_ROUNDS ?? 10);

        await db.transaction(async (tx) => {
            const [user] = await tx
                .insert(users)
                .values({
                    username,
                    passwordHash,
                    role: 'viewer',
                    lastLogin: new Date()
                })
                .returning();

            await tx
                .update(invites)
                .set({ usedBy: user?.id, usedAt: new Date() })
                .where(eq(invites.id, invite.id));
        
            const token = signJwt({ id: user!.id });

            return res.status(201).json({
                token,
                expiresIn: JWT_EXPIRY,
                user: {
                    id: user?.id,
                    username: user?.username,
                    role: user?.role,
                }
            });
        });
    } catch (err) {
        logger.error(`(POST /api/auth/register) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Registration failed due to an internal error'
        });
    }
});

export default router;