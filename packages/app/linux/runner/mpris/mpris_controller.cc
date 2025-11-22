#include "mpris_controller.h"
#include <iostream>

const gchar* introspection_xml =
        "<node>"
        "  <interface name='org.mpris.MediaPlayer2'>"
        "    <method name='Raise'/>"
        "    <method name='Quit'/>"
        "    <property name='CanQuit' type='b' access='read'/>"
        "    <property name='CanRaise' type='b' access='read'/>"
        "    <property name='HasTrackList' type='b' access='read'/>"
        "    <property name='Identity' type='s' access='read'/>"
        "    <property name='DesktopEntry' type='s' access='read'/>"
        "    <property name='SupportedUriSchemes' type='as' access='read'/>"
        "    <property name='SupportedMimeTypes' type='as' access='read'/>"
        "  </interface>"
        "  <interface name='org.mpris.MediaPlayer2.Player'>"
        "    <method name='PlayPause'/>"
        "    <method name='Play'/>"
        "    <method name='Pause'/>"
        "    <method name='Next'/>"
        "    <method name='Previous'/>"
        "    <method name='Stop'/>"
        "    <method name='Seek'>"
        "      <arg direction='in' type='x' name='Offset'/>"
        "    </method>"
        "    <method name='SetPosition'>"
        "      <arg direction='in' type='o' name='TrackId'/>"
        "      <arg direction='in' type='x' name='Position'/>"
        "    </method>"
        "    <property name='PlaybackStatus' type='s' access='read'/>"
        "    <property name='Metadata' type='a{sv}' access='read'/>"
        "    <property name='Position' type='x' access='read'/>"
        "    <property name='Rate' type='d' access='read'/>"
        "    <property name='CanGoNext' type='b' access='read'/>"
        "    <property name='CanGoPrevious' type='b' access='read'/>"
        "    <property name='CanPlay' type='b' access='read'/>"
        "    <property name='CanPause' type='b' access='read'/>"
        "    <property name='CanSeek' type='b' access='read'/>"
        "    <property name='CanControl' type='b' access='read'/>"
        "  </interface>"
        "</node>";

MprisController::MprisController(const std::string& app_id) : _app_id(app_id) {
    _introspection_data = g_dbus_node_info_new_for_xml(introspection_xml, nullptr);

    std::string mpris_name = "org.mpris.MediaPlayer2." + _app_id;
    _owner_id = g_bus_own_name(G_BUS_TYPE_SESSION,
                               mpris_name.c_str(),
                               G_BUS_NAME_OWNER_FLAGS_NONE,
                               [](GDBusConnection* c, const gchar* n, gpointer d) {
                                   static_cast<MprisController*>(d)->OnBusAcquired(c, n);
                               },
                               nullptr, nullptr, this, nullptr);
}

MprisController::~MprisController() {
    if (_owner_id > 0) g_bus_unown_name(_owner_id);
    if (_introspection_data) g_dbus_node_info_unref(_introspection_data);
}

void MprisController::OnBusAcquired(GDBusConnection* connection, const gchar* name) {
    _connection = connection;
    GDBusInterfaceVTable vtable = {
            &MprisController::HandleMethodCall,
            &MprisController::HandleGetProperty,
            nullptr
    };

    // Register org.mpris.MediaPlayer2 interface
    g_dbus_connection_register_object(
            connection,
            "/org/mpris/MediaPlayer2",
            _introspection_data->interfaces[0],
            &vtable,
            this,
            nullptr,
            nullptr
    );

    // Register org.mpris.MediaPlayer2.Player interface
    _registration_id = g_dbus_connection_register_object(
            connection,
            "/org/mpris/MediaPlayer2",
            _introspection_data->interfaces[1],
            &vtable,
            this,
            nullptr,
            nullptr
    );
}

