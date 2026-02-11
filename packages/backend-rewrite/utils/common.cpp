#include <regex>
#include "common.h"

bool isUUID(const std::string &str) {
    static const std::regex uuid("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", std::regex::icase);
    return std::regex_match(str, uuid);
}