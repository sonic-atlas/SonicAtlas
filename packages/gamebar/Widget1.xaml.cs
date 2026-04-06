using System;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Media.Imaging;
using Windows.UI.Core;
using System.Threading.Tasks;
using Windows.UI.Xaml.Navigation;
using System.Threading;
using Windows.UI.Xaml.Media.Animation;
using Windows.UI.Xaml.Input;
using Microsoft.Gaming.XboxGameBar;

namespace gamebar
{
    /// <summary>
    /// The page for the widget. Called Widget1 because I can't remember
    /// </summary>
    public sealed partial class Widget1 : Page
    {
        private readonly PlayerController _controller = new PlayerController();
        private XboxGameBarWidget _widget;

        public Widget1()
        {
            this.InitializeComponent();

            Loaded += Widget1_Loaded;
            Unloaded += Widget1_Unloaded;
            Window.Current.VisibilityChanged += Widget1_VisibilityChanged;
            Application.Current.Resuming += App_Resuming;
        }

        private async void Widget1_Loaded(object sender, RoutedEventArgs e)
        {
            _controller.StateUpdated += OnStateUpdated;
            _controller.ProgressUpdated += OnProgressUpdated;
            _controller.AvailabilityChanged += OnAvailabilityChanged;

            await _controller.InitialiseAsync();
        }

        private void Widget1_Unloaded(object sender, RoutedEventArgs e)
        {
            _controller.StateUpdated -= OnStateUpdated;
            _controller.ProgressUpdated -= OnProgressUpdated;
            _controller.Dispose();
        }

        private async void Widget1_VisibilityChanged(object sender, VisibilityChangedEventArgs e)
        {
            if (e.Visible)
            {
                await _controller.RefreshStateAsync(CancellationToken.None);
            }
        }

        private async void App_Resuming(object sender, object e)
        {
            await _controller.RefreshStateAsync(CancellationToken.None);
        }

        protected override async void OnNavigatedTo(NavigationEventArgs e)
        {
            base.OnNavigatedTo(e);
            _widget = e.Parameter as XboxGameBarWidget;

            if (_widget != null)
            {
                _widget.PinnedChanged += Widget1_PinnedChanged;

                await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
                {
                    UpdateVisualState(_widget.Pinned);
                });
            }

            await _controller.RefreshStateAsync(CancellationToken.None);
        }

        private async void Widget1_PinnedChanged(XboxGameBarWidget sender, object args)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                UpdateVisualState(sender.Pinned);
            });

            if (sender.Pinned)
            {
                await sender.TryResizeWindowAsync(new Windows.Foundation.Size(244, 84));
            }
            else
            {
                await sender.TryResizeWindowAsync(new Windows.Foundation.Size(300, 320));
            }
        }

        private async void OnStateUpdated(PlayerState state)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                PlayPauseButton.Content = state.IsPlaying ? "D" : "B";
                SongTitle.Text = state.Title;
                Artist.Text = state.Artist;

                ProgressBar.Maximum = state.Duration;
                ProgressBar.Value = state.Position;

                MiniProgressBar.Maximum = state.Duration;
                MiniProgressBar.Value = state.Position;

                NextButton.IsEnabled = state.HasNext;
                PrevButton.IsEnabled = state.HasPrev;

                AlbumArt.Source = new BitmapImage(new Uri(state.AlbumUrl));
            });
        }

        // TODO: On next/prev set to 0 and keep at 0 until song start
        private async void OnProgressUpdated(double value)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                ProgressBar.Value = value;
                MiniProgressBar.Value = value;
            });
        }

        private async void OnAvailabilityChanged(bool available)
        {
            await SetOverlayVisible(!available);
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                OfflineOverlay.Visibility = available ? Visibility.Collapsed : Visibility.Visible;
            });
        }

        private async Task SetOverlayVisible(bool visible)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                OfflineOverlay.IsHitTestVisible = visible;

                var animation = new DoubleAnimation
                {
                    To = visible ? 1 : 0,
                    Duration = new Duration(TimeSpan.FromMilliseconds(250))
                };

                var storyboard = new Storyboard();
                storyboard.Children.Add(animation);

                Storyboard.SetTarget(animation, OfflineOverlay);
                Storyboard.SetTargetProperty(animation, "Opacity");

                storyboard.Begin();
            });
        }

        private async void RetryButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await _controller.RefreshStateAsync(CancellationToken.None);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine(ex);
            }
        }

        private async void PlayPauseButton_Click(object sender, RoutedEventArgs e)
        {
            await _controller.RefreshStateAsync(CancellationToken.None);
            await _controller.PlayPauseAsync();
        }

        private async void NextButton_Click(object sender, RoutedEventArgs e)
            => await _controller.NextAsync();

        private async void PrevButton_Click(object sender, RoutedEventArgs e)
            => await _controller.PrevAsync();

        private async void OnPointerWheelChanged(object sender, PointerRoutedEventArgs e)
        {
            var delta = e.GetCurrentPoint(null).Properties.MouseWheelDelta;
            var ctrl = Window.Current.CoreWindow.GetKeyState(Windows.System.VirtualKey.Control);

            if (ctrl.HasFlag(CoreVirtualKeyStates.Down))
            {
                await _controller.SeekAsync(delta > 0 ? +5 : -5);
            }
            else
            {
                await _controller.AdjustVolumeAsync(delta > 0 ? +0.02 : -0.02);
            }
        }

        private void UpdateVisualState(bool isPinned)
        {
            VisualStateManager.GoToState(this, isPinned ? "Pinned" : "Unpinned", true);
        }

        private async void InteractionLayer_Tapped(object sender, TappedRoutedEventArgs e)
        {
            var pos = e.GetPosition(RootGrid).X;
            var width = RootGrid.ActualWidth;

            if (pos < width * 0.33)
            {
                await _controller.PrevAsync();
            }
            else if (pos > width * 0.66)
            {
                await _controller.NextAsync();
            }
            else
            {
                await _controller.PlayPauseAsync();
            }
        }
    }
}
