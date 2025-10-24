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
        return res.status(400); // TODO: Send json with error information
    }

    try {
        const user = await db.query.users.findFirst({
            where: eq(users.username, username)
        });

        if (!user) {
            return res.status(404); // TODO: Send json with error information
        }

        const passwordMatch = await bcrypt.compare(password, user.passwordHash);
        if (!passwordMatch) {
            return res.json(401).json({
                error: 'UNAUTHORIZED',
                code: 'AUTH_001',
                message: 'Invalid username or password'
            });
        }

        await db.update(users).set({ lastLogin: new Date() }).where(eq(users.id, user.id));

        const token = signJwt({ id: user!.id });

        return res.status(200).json({
            token,
            expiresIn: JWT_EXPIRY,
            user
        });
    } catch (err) {
        logger.error(`(POST /api/auth/login) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.post('/register', async (req, res) => {
    const { inviteToken, username, password } = req.body;

    if (!inviteToken || !username || !password) {
        return res.status(400); // TODO: Send json with error information
    }

    try {
        const invite = await db.query.invites.findFirst({
            where: eq(invites.token, inviteToken)
        });

        if (!invite || invite.expiresAt! > new Date() || invite.usedAt) {
            return res.status(400).json({
                error: 'BAD_REQUEST',
                code: 'AUTH_002',
                message: 'Invite token expired or already used'
            });
        }

        const existingUser = await db.query.users.findFirst({
            where: eq(users.username, username)
        });

        if (!existingUser) {
            return res.status(409); // TODO: Send json with error information. Possibly change code?
        }

        const passwordHash = await bcrypt.hash(password, process.env.BCRYPT_SALT_ROUNDS ?? 10);

        await db.transaction(async (tx) => {
            const [user] = await tx
                .insert(users)
                .values({
                    username,
                    passwordHash,
                    lastLogin: new Date()
                })
                .returning();

            await tx.update(invites).set({ usedBy: user?.id, usedAt: new Date() });
        
            const token = signJwt({ id: user!.id });

            return res.status(201).json({
                token,
                user
            });
        });
    } catch (err) {
        logger.error(`(POST /api/auth/register) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information, and maybe logging
        return res.json(500);
    }
});

export default router;