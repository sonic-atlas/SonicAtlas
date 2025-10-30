import { Router } from 'express';
import { db } from '../../db/db.js';
import { users } from '../../db/schema.js';
import { count } from 'drizzle-orm';
import bcrypt from 'bcrypt';
import { logger } from '../utils/logger.js';

const router = Router();

router.get('/status', async (req, res) => {
    try {
        const [result] = await db.select({ count: count() }).from(users);
        const setupComplete = result!.count > 0;
        
        res.json({ setupComplete });
    } catch (err) {
        logger.error(`Setup status check failed: ${err}`);
        res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            code: 'SETUP_001',
            message: 'Failed to check setup status'
        });
    }
});

router.post('/admin', async (req, res) => {
    try {
        const [result] = await db.select({ count: count() }).from(users);

        if (result!.count > 0) {
            return res.status(403).json({ 
                error: 'SETUP_ALREADY_COMPLETE',
                code: 'SETUP_002',
                message: 'Admin account already exists' 
            });
        }

        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ 
                error: 'BAD_REQUEST',
                code: 'SETUP_003',
                message: 'Username and password are required' 
            });
        }

        if (password.length < 8) {
            return res.status(400).json({ 
                error: 'BAD_REQUEST',
                code: 'SETUP_004',
                message: 'Password must be at least 8 characters' 
            });
        }

        const passwordHash = await bcrypt.hash(
            password,
            Number(process.env.BCRYPT_SALT_ROUNDS) || 12
        );

        await db.insert(users).values({
            username,
            passwordHash,
            role: 'admin'
        });

        logger.info(`Admin user created: ${username}`);
        return res.json({ success: true });
    } catch (err) {
        logger.error(`Failed to create admin user: ${err}`);
        res.status(500).json({ 
            error: 'INTERNAL_SERVER_ERROR',
            code: 'SETUP_005',
            message: 'Failed to create admin account' 
        });
    }
});

export default router;