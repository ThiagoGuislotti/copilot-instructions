using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace [Namespace]
{
    /// <summary>
    /// [BACKGROUND_SERVICE_DESCRIPTION]
    /// </summary>
    public sealed class [ServiceName] : BackgroundService
    {
        #region Variables
        private static readonly TimeSpan _loopDelay = TimeSpan.FromSeconds([LoopDelaySeconds]);
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<[ServiceName]> _logger;
        #endregion

        #region Constructors
        /// <summary>
        /// Initializes a new instance of the <see cref="[ServiceName]"/> class.
        /// </summary>
        /// <param name="serviceProvider">Service provider used to resolve scoped dependencies.</param>
        /// <param name="logger">Structured logger instance.</param>
        /// <exception cref="ArgumentNullException">Thrown when dependencies are null.</exception>
        public [ServiceName](IServiceProvider serviceProvider, ILogger<[ServiceName]> logger)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }
        #endregion

        #region Protected Methods/Operators
        /// <summary>
        /// Executes background work loop.
        /// </summary>
        /// <param name="stoppingToken">Cancellation token used to stop processing gracefully.</param>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("{ServiceName} started.", nameof([ServiceName]));

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    var handler = scope.ServiceProvider.GetRequiredService<[ScopedDependencyInterface]>();

                    await handler.[WorkMethodName]Async(stoppingToken).ConfigureAwait(false);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    // Graceful shutdown path.
                }
                catch (Exception exception)
                {
                    _logger.LogError(exception, "{ServiceName} iteration failed.", nameof([ServiceName]));
                }

                await Task.Delay(_loopDelay, stoppingToken).ConfigureAwait(false);
            }
        }

        /// <summary>
        /// Called when host starts the service.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token.</param>
        public override Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("{ServiceName} starting.", nameof([ServiceName]));
            return base.StartAsync(cancellationToken);
        }

        /// <summary>
        /// Called when host stops the service.
        /// </summary>
        /// <param name="cancellationToken">Cancellation token.</param>
        public override Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("{ServiceName} stopping.", nameof([ServiceName]));
            return base.StopAsync(cancellationToken);
        }
        #endregion
    }
}