import { Router } from 'express';
import { JWT_EXPIRY, signJwt } from '../utils/jwt.js';
import { logger } from '../utils/logger.js';

const router = Router();

router.post('/login', async (req, res) => {
    const { password } = req.body;

    if (!password) {
        return res.status(400).json({
            error: 'BAD_REQUEST',
            code: 'AUTH_001',
            message: 'Password is required'
        });
    }

    if (password !== process.env.SERVER_PASSWORD) {
        return res.status(401).json({
            error: 'UNAUTHORIZED',
            code: 'AUTH_002',
            message: 'Invalid password'
        });
    }

    try {
        const token = signJwt({ authenticated: true, timestamp: Date.now() });

        return res.status(200).json({
            token,
            expiresIn: JWT_EXPIRY
        });
    } catch (err) {
        logger.error(`(POST /api/auth/login) Token generation failed:\n${err}`);
        return res.status(500).json({
            error: 'INTERNAL_SERVER_ERROR',
            message: 'Login failed due to an internal error'
        });
    }
});

export default router;