import { Router } from 'express';
import { adminPerms, authMiddleware } from '../middleware/auth.js';
import { db } from '../../db/db.js';
import { invites } from '../../db/schema.js';
import crypto from 'node:crypto';
import { eq } from 'drizzle-orm';
import { logger } from '../utils/logger.js';

const router = Router();
router.use(authMiddleware, adminPerms);

function generateInviteToken() {
    return crypto.randomBytes(16).toString('hex');
}

router.post('/invites/generate', async (req, res) => {
    const { expiryDays = '7' } = req.body;

    if (isNaN(Number(expiryDays))) {
        return res.status(400); // TODO: Send json with error information
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
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.get('/invites', async (req, res) => {
    try {
        const invites = await db.query.invites.findMany();

        return res.json(invites);
    } catch (err) {
        logger.error(`(GET /api/admin/invites) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

router.post('/invites/:token/revoke', async (req, res) => {
    const { token } = req.params;

    try {
        const existingInvite = await db.query.invites.findFirst({
            where: eq(invites.token, token)
        });

        if (!existingInvite) {
            return res.status(404); // TODO: Send json with error information
        }

        await db.update(invites).set({ usedAt: new Date() }).where(eq(invites.token, token));

        return res.status(200).json({
            message: 'Invite revoked'
        });
    } catch (err) {
        logger.error(`(POST /api/admin/invites/${token}/revoke) Unknown Error Occured:\n${err}`);
        // TODO: Send json with error information
        return res.status(500);
    }
});

export default router;
