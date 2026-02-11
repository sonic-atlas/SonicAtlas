#pragma once
#include <chrono>

struct RateLimitData {
    std::chrono::steady_clock::time_point windowStart = std::chrono::steady_clock::now();
    size_t count = 0;
};

void setupRateLimit();