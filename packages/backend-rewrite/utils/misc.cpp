#include <drogon/drogon.h>

void setupJsonParsing() {
    drogon::app().registerSyncAdvice([](const drogon::HttpRequestPtr &req) -> drogon::HttpResponsePtr {
        if (req->body().length() > 10 * 1024 * 1024) {
            drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
            resp->setStatusCode(drogon::k413RequestEntityTooLarge);
            resp->setBody("Request body too large");
            return resp;
        }

        return nullptr;
    });
}