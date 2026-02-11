#pragma once
#include <string>
#include <unordered_set>

std::unordered_set<std::string> getAllowedOrigins(const std::string &ip);
void setupCors(const std::string &ip);