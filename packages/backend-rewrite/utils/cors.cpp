#include <drogon/drogon.h>
#include "cors.h"

std::unordered_set<std::string> getAllowedOrigins(const std::string &ip) {
    std::unordered_set<std::string> allowedOrigins = {
        "http://localhost:5173",
        "http://" + ip + ":5173"
    };
    return allowedOrigins;
}

void setupCors(const std::string &ip) {
    std::unordered_set<std::string> allowedOrigins = getAllowedOrigins(ip);

    drogon::app().registerSyncAdvice([allowedOrigins](const drogon::HttpRequestPtr &req) -> drogon::HttpResponsePtr {
        if (req->method() != drogon::HttpMethod::Options) {
            return nullptr;
        }

        std::string origin = req->getHeader("Origin");
        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();

        if (!origin.empty() && allowedOrigins.count(origin)) {
            resp->addHeader("Access-Control-Allow-Origin", origin);
            resp->addHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,PATCH,OPTIONS");
            resp->addHeader("Access-Control-Allow-Headers", "Content-Type,Authorization,x-server-password");
            resp->addHeader("Access-Control-Allow-Credentials", "true");
            resp->setStatusCode(drogon::k204NoContent);
        } else {
            resp->setStatusCode(drogon::k403Forbidden);
        }

        return resp;
    });

    drogon::app().registerPostHandlingAdvice([allowedOrigins](const drogon::HttpRequestPtr &req, const drogon::HttpResponsePtr &resp) {
        std::string origin = req->getHeader("Origin");

        if (!origin.empty() && allowedOrigins.count(origin)) {
            resp->addHeader("Access-Control-Allow-Origin", origin);
            resp->addHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,PATCH,OPTIONS");
            resp->addHeader("Access-Control-Allow-Headers", "Content-Type,Authorization,x-server-password");
            resp->addHeader("Access-Control-Allow-Credentials", "true");
        }
    });
}