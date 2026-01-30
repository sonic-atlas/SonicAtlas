namespace gamebar
{
    internal class PlayerState
    {
        public bool IsPlaying { get; set; }
        public string Title { get; set; }
        public string Artist { get; set; }
        public double Position { get; set; }
        public double Duration { get; set; }
        public string AlbumUrl { get; set; }
    }

    internal class SeekWebSocketObject
    {
        public double Position { get; set; }
    }
}
