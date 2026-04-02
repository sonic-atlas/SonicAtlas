using System;
using System.Threading.Tasks;
using Windows.Web.Http;
using Windows.Web.Http.Headers;

namespace gamebar
{
    internal static class ApiClient
    {
        private static readonly Uri BaseUri = new Uri("http://127.0.0.1:39393/");
        private static readonly HttpClient client = new HttpClient();

        static ApiClient()
        {
            client.DefaultRequestHeaders.Accept.Add(new HttpMediaTypeWithQualityHeaderValue("application/json"));
        }

        public static async Task<string> GetStateAsync()
        {
            var response = await client.GetAsync(new Uri(BaseUri, "state"));
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }

        public static async Task SendCommandAsync(string endpoint, string command = "")
        {
            var json = $"{{\"action\":\"{command}\"}}";
            var content = new HttpStringContent(json, Windows.Storage.Streams.UnicodeEncoding.Utf8, "application/json");

            var response = await client.PostAsync(new Uri(BaseUri, endpoint), content);
            response.EnsureSuccessStatusCode();
        }
    }
}
