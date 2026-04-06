using System;
using System.Threading;
using System.Threading.Tasks;
using Windows.System.Threading;

namespace gamebar
{
    internal class PlayerController : IDisposable
    {
        private readonly WsClient _wsClient = new WsClient();

        private ThreadPoolTimer _progressTimer;
        private DateTime _lastSyncTime;
        private double _lastKnownPosition;

        private readonly CancellationTokenSource _cts = new CancellationTokenSource();

        public PlayerState CurrentState { get; private set; }

        public event Action<PlayerState> StateUpdated;
        public event Action<double> ProgressUpdated;

        public bool IsAvailable { get; private set; }
        public event Action<bool> AvailabilityChanged;

        public async Task InitialiseAsync()
        {
            SetAvailability(false);

            await RefreshStateAsync(_cts.Token);
            SetupWebSocket();
            StartTimer();
        }

        private void SetAvailability(bool available)
        {
            if (IsAvailable == available) return;

            IsAvailable = available;
            AvailabilityChanged?.Invoke(available);
        }

        public async Task RefreshStateAsync(CancellationToken token)
        {
            try
            {
                var json = await ApiClient.GetStateAsync();
                token.ThrowIfCancellationRequested();

                var state = Newtonsoft.Json.JsonConvert.DeserializeObject<PlayerState>(json);

                IsAvailable = true;
                AvailabilityChanged?.Invoke(true);

                ApplyState(state);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine(ex);
                SetAvailability(false);
            }
        }

        private void ApplyState(PlayerState state)
        {
            CurrentState = state;

            _lastKnownPosition = state.Position;
            _lastSyncTime = DateTime.UtcNow;

            StateUpdated?.Invoke(state);
        }

        private void SetupWebSocket()
        {
            _wsClient.StateReceived += s =>
            {
                if (!IsAvailable)
                {
                    IsAvailable = true;
                    AvailabilityChanged?.Invoke(true);
                }

                ApplyState(s);
            };

            _wsClient.SeekReceived += o =>
            {
                _lastKnownPosition = o.Position;
                _lastSyncTime = DateTime.UtcNow;

                ProgressUpdated?.Invoke(o.Position);
            };

            _wsClient.IsPlayingReceived += b =>
            {
                if (CurrentState != null)
                {
                    CurrentState.IsPlaying = b;
                    _lastSyncTime = DateTime.UtcNow;
                    StateUpdated?.Invoke(CurrentState);
                }
            };

            _ = _wsClient.StartAsync(_cts.Token);
        }

        private void StartTimer()
        {
            if (_progressTimer != null) return;

            _progressTimer = ThreadPoolTimer.CreatePeriodicTimer(_ =>
            {
                if (CurrentState == null || !CurrentState.IsPlaying) return;

                var elapsed = (DateTime.UtcNow - _lastSyncTime).TotalSeconds;
                var newPosition = _lastKnownPosition + elapsed;

                ProgressUpdated?.Invoke(newPosition);
            }, TimeSpan.FromMilliseconds(500));
        }

        private void StopTimer()
        {
            _progressTimer?.Cancel();
            _progressTimer = null;
        }

        public async Task PlayPauseAsync()
        {
            if (!IsAvailable || CurrentState == null) return;

            try
            {
                await ApiClient.SendCommandAsync(CurrentState.IsPlaying ? "pause" : "play");
                await RefreshStateAsync(_cts.Token);
            }
            catch { }
        }

        public async Task NextAsync()
        {
            if (!IsAvailable) return;

            try
            {
                await ApiClient.SendCommandAsync("next");
                await RefreshStateAsync(_cts.Token);
            }
            catch { }
        }

        public async Task PrevAsync()
        {
            if (!IsAvailable) return;

            try
            {
                await ApiClient.SendCommandAsync("previous");
                await RefreshStateAsync(_cts.Token);
            }
            catch { }
        }

        public async Task SeekAsync(int diff)
        {
            if (!IsAvailable) return;

            try
            {
                await ApiClient.SendCommandAsync($"sdiff_{diff}");
                await RefreshStateAsync(_cts.Token);
            }
            catch { }
        }

        public async Task AdjustVolumeAsync(double diff)
        {
            if (!IsAvailable) return;

            try
            {
                await ApiClient.SendCommandAsync($"vdiff_{diff}");
            }
            catch { }
        }

        public void Dispose()
        {
            _cts.Cancel();
            StopTimer();
            _wsClient.Dispose();
        }
    }
}
