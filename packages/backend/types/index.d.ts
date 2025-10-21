import "express";

export interface JwtUser {
    id: number;
}

declare module "express-serve-static-core" {
    interface Request {
        user?: JwtUser;
    }
}