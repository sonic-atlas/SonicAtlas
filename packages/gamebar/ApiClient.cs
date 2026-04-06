using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;

namespace gamebar
{
    internal static class ApiClient
    {
        private static readonly Uri BaseUri = new Uri("http://127.0.0.1:39393/");
        private static readonly HttpClient client = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(2)
        };

        static ApiClient()
        {
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
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
            var content = new StringContent(json, UnicodeEncoding.UTF8, "application/json");

            var response = await client.PostAsync(new Uri(BaseUri, endpoint), content);
            response.EnsureSuccessStatusCode();
        }

        public static async Task<bool> IsServerAlive()
        {
            try
            {
                var response = await client.GetAsync(new Uri(BaseUri, "ping"));
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }
    }
}
