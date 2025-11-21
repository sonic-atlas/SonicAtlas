#ifndef MPRIS_CONTROLLER_H_
#define MPRIS_CONTROLLER_H_

#include <gio/gio.h>
#include <functional>
#include <string>

// Seek callbacks in microseconds
using SeekCallback = std::function<void(int64_t)>;
using SetPositionCallback = std::function<void(int64_t)>;
using VoidCallback = std::function<void()>;

class MprisController {
public:
    explicit MprisController(const std::string &app_id);
    ~MprisController();

    void SetSeekHandler(SeekCallback handler);
    void SetPositionHandler(SetPositionCallback handler);
    void SetPlayHandler(VoidCallback handler);
    void SetPauseHandler(VoidCallback handler);
    void SetNextHandler(VoidCallback handler);
    void SetPreviousHandler(VoidCallback handler);

    void UpdatePlaybackState(bool playing, int64_t position_us, double speed);
    void UpdateMetadata(const std::string &title, const std::string &artist,
                        const std::string &album, const std::string &art_url,
                        int64_t duration_us);

private:
    void OnBusAcquired(GDBusConnection *connection, const gchar *name);
    void EmitPropertiesChanged(GVariantBuilder *builder);

    static void HandleMethodCall(GDBusConnection *connection,
                                 const gchar *sender,
                                 const gchar *object_path,
                                 const gchar *interface_name,
                                 const gchar *method_name,
                                 GVariant *parameters,
                                 GDBusMethodInvocation *invocation,
                                 gpointer user_data);

    static GVariant *HandleGetProperty(GDBusConnection *connection,
                                       const gchar *sender,
                                       const gchar *object_path,
                                       const gchar *interface_name,
                                       const gchar *property_name,
                                       GError **error,
                                       gpointer user_data);

    guint _owner_id;
    guint _registration_id;
    GDBusNodeInfo *_introspection_data;
    GDBusConnection *_connection = nullptr;
    std::string _app_id;

    SeekCallback _seek_callback;
    SetPositionCallback _set_position_callback;
    VoidCallback _play_callback;
    VoidCallback _pause_callback;
    VoidCallback _next_callback;
    VoidCallback _previous_callback;

    // State (time in microseconds)
    int64_t _last_position_us = 0;
    int64_t _last_update_time = 0;
    bool _is_playing = false;
    double _playback_speed = 1.0;

    // Metadata
    std::string _title;
    std::string _artist;
    std::string _album;
    std::string _art_url;
    int64_t _duration_us = 0;
};

#endif