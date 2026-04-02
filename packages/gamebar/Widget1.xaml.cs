using System;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Newtonsoft.Json;
using Windows.UI.Xaml.Media.Imaging;

namespace gamebar
{
    /// <summary>
    /// The page for the widget. Called Widget1 because I can't remember
    /// </summary>
    public sealed partial class Widget1 : Page
    {
        private bool isPlaying = false;
        private WsClient wsClient;
        private DispatcherTimer _progressTimer;

        public Widget1()
        {
            this.InitializeComponent();
            Loaded += Widget1_Loaded;
        }

        private async void Widget1_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                var json = await ApiClient.GetStateAsync();
                var state = JsonConvert.DeserializeObject<PlayerState>(json);
                ApplyState(state);

                wsClient = new WsClient();
                wsClient.StateReceived += s =>
                {
                    _ = Dispatcher.RunAsync(Windows.UI.Core.CoreDispatcherPriority.Normal, () =>
                    {
                        ApplyState(s);
                    });
                };
                wsClient.SeekReceived += o =>
                {
                    _ = Dispatcher.RunAsync(Windows.UI.Core.CoreDispatcherPriority.Normal, () =>
                    {
                        ProgressBar.Value = o.Position;
                    });
                };

                wsClient.IsPlayingReceived += b =>
                {
                    _ = Dispatcher.RunAsync(Windows.UI.Core.CoreDispatcherPriority.Normal, () =>
                    {
                        isPlaying = b;
                        PlayPauseButton.Content = isPlaying ? "D" : "B";
                    });
                };

                wsClient.ConnectWebSocket();

                StartProgressTimer();
            }
            catch
            {

            }
        }

        private void ApplyState(PlayerState state)
        {
            isPlaying = state.IsPlaying;
            PlayPauseButton.Content = isPlaying ? "D" : "B";

            SetAlbumArt(state.AlbumUrl);

            SongTitle.Text = state.Title;
            Artist.Text = state.Artist;

            ProgressBar.Maximum = state.Duration;
            ProgressBar.Value = state.Position;
        }

        private void SetAlbumArt(string albumArtUrl)
        {
            AlbumArt.Source = new BitmapImage(new Uri(albumArtUrl));
        }

        private async void PrevButton_Click(object sender, RoutedEventArgs e)
        {
            isPlaying = true;
            await ApiClient.SendCommandAsync("previous");
        }

        private async void PlayPauseButton_Click(object sender, RoutedEventArgs e)
        {
            isPlaying = !isPlaying;
            PlayPauseButton.Content = isPlaying ? "D" : "B";

            await ApiClient.SendCommandAsync(isPlaying ? "play" : "pause");
        }

        private async void NextButton_Click(object sender, RoutedEventArgs e)
        {
            isPlaying = true;
            await ApiClient.SendCommandAsync("next");
        }

        private void StartProgressTimer()
        {
            if (_progressTimer != null) return;

            _progressTimer = new DispatcherTimer()
            {
                Interval = TimeSpan.FromSeconds(1)
            };
            _progressTimer.Tick += (s, e) =>
            {
                if (isPlaying && ProgressBar.Value < ProgressBar.Maximum)
                {
                    ProgressBar.Value += 1;
                }
            };
            _progressTimer.Start();
        }
    }
}
