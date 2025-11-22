#include "flutter_bridge.h"

FlutterBridge::FlutterBridge(FlEngine* engine) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    FlBinaryMessenger* messenger = fl_engine_get_binary_messenger(engine);

    _channel = fl_method_channel_new(messenger, "sonic_atlas/mpris", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(_channel, HandleMethodCall, this, nullptr);

    _mpris = std::make_unique<MprisController>("sonic_atlas");

    _mpris->SetSeekHandler([this](int64_t offset) { this->SendEvent("onSeek", fl_value_new_int(offset)); });
    _mpris->SetPositionHandler([this](int64_t pos) { this->SendEvent("onSetPosition", fl_value_new_int(pos)); });
    _mpris->SetPlayHandler([this]() { this->SendEvent("onPlay", nullptr); });
    _mpris->SetPauseHandler([this]() { this->SendEvent("onPause", nullptr); });
    _mpris->SetNextHandler([this]() { this->SendEvent("onNext", nullptr); });
    _mpris->SetPreviousHandler([this]() { this->SendEvent("onPrevious", nullptr); });
}

FlutterBridge::~FlutterBridge() {
    if (_channel) {
        g_object_unref(_channel);
        _channel = nullptr;
    }
}

void FlutterBridge::HandleMethodCall(FlMethodChannel* channel, FlMethodCall* call, gpointer user_data) {
    auto* self = static_cast<FlutterBridge*>(user_data);
    const gchar* method = fl_method_call_get_name(call);
    FlValue* args = fl_method_call_get_args(call);

    if (g_strcmp0(method, "updateState") == 0) {
        if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* playing = fl_value_lookup_string(args, "playing");
            FlValue* pos = fl_value_lookup_string(args, "position");
            FlValue* speed = fl_value_lookup_string(args, "speed");

            if (playing && pos && speed) {
                self->_mpris->UpdatePlaybackState(
                        fl_value_get_bool(playing),
                        fl_value_get_int(pos),
                        fl_value_get_float(speed)
                );
            }
        }
        fl_method_call_respond_success(call, nullptr, nullptr);
    }
    else if (g_strcmp0(method, "updateMetadata") == 0) {
        if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* title = fl_value_lookup_string(args, "title");
            FlValue* artist = fl_value_lookup_string(args, "artist");
            FlValue* album = fl_value_lookup_string(args, "album");
            FlValue* art = fl_value_lookup_string(args, "artUrl");
            FlValue* dur = fl_value_lookup_string(args, "duration");

            self->_mpris->UpdateMetadata(
                    title ? fl_value_get_string(title) : "",
                    artist ? fl_value_get_string(artist) : "",
                    album ? fl_value_get_string(album) : "",
                    art ? fl_value_get_string(art) : "",
                    dur ? fl_value_get_int(dur) : 0
            );
        }
        fl_method_call_respond_success(call, nullptr, nullptr);
    }
    else {
        fl_method_call_respond_not_implemented(call, nullptr);
    }
}

void FlutterBridge::SendEvent(const char* method, FlValue* args) {
    fl_method_channel_invoke_method(_channel, method, args, nullptr, nullptr, nullptr);
}