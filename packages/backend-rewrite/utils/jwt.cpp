#include <jwt-cpp/jwt.h>
#include <jwt-cpp/traits/open-source-parsers-jsoncpp/defaults.h>
#include <jwt-cpp/traits/open-source-parsers-jsoncpp/traits.h>
#include "jwt.h"

std::string JWT_SECRET;

std::optional<JwtUser> verifyJwt(const std::string &token) {
    try {
        jwt::decoded_jwt<jwt::traits::open_source_parsers_jsoncpp> decoded = jwt::decode<jwt::traits::open_source_parsers_jsoncpp>(token);

        jwt::verifier<jwt::default_clock, jwt::traits::open_source_parsers_jsoncpp> verifier = jwt::verify<jwt::traits::open_source_parsers_jsoncpp>().allow_algorithm(jwt::algorithm::hs256{JWT_SECRET}).with_claim("authenticated", jwt::claim(true));

        verifier.verify(decoded);

        JwtUser user;
        if (decoded.has_payload_claim("id")) user.id = decoded.get_payload_claim("id").as_string();
        user.authenticated = decoded.get_payload_claim("authenticated").as_boolean();
        user.issuedAt = decoded.get_issued_at();

        return user;
    } catch (...) {
        return std::nullopt;
    }
}

std::string signJwt(const JwtUser &payload, int expiresInHours) {
    std::chrono::system_clock::time_point now = std::chrono::system_clock::now();
    std::chrono::system_clock::time_point expiry = now + std::chrono::hours(expiresInHours);

    return jwt::create()
        .set_issuer("Sonic Atlas")
        .set_type("JWS")
        .set_issued_at(now)
        .set_expires_at(expiry)
        .set_payload_claim("id", jwt::claim(payload.id))
        .set_payload_claim("authenticated", jwt::claim(payload.authenticated))
        .sign(jwt::algorithm::hs256{JWT_SECRET});
}