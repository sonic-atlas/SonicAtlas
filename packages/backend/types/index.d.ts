import "express";

export interface JwtUser {
    id: string;
}

declare module "express-serve-static-core" {
    interface Request {
        user?: JwtUser;
    }
}