void MprisController::HandleMethodCall(GDBusConnection* connection, const gchar* sender,
                                       const gchar* object_path, const gchar* interface_name,
                                       const gchar* method_name, GVariant* parameters,
                                       GDBusMethodInvocation* invocation, gpointer user_data) {
    auto* self = static_cast<MprisController*>(user_data);

    if (g_strcmp0(method_name, "Raise") == 0) {
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Quit") == 0) {
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "PlayPause") == 0) {
        if (self->_is_playing) {
            if (self->_pause_callback) self->_pause_callback();
        } else {
            if (self->_play_callback) self->_play_callback();
        }
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Play") == 0) {
        if (self->_play_callback) self->_play_callback();
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Pause") == 0 || g_strcmp0(method_name, "Stop") == 0) {
        if (self->_pause_callback) self->_pause_callback();
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Next") == 0) {
        if (self->_next_callback) self->_next_callback();
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Previous") == 0) {
        if (self->_previous_callback) self->_previous_callback();
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "Seek") == 0) {
        int64_t offset;
        g_variant_get(parameters, "(x)", &offset);
        if (self->_seek_callback) self->_seek_callback(offset);
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
    else if (g_strcmp0(method_name, "SetPosition") == 0) {
        const gchar* track_id;
        int64_t position;
        g_variant_get(parameters, "(ox)", &track_id, &position);
        if (self->_set_position_callback) self->_set_position_callback(position);
        g_dbus_method_invocation_return_value(invocation, nullptr);
    }
}

GVariant* MprisController::HandleGetProperty(GDBusConnection* connection, const gchar* sender,
                                             const gchar* object_path, const gchar* interface_name,
                                             const gchar* property_name, GError** error,
                                             gpointer user_data) {
    auto* self = static_cast<MprisController*>(user_data);

    // org.mpris.MediaPlayer2 properties
    if (g_strcmp0(property_name, "Identity") == 0) {
        return g_variant_new_string("Sonic Atlas Playback");
    }
    if (g_strcmp0(property_name, "DesktopEntry") == 0) {
        return g_variant_new_string("sonic_atlas");
    }
    if (g_strcmp0(property_name, "SupportedUriSchemes") == 0) {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("as"));
        return g_variant_builder_end(&builder);
    }
    if (g_strcmp0(property_name, "SupportedMimeTypes") == 0) {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("as"));
        return g_variant_builder_end(&builder);
    }
    if (g_strcmp0(property_name, "CanQuit") == 0) return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "CanRaise") == 0) return g_variant_new_boolean(FALSE);
    if (g_strcmp0(property_name, "HasTrackList") == 0) return g_variant_new_boolean(FALSE);


    // org.mpris.MediaPlayer2.Player properties
    if (g_strcmp0(property_name, "PlaybackStatus") == 0) {
        return g_variant_new_string(self->_is_playing ? "Playing" : "Paused");
    }
    if (g_strcmp0(property_name, "Metadata") == 0) {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

        g_variant_builder_add(&builder, "{sv}", "mpris:trackid", g_variant_new_object_path("/org/mpris/MediaPlayer2/Track/0"));
        g_variant_builder_add(&builder, "{sv}", "mpris:length", g_variant_new_int64(self->_duration_us));
        g_variant_builder_add(&builder, "{sv}", "xesam:title", g_variant_new_string(self->_title.c_str()));
        g_variant_builder_add(&builder, "{sv}", "xesam:album", g_variant_new_string(self->_album.c_str()));

        GVariantBuilder artist_builder;
        g_variant_builder_init(&artist_builder, G_VARIANT_TYPE("as"));
        g_variant_builder_add(&artist_builder, "s", self->_artist.c_str());
        g_variant_builder_add(&builder, "{sv}", "xesam:artist", g_variant_builder_end(&artist_builder));

        if (!self->_art_url.empty()) {
            g_variant_builder_add(&builder, "{sv}", "mpris:artUrl", g_variant_new_string(self->_art_url.c_str()));
        }
        return g_variant_builder_end(&builder);
    }
    if (g_strcmp0(property_name, "Position") == 0) {
        int64_t current = self->_last_position_us;
        if (self->_is_playing) {
            current += (int64_t)((g_get_monotonic_time() - self->_last_update_time) * self->_playback_speed);
        }
        return g_variant_new_int64(current);
    }
    if (g_strcmp0(property_name, "Rate") == 0) return g_variant_new_double(self->_playback_speed);

    if (g_strcmp0(property_name, "CanGoNext") == 0 || g_strcmp0(property_name, "CanGoPrevious") == 0 ||
        g_strcmp0(property_name, "CanPlay") == 0 || g_strcmp0(property_name, "CanPause") == 0 ||
        g_strcmp0(property_name, "CanSeek") == 0 || g_strcmp0(property_name, "CanControl") == 0) {
        return g_variant_new_boolean(TRUE);
    }

    return nullptr;
}

