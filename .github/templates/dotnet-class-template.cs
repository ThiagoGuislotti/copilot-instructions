// C# Class template following Clean Architecture
// Use: [Namespace] = project namespace
// Use: [ClassName] = class name
// Use: [InterfaceName] = implemented interface (optional)
// Use: [DependencyType] = injected dependency type
// Use: [CONSTANT_NAME] = constant name (e.g., MaxRetries)
// Use: [CONSTANT_VALUE] = constant value (e.g., "DefaultValue")
// Use: [CONSTANT_NAME_INT] = integer constant name (e.g., DefaultTimeout)
// Use: [CONSTANT_VALUE_INT] = integer constant value (e.g., 30)
// Use: [STATIC_VARIABLE_DESCRIPTION] = description for static variable
// Use: [StaticVariableName] = static variable name (e.g., GlobalConfig)
// Use: [STATIC_VARIABLE_VALUE] = static variable value (e.g., "config")
// Use: [StaticDependencyName] = static dependency variable name (e.g., service)
// Use: [STATIC_PROPERTY_DESCRIPTION] = description for static property
// Use: [StaticPropertyName] = static property name (e.g., CurrentUser)
// Use: [PropertyAccessor] = property accessor method (e.g., GetCurrentUser)
// Use: [PropertySetter] = property setter method (e.g., SetCurrentUser)
// Use: [StaticBooleanProperty] = static boolean property name (e.g., IsInitialized)

//#define HAS_INTERFACE   // <- Descomente se a classe implementar  [InterfaceName]

using System;
using System.ComponentModel.DataAnnotations;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace [Namespace]
{
    /// <summary>
    /// [CLASS_DESCRIPTION]
    /// </summary>
    /// <remarks>
    /// [ADDITIONAL_CLASS_INFORMATION]
    /// </remarks>
#if HAS_INTERFACE
    public class  [ClassName] : [InterfaceName]
#else
    public class  [ClassName]
#endif
    {
        #region Constants
        /// <summary>
        /// [CONSTANT_DESCRIPTION]
        /// </summary>
        public const string [CONSTANT_NAME] = "[CONSTANT_VALUE]";

        /// <summary>
        /// [CONSTANT_DESCRIPTION]
        /// </summary>
        public const int [CONSTANT_NAME_INT] = [CONSTANT_VALUE_INT];
        #endregion

        #region Static Variables
        /// <summary>
        /// [STATIC_VARIABLE_DESCRIPTION]
        /// </summary>
        public static readonly string [StaticVariableName] = "[STATIC_VARIABLE_VALUE]";

        /// <summary>
        /// [STATIC_VARIABLE_DESCRIPTION]
        /// </summary>
        private static readonly /* Avoid static singletons; prefer DI */ Lazy<[DependencyType]> _[StaticDependencyName] = new(() => new [DependencyType]());
        #endregion

        #region Static Properties
        /// <summary>
        /// [STATIC_PROPERTY_DESCRIPTION]
        /// </summary>
        public static string [StaticPropertyName]
        {
            get => _[StaticDependencyName].Value.[PropertyAccessor]();
            set => _[StaticDependencyName].Value.[PropertySetter](value);
        }

        /// <summary>
        /// [STATIC_PROPERTY_DESCRIPTION]
        /// </summary>
        public static bool [StaticBooleanProperty] { get; set; } = true;
        #endregion

        #region Variables
        /// <summary>
        /// [DEPENDENCY_DESCRIPTION]
        /// </summary>
        private readonly [DependencyType] _[DependencyName];

        /// <summary>
        /// Logger instance for this class.
        /// </summary>
        private readonly ILogger< [ClassName]> _logger;
        #endregion

        #region Protected Properties
        /// <summary>
        /// [BOOLEAN_COMPLETE_DESCRIPTION]
        /// </summary>
        protected bool [ProtectedProperty] { get; init; }
        #endregion

        #region Public Properties
        /// <summary>
        /// [PROPERTY_DESCRIPTION]
        /// </summary>
        public string [PropertyName]
        { get; set; } = string.Empty;

        /// <summary>
        /// [PROPERTY_DESCRIPTION]
        /// </summary>
        [Required]
        public int[AnotherProperty]
        { get; init; }
        #endregion

        #region Constructors
        /// <summary>
        /// Initializes a new instance of the <see cref="[ClassName]"/> class.
        /// </summary>
        /// <param name="[DependencyName]">[DEPENDENCY_DESCRIPTION]</param>
        /// <param name="logger">The logger instance for structured logging.</param>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[DependencyName]"/> or <paramref name="logger"/> is <c>null</c>.
        /// </exception>
        public [ClassName] ([DependencyType] [DependencyName], ILogger< [ClassName]> logger)
        {
            _[DependencyName] = [DependencyName] ?? throw new ArgumentNullException(nameof([DependencyName]));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }
        #endregion

        #region Public Methods/Operators
        #if HAS_INTERFACE
        /// <inheritdoc/> // Implements interface method documentation
        #else
        /// <summary>
        /// [MethodDescription]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <param name="cancellationToken">The cancellation token to cancel the operation.</param>
        /// <returns>
        /// A <see cref="Task{TResult}"/> representing the asynchronous operation.
        /// The task result contains [ReturnTypeDescription].
        /// </returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[ParameterName]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This method [METHOD_BEHAVIOR]. Uses ConfigureAwait(false) for library code.
        /// </remarks>
        #endif
        public async Task<[ReturnType]> [MethodName]Async([ParameterType] [ParameterName], CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull([ParameterName]);

            _logger.LogInformation("Starting {MethodName} with parameter: {Parameter}",
                nameof([MethodName]Async), [ParameterName]);

            var result = await _[DependencyName].[DependencyMethod]([ParameterName], cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Completed {MethodName} successfully", nameof([MethodName]Async));
            return result;
        }

        #if HAS_INTERFACE
        /// <inheritdoc/> // Implements interface method documentation
        #else
        /// <summary>
        /// [METHOD_DESCRIPTION_SYNC]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <returns>[ReturnTypeDescription]</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[ParameterName]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This method [METHOD_BEHAVIOR_SYNC].
        /// </remarks>
        #endif
        public [ReturnType][MethodName] ([ParameterType] [ParameterName])
                {
            ArgumentNullException.ThrowIfNull([ParameterName]);

            _logger.LogDebug("Executing synchronous {MethodName}", nameof([MethodName]));
            return _[DependencyName].[DependencyMethod]([ParameterName]);
        }

        /// <summary>
        /// [STATIC_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[ParameterName]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This static utility method [STATIC_METHOD_BEHAVIOR].
        /// </remarks>
        /// <example>
        /// <code>
        /// var result = [ClassName].[StaticMethod]("input");
        /// Console.WriteLine($"Static result: {result}");
        /// </code>
        /// </example>
        public static [ReturnType][StaticMethod] ([ParameterType] [ParameterName])
        {
            ArgumentNullException.ThrowIfNull([ParameterName]);

            // Static method implementation
            return default([ReturnType]);
        }
        #endregion

        #region Protected Methods/Operators
        /// <summary>
        /// [PROTECTED_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        protected virtual [ReturnType][ProtectedMethodName] ([ParameterType] [ParameterName])
                {
            // Implementation
            return default([ReturnType]);
        }
        #endregion

        #region Private Methods/Operators
        /// <summary>
        /// [PRIVATE_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        private [ReturnType] [PrivateMethodName]([ParameterType]  [ParameterName])
                {
            // Implementation
            return default([ReturnType]);
        }
        #endregion
    }
}