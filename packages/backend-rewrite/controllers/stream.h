#pragma once
#include <drogon/HttpController.h>
#include "utils/callback.h"

using namespace drogon;

namespace api {

class stream : public drogon::HttpController<stream> {
public:
    METHOD_LIST_BEGIN

    METHOD_ADD(stream::quality, "/{trackId}/quality", drogon::Get, "AuthMiddleware");
    METHOD_ADD(stream::playlist_master, "/{trackId}/master.m3u8", drogon::Get, "AuthMiddleware");
    METHOD_ADD(stream::playlist, "/{trackId}/{quality}/{filename}.m3u8", drogon::Get, "AuthMiddleware");
    METHOD_ADD(stream::segment, "/{trackId}/{quality}/{segment}", drogon::Get, "AuthMiddleware");

    METHOD_LIST_END

    void quality(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string &trackId);
    void playlist_master(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId);
    void playlist(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId, const std::string quality, const std::string filename);
    void segment(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId, const std::string quality, const std::string segment);

private:
    enum ValidQualities {
        QUALITY_EFFICIENCY,
        QUALITY_HIGH,
        QUALITY_CD,
        QUALITY_HIRES
    };
    const std::vector<std::string> qualityHierarchy = {"efficiency", "high", "cd", "hires"};
    ValidQualities getSourceQuality(drogon::orm::Result::Reference track);
};

}