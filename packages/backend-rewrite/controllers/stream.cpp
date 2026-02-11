#include <fstream>
#include "stream.h"
#include "utils/common.h"
#include "utils/globals.h"

using namespace api;

stream::ValidQualities stream::getSourceQuality(drogon::orm::Result::Reference track) {
    std::string format = toLowerCase(track["format"].as<std::string>());
    int sampleRate = track["sample_rate"].isNull() ? 44100 : track["sample_rate"].as<int>();
    int bitDepth   = track["bit_depth"].as<int>();
    int fileSize   = track["file_size"].isNull() ? 0 : track["file_size"].as<int>();
    int duration   = track["duration"].isNull() ? 1 : track["duration"].as<int>();

    int estimatedBitrate = (fileSize * 8) / duration;

    if (format == "flac") {
        if (bitDepth && bitDepth > 16 || sampleRate > 48000) return QUALITY_HIRES;
        return QUALITY_CD;
    }

    if (format == "mp3" || format == "aac" || format == "ogg" || format == "opus") {
        if (estimatedBitrate >= 320000) return QUALITY_HIGH;
        return QUALITY_EFFICIENCY;
    }

    if (format == "wav") {
        if (sampleRate > 48000) return QUALITY_HIRES;
        return QUALITY_CD;
    }

    return QUALITY_CD;
}

void stream::quality(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string &trackId) {
    (void)req;

    if (!isUUID(trackId)) {
        Json::Value resJson;
        resJson["error"]   = "UNPROCESSABLE_ENTITY";
        resJson["code"]    = "TRACK_002";
        resJson["message"] = "Track id must be a valid UUID";

        auto resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k422UnprocessableEntity);
        callback(resp);
        return;
    }

    drogon::orm::DbClientPtr dbClient = drogon::app().getDbClient();

    /**
     * Interesting, but this would also work here as an alternative method:
     * *dbClient << "QUERY"
     *           << trackId
     *           >> [&](const drogon::orm::Result &r) { ... }
     *           >> [callback](const drogon::orm::DrogonDbException &e)
     * 
     * Yes this is asynchronous non-blocking (You can '<< drogon::orm::Mode::Blocking' (or just '<< 1') to make it synchronous and blocking)
     * See more:
     * https://github.com/drogonframework/drogon/wiki/ENG-08-1-DataBase-DbClient#operator
     */

    dbClient->execSqlAsync("SELECT * FROM tracks WHERE id=$1", [&](const drogon::orm::Result &r) {
            if (r.size() == 0) {
                Json::Value resJson;
                resJson["error"] = "NOT_FOUND";
                resJson["code"] = "TRACK_001";
                resJson["message"] = "Track not found";

                drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
                resp->setStatusCode(drogon::k404NotFound);
                callback(resp);
                return;
            }

            drogon::orm::Result::Reference row = r[0];
            std::string format = row["format"].as<std::string>();
            int sampleRate = row["sample_rate"].as<int>();
            int bitDepth = row["bit_depth"].as<int>();
            std::string sourceQuality = row["source_quality"].as<std::string>();

            std::vector<std::string>::const_iterator it = std::find(qualityHierarchy.begin(), qualityHierarchy.end(), sourceQuality);
            std::vector<std::string> availableQualities;
            if (it != qualityHierarchy.end()) {
                availableQualities = std::vector<std::string>(qualityHierarchy.begin(), it + 1);
            } else {
                availableQualities = qualityHierarchy;
            }

            Json::Value resJson;
            resJson["sourceQuality"] = sourceQuality;
            resJson["availableQualities"] = Json::arrayValue;
            for (std::string &q : availableQualities) {
                resJson["availableQualities"].append(q);
            }
            resJson["track"]["format"]     = format;
            resJson["track"]["sampleRate"] = sampleRate;
            resJson["track"]["bitDepth"]   = bitDepth;

            drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
            callback(resp);
        },
        [callback](const drogon::orm::DrogonDbException &e) {
            (void)e;
            
            Json::Value resJson;
            resJson["error"]   = "INTERNAL_SERVER_ERROR";
            resJson["message"] = "Failed to fetch track qualities";

            drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
            resp->setStatusCode(drogon::k500InternalServerError);
            callback(resp);
        },
        trackId
    );
}

