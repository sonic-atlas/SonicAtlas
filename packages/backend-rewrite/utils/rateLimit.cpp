#include <drogon/drogon.h>
#include <mutex>
#include <unordered_map>
#include "common.h"
#include "jwt.h"
#include "rateLimit.h"

std::unordered_map<std::string, RateLimitData> ipRateLimitMap;
std::unordered_map<std::string, RateLimitData> userRateLimitMap;
std::mutex rateLimitMutex;

void setupRateLimit() {
    drogon::app().registerSyncAdvice([](const drogon::HttpRequestPtr &req) -> drogon::HttpResponsePtr {
        std::string path = req->path();
        if (endsWith(path, ".ts") || endsWith(path, ".m4s")) {
            return nullptr;
        }

        std::chrono::steady_clock::time_point now = std::chrono::steady_clock::now();
        int ipLimit = 1000;
        int userLimit = 1000;

        auto checkRateLimit = [&](std::unordered_map<std::string, RateLimitData> &map, const std::string &key, int limit, auto window) -> bool {
            RateLimitData &data = map[key];
            if (now - data.windowStart > window) {
                data.windowStart = now;
                data.count = 0;
            }
            data.count++;
            return data.count > static_cast<size_t>(limit) && req->method() != drogon::HttpMethod::Options;
        };

        std::lock_guard<std::mutex> lock(rateLimitMutex);

        // IP Rate Limiting
        std::string ipKey = req->getPeerAddr().toIp();
        if (checkRateLimit(ipRateLimitMap, ipKey, ipLimit, std::chrono::minutes(1))) {
            drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
            resp->setStatusCode(drogon::k429TooManyRequests);
            resp->setBody("IP rate limit exceeded");
            return resp;
        }

        // User Rate Limiting
        std::string userKey;
        if (req->attributes()->find("user")) {
            const JwtUser user = req->attributes()->get<JwtUser>("user");
            userKey = user.id.empty() ? ipKey : user.id;
        } else {
            userKey = ipKey;
        }

        if (checkRateLimit(userRateLimitMap, userKey, userLimit, std::chrono::hours(1))) {
            drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
            resp->setStatusCode(drogon::k429TooManyRequests);
            resp->setBody("User rate limit exceeded");
            return resp;
        }

        return nullptr;
    });
}