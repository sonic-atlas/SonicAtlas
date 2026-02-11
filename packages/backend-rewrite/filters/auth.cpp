#include "auth.h"
#include "utils/globals.h"
#include "utils/jwt.h"

void AuthMiddleware::doFilter(const drogon::HttpRequestPtr &req, drogon::FilterCallback &&fcb, drogon::FilterChainCallback&& fccb) {
    std::string authHeader = req->getHeader("Authorization");
    if (authHeader.rfind("Bearer ", 0) == 0) {
        std::string token = authHeader.substr(7);
        std::optional<JwtUser> user = verifyJwt(token);

        if (user && user->authenticated) {
            req->attributes()->insert("user", *user);
            fccb();
            return;
        }
    }

    std::string password = req->getHeader("x-server-password");

    if (serverPassword.empty()) {
        fccb();
        return;
    }

    if (password.empty()) {
        password = req->getParameter("password");
    }

    if (password.empty()) {
        Json::Value resJson;
        resJson["error"]   = "UNAUTHORIZED";
        resJson["code"]    = "AUTH_001";
        resJson["message"] = "Authentication required";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k401Unauthorized);
        fcb(resp);
        return;
    }

    if (password != serverPassword) {
        Json::Value resJson;
        resJson["error"]   = "FORBIDDEN";
        resJson["code"]    = "AUTH_002";
        resJson["message"] = "Invalid Credentials";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k403Forbidden);
        fcb(resp);
        return;
    }

    fccb();
}