void stream::playlist_master(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId) {
    std::filesystem::path filepath = hlsRoot / trackId / "master.m3u8";

    if (!std::filesystem::exists(filepath)) {
        Json::Value resJson;
        resJson["error"]   = "NOT_FOUND";
        resJson["code"]    = "STREAM_001";
        resJson["message"] = "Playlist 'master' not found";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k404NotFound);
        callback(resp);
        return;
    }

    std::filesystem::file_time_type mtime = std::filesystem::last_write_time(filepath);
    std::string etag = std::to_string(static_cast<uint64_t>(mtime.time_since_epoch().count()));
    std::string ifNoneMatch = req->getHeader("If-None-Match");
    if (ifNoneMatch == etag) {
        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::k304NotModified);
        callback(resp);
        return;
    }

    drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
    resp->addHeader("Content-Type", "application/vnd.apple.mpegurl");
    resp->addHeader("Cache-Control", "no-cache");
    resp->addHeader("ETag", etag);

    std::ifstream file(filepath, std::ios::binary);
    if (!file) {
        Json::Value resJson;
        resJson["error"]   = "INTERNAL_SERVER_ERROR";
        resJson["code"]    = "STREAM_002";
        resJson["message"] = "Could not open playlist file";

        drogon::HttpResponsePtr respErr = drogon::HttpResponse::newHttpJsonResponse(resJson);
        respErr->setStatusCode(drogon::k500InternalServerError);
        callback(respErr);
        return;
    }

    std::string fileContent((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    resp->setBody(fileContent);
    callback(resp);
}

void stream::playlist(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId, const std::string quality, const std::string filename) {
    std::filesystem::path filepath = hlsRoot / trackId / quality / filename;

    if (!std::filesystem::exists(filepath)) {
        Json::Value resJson;
        resJson["error"]   = "NOT_FOUND";
        resJson["code"]    = "STREAM_001";
        resJson["message"] = "Playlist '" + quality + "/" + filename + "' not found";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k404NotFound);
        callback(resp);
        return;
    }

    std::filesystem::file_time_type mtime = std::filesystem::last_write_time(filepath);
    std::string etag = std::to_string(static_cast<uint64_t>(mtime.time_since_epoch().count())); // static_cast as some platforms have different precision
    std::string ifNoneMatch = req->getHeader("If-None-Match");
    if (ifNoneMatch == etag) {
        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::k304NotModified);
        callback(resp);
        return;
    }

    drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
    resp->addHeader("Content-Type", "application/vnd.apple.mpegurl");
    resp->addHeader("Cache-Control", "no-cache");
    resp->addHeader("ETag", etag);

    std::ifstream file(filepath, std::ios::binary);
    if (!file) {
        Json::Value resJson;
        resJson["error"]   = "INTERNAL_SERVER_ERROR";
        resJson["code"]    = "STREAM_002";
        resJson["message"] = "Could not open playlist file";

        drogon::HttpResponsePtr respErr = drogon::HttpResponse::newHttpJsonResponse(resJson);
        respErr->setStatusCode(drogon::k500InternalServerError);
        callback(respErr);
        return;
    }

    std::string fileContent((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    resp->setBody(fileContent);

    callback(resp);
}

void stream::segment(const drogon::HttpRequestPtr &req, Callback &&callback, const std::string trackId, const std::string quality, const std::string segment) {
    (void)req;

    std::filesystem::path requested = hlsRoot / trackId / quality / segment;
    std::filesystem::path full = std::filesystem::weakly_canonical(requested).lexically_normal();

#ifdef _WIN32
    std::wstring baseStr = hlsBase.wstring();
    std::wstring fullStr = full.wstring();
#else
    std::string baseStr = hlsBase.string();
    std::string fullStr = full.string();
#endif

    if (fullStr.rfind(baseStr, 0) != 0) {
        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpResponse();
        resp->setStatusCode(drogon::k403Forbidden);
        callback(resp);
        return;
    }

    if (!std::filesystem::exists(full)) {
        Json::Value resJson;
        resJson["error"]   = "NOT_FOUND";
        resJson["code"]    = "STREAM_001";
        resJson["message"] = "Track segment '" + segment +  "' not found";

        drogon::HttpResponsePtr resp = drogon::HttpResponse::newHttpJsonResponse(resJson);
        resp->setStatusCode(drogon::k404NotFound);
        callback(resp);
        return;
    }

    auto resp = drogon::HttpResponse::newFileResponse(full.string());
    resp->addHeader("Content-Type", full.extension() == ".ts" ? "video/mp2t" : "audio/mp4");
    resp->addHeader("Cache-Control", "public, max-age=31536000, immutable");
    
    callback(resp);
}