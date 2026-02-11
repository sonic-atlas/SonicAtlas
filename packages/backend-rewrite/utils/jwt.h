#pragma once
#include <chrono>
#include <optional>
#include <string.h>

struct JwtUser {
    std::string id;
    bool authenticated = false;
    std::chrono::system_clock::time_point issuedAt;
};

inline constexpr int JWT_EXPIRY_HOURS = 168;
extern std::string JWT_SECRET;

std::optional<JwtUser> verifyJwt(const std::string &token);
std::string signJwt(const JwtUser &payload, int expiresInHours = JWT_EXPIRY_HOURS);