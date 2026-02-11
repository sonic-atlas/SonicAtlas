#include <fstream>
#include "env.h"
#include "common.h"

std::unordered_map<std::string, std::string> loadDotEnv(const std::filesystem::path &path) {
    std::unordered_map<std::string, std::string> envMap;
    std::ifstream file(path);
    if (!file) return envMap;

    std::string line;
    while (std::getline(file, line)) {
        line = trim(line);
        if (line.empty() || line[0] == '#') continue;
        size_t pos = line.find('=');
        if (pos == std::string::npos) continue;

        std::string key   = trim(line.substr(0, pos));
        std::string value = trim(line.substr(pos + 1));
        envMap[key] = value;
    }

    return envMap;
}