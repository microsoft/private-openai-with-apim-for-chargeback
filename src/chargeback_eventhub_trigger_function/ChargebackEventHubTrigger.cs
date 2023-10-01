using System;
using System.Collections.Generic;
using Azure.Messaging.EventHubs;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.ApplicationInsights;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace chargeback_eventhub_trigger
{
    public class ChargebackEventHubTrigger
    {
        private readonly ILogger _logger;
        private TelemetryClient _telemetryClient;


        public ChargebackEventHubTrigger(ILoggerFactory loggerFactory, TelemetryClient telemetryClient)
        {
            _logger = loggerFactory.CreateLogger<ChargebackEventHubTrigger>();
            _telemetryClient = telemetryClient;

        }

        [Function("ChargebackEventHubTrigger")]
        public async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnection")] string[] events)
        {
            var exceptions = new List<Exception>();

            //Eventhub Messages arrive as an array            
            foreach (var eventData in events)
            {
                try
                {
                    _telemetryClient.TrackEvent(eventData);
                }
                catch (Exception e)
                {
                    // We need to keep processing the rest of the batch - capture this exception and continue.
                    // Also, consider capturing details of the message that failed processing so it can be processed again later.
                    exceptions.Add(e);
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();

            await Task.FromResult(true);


        }
    }
}