void MprisController::UpdatePlaybackState(bool playing, int64_t position_us, double speed) {
    _is_playing = playing;
    _last_position_us = position_us;
    _playback_speed = speed;
    _last_update_time = g_get_monotonic_time();

    if (_connection) {
        int64_t current = _last_position_us;
        if (_is_playing) {
            current += (int64_t)((g_get_monotonic_time() - _last_update_time) * _playback_speed);
        }

        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

        g_variant_builder_add(&builder, "{sv}", "PlaybackStatus", g_variant_new_string(playing ? "Playing" : "Paused"));
        g_variant_builder_add(&builder, "{sv}", "Position", g_variant_new_int64(current));
        g_variant_builder_add(&builder, "{sv}", "Rate", g_variant_new_double(_playback_speed));

        EmitPropertiesChanged(&builder);
    }
}

void MprisController::UpdateMetadata(const std::string& title, const std::string& artist,
                                     const std::string& album, const std::string& art_url, int64_t duration_us) {
    if (_title == title && _artist == artist && _duration_us == duration_us && _art_url == art_url) return;

    _title = title;
    _artist = artist;
    _album = album;
    _art_url = art_url;
    _duration_us = duration_us;

    if (_connection) {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, G_VARIANT_TYPE("a{sv}"));

        GVariantBuilder meta_builder;
        g_variant_builder_init(&meta_builder, G_VARIANT_TYPE("a{sv}"));
        g_variant_builder_add(&meta_builder, "{sv}", "mpris:trackid", g_variant_new_object_path("/org/mpris/MediaPlayer2/Track/0"));
        g_variant_builder_add(&meta_builder, "{sv}", "mpris:length", g_variant_new_int64(duration_us));
        g_variant_builder_add(&meta_builder, "{sv}", "xesam:title", g_variant_new_string(title.c_str()));
        g_variant_builder_add(&meta_builder, "{sv}", "xesam:album", g_variant_new_string(album.c_str()));

        GVariantBuilder artist_builder;
        g_variant_builder_init(&artist_builder, G_VARIANT_TYPE("as"));
        g_variant_builder_add(&artist_builder, "s", artist.c_str());
        g_variant_builder_add(&meta_builder, "{sv}", "xesam:artist", g_variant_builder_end(&artist_builder));

        if (!art_url.empty()) {
            g_variant_builder_add(&meta_builder, "{sv}", "mpris:artUrl", g_variant_new_string(art_url.c_str()));
        }

        g_variant_builder_add(&builder, "{sv}", "Metadata", g_variant_builder_end(&meta_builder));
        EmitPropertiesChanged(&builder);
    }
}

void MprisController::EmitPropertiesChanged(GVariantBuilder* builder) {
    g_dbus_connection_emit_signal(_connection, nullptr, "/org/mpris/MediaPlayer2",
                                  "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                  g_variant_new("(sa{sv}as)", "org.mpris.MediaPlayer2.Player", builder, nullptr), nullptr);
}

void MprisController::SetSeekHandler(SeekCallback h) { _seek_callback = h; }
void MprisController::SetPositionHandler(SetPositionCallback h) { _set_position_callback = h; }
void MprisController::SetPlayHandler(VoidCallback h) { _play_callback = h; }
void MprisController::SetPauseHandler(VoidCallback h) { _pause_callback = h; }
void MprisController::SetNextHandler(VoidCallback h) { _next_callback = h; }
void MprisController::SetPreviousHandler(VoidCallback h) { _previous_callback = h; }