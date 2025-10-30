import { Router } from 'express';
import { adminPerms, authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { invites } from '../../db/schema.js';
import crypto from 'node:crypto';
import { eq } from 'drizzle-orm';
import { logger } from '../utils/logger.js';
import { isUUID } from '../utils/isUUID.js';

const router = Router();
router.use(authMiddleware, adminPerms);

function generateInviteToken() {
    return crypto.randomBytes(16).toString('hex');
}

router.post('/invites/generate', async (req, res) => {
    const { expiryDays = '7' } = req.body;

    if (isNaN(Number(expiryDays))) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'ADMIN_001',
            message: 'Invalid expiryDays. Must be a number'
        });
    }

    const token = generateInviteToken();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + Number(expiryDays));

    try {
        const [created] = await db
            .insert(invites)
            .values({
                createdBy: req.user!.id,
                expiresAt,
                token
            })
            .returning();

        return res.status(201).json(created);
    } catch (err) {
        logger.error(`(POST /api/admin/invites/generate) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Invite generation failed due to an internal error'
        });
    }
});

router.get('/invites', async (req, res) => {
    try {
        const invites = await db.query.invites.findMany();

        return res.json(invites);
    } catch (err) {
        logger.error(`(GET /api/admin/invites) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Invite fetching failed due to an internal error'
        });
    }
});

router.post('/invites/:token/revoke', async (req, res) => {
    const { token } = req.params;

    if (!isUUID(token)) {
        return res.status(422).json({
            error: 'UNPROCESSABLE_ENTITY',
            code: 'ADMIN_003',
            message: 'Token must be a valid UUID'
        });
    }

    try {
        const existingInvite = await db.query.invites.findFirst({
            where: eq(invites.token, token)
        });

        if (!existingInvite) {
            return res.status(404).json({
                error: 'NOT_FOUND',
                code: 'ADMIN_002',
                message: 'Invite does not exist'
            });
        }

        await db.update(invites).set({ usedAt: new Date() }).where(eq(invites.token, token));

        return res.status(200).json({
            message: 'Invite revoked'
        });
    } catch (err) {
        logger.error(`(POST /api/admin/invites/${token}/revoke) Unknown Error Occured:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Invite revocation failed due to an internal error'
        });
    }
});

export default router;
