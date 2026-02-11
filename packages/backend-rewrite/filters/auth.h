#pragma once
#include <drogon/HttpFilter.h>

class AuthMiddleware : public drogon::HttpFilter<AuthMiddleware> {
public:
    void doFilter(const drogon::HttpRequestPtr &req, drogon::FilterCallback &&fcb, drogon::FilterChainCallback&& fccb) override;
};