#include "auth.h"
#include "utils/globals.h"
#include "utils/jwt.h"

using namespace api;

void auth::login(const drogon::HttpRequestPtr &req, Callback &&callback) {
    std::shared_ptr<Json::Value> json;
    try {
        json = req->getJsonObject();
    } catch (...) {
        callback(drogon::HttpResponse::newHttpJsonResponse({{"error","INVALID_JSON"}}));
        return;
    }

    if (!json || !json->isMember("password")) {
        Json::Value resJson;
        resJson["error"]   = "BAD_REQUEST";
        resJson["code"]    = "AUTH_001";
        resJson["message"] = "Password is required";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k400BadRequest);
        callback(resp);
        return;
    }

    const std::string password = (*json)["password"].asString();

    if (!serverPassword.empty() && password != serverPassword) {
        Json::Value resJson;
        resJson["error"]   = "UNAUTHORIZED";
        resJson["code"]    = "AUTH_002";
        resJson["message"] = "Invalid password";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k401Unauthorized);
        callback(resp);
        return;
    }

    JwtUser user;
    user.authenticated = true;
    const std::string token = signJwt(user);

    Json::Value resJson;
    resJson["token"]     = token;
    resJson["expiresIn"] = JWT_EXPIRY_HOURS;
    
    drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
    resp->setStatusCode(drogon::k200OK);
    callback(resp);
}