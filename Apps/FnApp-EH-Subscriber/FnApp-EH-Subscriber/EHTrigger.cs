using System;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FnApp_EH_Subscriber
{
    public class EHTrigger
    {
        private readonly ILogger _logger;
        private TelemetryClient _telemetryClient;


        public EHTrigger(ILoggerFactory loggerFactory, TelemetryClient tc)
        {
            _logger = loggerFactory.CreateLogger<EHTrigger>();
            _telemetryClient = tc;

        }

        [Function("EHTrigger")]
        public void Run([EventHubTrigger("%EventHubName%", Connection = "EHConnectionString")] string[] input)
        {
            //Eventhub Messages arrive as an array
            foreach(var item in input)
            {
                string customeEvent = item;
                
                //Log Packet into EventHub
                _telemetryClient.TrackEvent(customeEvent);
            }
           

        }
    }
}
