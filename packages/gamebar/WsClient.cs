using System;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using Windows.Networking.Sockets;
using Windows.Storage.Streams;

namespace gamebar
{
    internal class WsClient : IDisposable
    {
        private MessageWebSocket _socket;
        private bool _connecting;
        private bool _isConnected;
        public bool IsConnected => _isConnected;

        public event Action<PlayerState> StateReceived;
        public event Action<SeekWebSocketObject> SeekReceived;
        public event Action<bool> IsPlayingReceived;

        public async Task StartAsync(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                if (!_isConnected && !_connecting)
                {
                    await ConnectAsync();
                }

                await Task.Delay(2000, token);
            }
        }

        private async Task ConnectAsync()
        {
            _connecting = true;

            try
            {
                _socket?.Dispose();

                _socket = new MessageWebSocket();
                _socket.Control.MessageType = SocketMessageType.Utf8;

                _socket.MessageReceived += Socket_MessageReceived;
                _socket.Closed += Socket_Closed;

                var connectTask = _socket.ConnectAsync(new Uri("ws://127.0.0.1:39393")).AsTask();

                if (await Task.WhenAny(connectTask, Task.Delay(2000)) != connectTask)
                {
                    throw new TimeoutException("WebSocket connect timed out");
                }

                await connectTask;

                _isConnected = true;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine(ex);
                _isConnected = false;
            }
            finally
            {
                _connecting = false;
            }
        }

        private void Socket_Closed(IWebSocket sender, WebSocketClosedEventArgs args)
        {
            _isConnected = false;
        }

        private void Socket_MessageReceived(MessageWebSocket sebder, MessageWebSocketMessageReceivedEventArgs e)
        {
            try
            {
                using (DataReader reader = e.GetDataReader())
                {
                    reader.UnicodeEncoding = UnicodeEncoding.Utf8;
                    string msg = reader.ReadString(reader.UnconsumedBufferLength);

                    var json = JObject.Parse(msg);
                    var type = (string)json["type"];
                    var payload = json["payload"];

                    switch (type)
                    {
                        case "state":
                            StateReceived?.Invoke(payload.ToObject<PlayerState>());
                            break;
                        case "seek":
                            SeekReceived?.Invoke(payload.ToObject<SeekWebSocketObject>());
                            break;
                        case "play":
                            IsPlayingReceived?.Invoke(true);
                            break;
                        case "pause":
                            IsPlayingReceived?.Invoke(false);
                            break;
                    }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine(ex);
            }
        }

        public void Dispose()
        {
            _socket?.Dispose();
        }
    }
}
