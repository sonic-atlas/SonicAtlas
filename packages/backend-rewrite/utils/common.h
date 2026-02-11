#pragma once
#include <algorithm>
#include <string>

inline bool endsWith(const std::string &value, const std::string &suffix) {
    if (suffix.size() > value.size()) return false;
    return std::equal(suffix.rbegin(), suffix.rend(), value.rbegin());
}

bool isUUID(const std::string &str);

inline std::string toLowerCase(const std::string &input) {
    std::string result = input;
    std::transform(result.begin(), result.end(), result.begin(),
        [](unsigned char c) { return std::tolower(c); });
    return result;
}

inline std::string trim(const std::string &s) {
    std::string::const_iterator start = s.begin();
    while (start != s.end() && std::isspace(*start)) start++;

    if (start == s.end()) return "";

    std::string::const_iterator end = s.end() - 1;
    while (end != start && std::isspace(*end)) end--;
    return std::string(start, end + 1);
}