#include <drogon/drogon.h>
#include <iostream>

#include "utils/common.h"
#include "utils/cors.h"
#include "utils/env.h"
#include "utils/globals.h"
#include "utils/ip.h"
#include "utils/jwt.h"
#include "utils/misc.h"
#include "utils/rateLimit.h"

/* std::optional<JwtUser> getUser(const drogon::HttpRequestPtr &req) {
    if (req->getAttributes()->find("user")) {
        return req->attributes()->get<JwtUser>("user");
    }
    return std::nullopt;
} */

int main() {
    try {
        std::chrono::steady_clock::time_point start = std::chrono::high_resolution_clock::now();

        std::unordered_map<std::string, std::string> envMap = loadDotEnv(".env");

        const std::string localIp = getLocalIp();

        auto env = [&envMap](const std::string &key, std::optional<std::string> fallback = std::nullopt) -> std::string {
            auto it = envMap.find(key);
            if (it != envMap.end()) return it->second;

            if (const char *v = std::getenv(key.c_str())) return v;
            if (fallback) return *fallback;
            
            std::cerr << "Missing required env var: " << key << std::endl;
            std::exit(1);
        };

        serverPassword = env("SERVER_PASSWORD", "");
        JWT_SECRET = env("JWT_SECRET", "super-secret-key");

        hlsRoot = "C:/dev/sonic-atlas/SonicAtlas/storage/hls";
        hlsBase = std::filesystem::weakly_canonical(hlsRoot).lexically_normal();

        setupCors(localIp);
        setupJsonParsing();
        setupRateLimit();

        drogon::app().loadConfigFile("config.json");

        drogon::orm::PostgresConfig dbConf;
        dbConf.host         = env("DB_HOST");
        dbConf.port         = static_cast<unsigned short>(std::stoi(env("DB_PORT")));
        dbConf.databaseName = env("DB_NAME");
        dbConf.username     = env("DB_USER");
        dbConf.password     = env("DB_PASS");
        dbConf.connectionNumber = 1;
        dbConf.timeout = 30;

        drogon::app().addDbClient(dbConf);

        drogon::app().registerBeginningAdvice([localIp, start]() {
            std::chrono::steady_clock::time_point end = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> elapsed = end - start;
            std::cout << "Server is running at (" << elapsed.count() <<  "ms):" << std::endl;
            std::cout << "  Local:   \033[4;32mhttp://localhost:8080\033[0m" << std::endl;
            std::cout << "  Network: \033[4;32mhttp://" << localIp << ":8080\033[0m" << std::endl;
        });

        drogon::app().run();

        return 0;
    } catch (const std::exception &e) {
        std::cerr << "Fatal error: " << e.what() << std::endl;
#ifdef _WIN32
        MessageBoxA(nullptr, e.what(), "Startup error", MB_OK | MB_ICONERROR);
#endif
        return 1;
    } catch (...) {
        std::cerr << "Fatal unknown error" << std::endl;
#ifdef _WIN32
        MessageBoxA(nullptr, "Unknown fatal error", "Startup error", MB_OK | MB_ICONERROR);
#endif
        return 1;
    }
}

#pragma endregion main()