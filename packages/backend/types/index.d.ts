import 'express';

export interface JwtUser {
    id?: string;
    authenticated?: boolean;
    timestamp?: number;
}

declare module 'express-serve-static-core' {
    interface Request {
        user?: JwtUser;
    }
}