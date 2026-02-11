#pragma once
#include <drogon/HttpController.h>
#include "utils/callback.h"

using namespace drogon;

namespace api {

class auth : public drogon::HttpController<auth> {
public:
    METHOD_LIST_BEGIN
        METHOD_ADD(auth::login, "/login", drogon::Post);
    METHOD_LIST_END

    void login(const drogon::HttpRequestPtr &req, Callback &&callback);
};

}