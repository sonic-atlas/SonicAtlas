#ifndef FLUTTER_BRIDGE_H_
#define FLUTTER_BRIDGE_H_

#include <flutter_linux/flutter_linux.h>
#include <memory>
#include "mpris_controller.h"

class FlutterBridge {
public:
    explicit FlutterBridge(FlEngine* engine);
    ~FlutterBridge();

private:
    std::unique_ptr<MprisController> _mpris;
    FlMethodChannel* _channel;

    static void HandleMethodCall(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data);

    void SendEvent(const char* method, FlValue* args);
};

#endif