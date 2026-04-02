using System;
using Newtonsoft.Json.Linq;
using Windows.Networking.Sockets;
using Windows.Storage.Streams;

namespace gamebar
{
    internal class WsClient
    {
        private MessageWebSocket _socket;
        private DataWriter _writer;
        public event Action<PlayerState> StateReceived;
        public event Action<SeekWebSocketObject> SeekReceived;
        public event Action<bool> IsPlayingReceived;

        public async void ConnectWebSocket()
        {
            _socket = new MessageWebSocket();
            _socket.Control.MessageType = SocketMessageType.Utf8;

            _socket.MessageReceived += Socket_MessageReceived;

            Uri serverUri = new Uri("ws://127.0.0.1:39393");
            try
            {
                await _socket.ConnectAsync(serverUri);
                _writer = new DataWriter(_socket.OutputStream);
            }
            catch
            {
                
            }
        }

        private void Socket_MessageReceived(MessageWebSocket sebder, MessageWebSocketMessageReceivedEventArgs e)
        {
            try
            {
                using (DataReader reader = e.GetDataReader())
                {
                    reader.UnicodeEncoding = Windows.Storage.Streams.UnicodeEncoding.Utf8;
                    string msg = reader.ReadString(reader.UnconsumedBufferLength);

                    var json = JObject.Parse(msg);
                    var type = (string)json["type"];
                    var payload = json["payload"];

                    if (type == "state")
                    {
                        var state = payload.ToObject<PlayerState>();
                        StateReceived?.Invoke(state);
                    }
                    else if (type == "seek")
                    {
                        var obj = payload.ToObject<SeekWebSocketObject>();
                        SeekReceived?.Invoke(obj);
                    }
                    else if (type == "play")
                    {
                        IsPlayingReceived(true);
                    }
                    else if (type == "pause")
                    {
                        IsPlayingReceived(false);
                    }
                }
            }
            catch
            {

            }
        }
    }
}
