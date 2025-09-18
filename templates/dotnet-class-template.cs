// C# Class template following Clean Architecture
// Use: [NAMESPACE] = project namespace
// Use: [CLASS_NAME] = class name
// Use: [INTERFACE_NAME] = implemented interface (optional)
// Use: [DEPENDENCY_TYPE] = injected dependency type
// Use: [CONSTANT_NAME] = constant name (e.g., MaxRetries)
// Use: [CONSTANT_VALUE] = constant value (e.g., "DefaultValue")
// Use: [CONSTANT_NAME_INT] = integer constant name (e.g., DefaultTimeout)
// Use: [CONSTANT_VALUE_INT] = integer constant value (e.g., 30)
// Use: [STATIC_VARIABLE_DESCRIPTION] = description for static variable
// Use: [StaticVariableName] = static variable name (e.g., GlobalConfig)
// Use: [STATIC_VARIABLE_VALUE] = static variable value (e.g., "config")
// Use: [staticDependencyName] = static dependency variable name (e.g., service)
// Use: [STATIC_PROPERTY_DESCRIPTION] = description for static property
// Use: [StaticPropertyName] = static property name (e.g., CurrentUser)
// Use: [PropertyAccessor] = property accessor method (e.g., GetCurrentUser)
// Use: [PropertySetter] = property setter method (e.g., SetCurrentUser)
// Use: [StaticBooleanProperty] = static boolean property name (e.g., IsInitialized)

//#define HAS_INTERFACE   // <- Descomente se a classe implementar [INTERFACE_NAME]

using System;
using System.ComponentModel.DataAnnotations;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace [NAMESPACE]
{
    /// <summary>
    /// [CLASS_DESCRIPTION]
    /// </summary>
    /// <remarks>
    /// [ADDITIONAL_CLASS_INFORMATION]
    /// </remarks>
#if HAS_INTERFACE
    public class [CLASS_NAME] : [INTERFACE_NAME]
#else
    public class [CLASS_NAME]
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
        private static readonly Lazy<[DEPENDENCY_TYPE]> _[staticDependencyName] = new(() => new [DEPENDENCY_TYPE]());
        #endregion

        #region Static Properties
        /// <summary>
        /// [STATIC_PROPERTY_DESCRIPTION]
        /// </summary>
        public static string [StaticPropertyName]
        {
            get => _[staticDependencyName].Value.[PropertyAccessor]();
            set => _[staticDependencyName].Value.[PropertySetter](value);
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
        private readonly [DEPENDENCY_TYPE] _[dependencyName];

        /// <summary>
        /// Logger instance for this class.
        /// </summary>
        private readonly ILogger<[CLASS_NAME]> _logger;
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
        public string[PropertyName]
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
        /// Initializes a new instance of the <see cref="[CLASS_NAME]"/> class.
        /// </summary>
        /// <param name="[dependencyName]">[DEPENDENCY_DESCRIPTION]</param>
        /// <param name="logger">The logger instance for structured logging.</param>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[dependencyName]"/> or <paramref name="logger"/> is <c>null</c>.
        /// </exception>
        public [CLASS_NAME] ([DEPENDENCY_TYPE] [dependencyName], ILogger<[CLASS_NAME]> logger)
        {
            _[dependencyName] = [dependencyName] ?? throw new ArgumentNullException(nameof([dependencyName]));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }
        #endregion

        #region Public Methods/Operators

        #if HAS_INTERFACE
        /// <inheritdoc/> // Implements interface method documentation
        #else
        /// <summary>
        /// [METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <param name="cancellationToken">The cancellation token to cancel the operation.</param>
        /// <returns>
        /// A <see cref="Task{TResult}"/> representing the asynchronous operation.
        /// The task result contains [RETURN_TYPE_DESCRIPTION].
        /// </returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[parameter]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This method [METHOD_BEHAVIOR]. Uses ConfigureAwait(false) for library code.
        /// </remarks>
        #endif
        public async Task<[RETURN_TYPE]> [MethodName] Async([PARAMETER_TYPE][parameter], CancellationToken cancellationToken = default)
        {
            ArgumentNullException.ThrowIfNull([parameter]);

            _logger.LogInformation("Starting {MethodName} with parameter: {Parameter}",
                nameof([MethodName]Async), [parameter]);

            var result = await _[dependencyName].[DependencyMethod]([parameter], cancellationToken).ConfigureAwait(false);

            _logger.LogInformation("Completed {MethodName} successfully", nameof([MethodName]Async));
            return result;
        }

        #if HAS_INTERFACE
                /// <inheritdoc/> // Implements interface method documentation
        #else
        /// <summary>
        /// [METHOD_DESCRIPTION_SYNC]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <returns>[RETURN_TYPE_DESCRIPTION]</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[parameter]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This method [METHOD_BEHAVIOR_SYNC].
        /// </remarks>
        #endif
        public [RETURN_TYPE][MethodName] ([PARAMETER_TYPE][parameter])
                {
            ArgumentNullException.ThrowIfNull([parameter]);

            _logger.LogDebug("Executing synchronous {MethodName}", nameof([MethodName]));
            return _[dependencyName].[DependencyMethod]([parameter]);
        }

        /// <summary>
        /// [STATIC_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        /// <exception cref="ArgumentNullException">
        /// Thrown when <paramref name="[parameter]"/> is <c>null</c>.
        /// </exception>
        /// <remarks>
        /// This static utility method [STATIC_METHOD_BEHAVIOR].
        /// </remarks>
        /// <example>
        /// <code>
        /// var result = [CLASS_NAME].[StaticMethod]("input");
        /// Console.WriteLine($"Static result: {result}");
        /// </code>
        /// </example>
        public static [RETURN_TYPE][StaticMethod] ([PARAMETER_TYPE][parameter])
        {
            ArgumentNullException.ThrowIfNull([parameter]);

            // Static method implementation
            return default([RETURN_TYPE]);
        }
        #endregion

        #region Protected Methods/Operators
        /// <summary>
        /// [PROTECTED_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        protected virtual [RETURN_TYPE][ProtectedMethodName] ([PARAMETER_TYPE][parameter])
                {
            // Implementation
            return default([RETURN_TYPE]);
        }
        #endregion

        #region Private Methods/Operators
        /// <summary>
        /// [PRIVATE_METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <returns>[RETURN_DESCRIPTION]</returns>
        private [RETURN_TYPE][PrivateMethodName] ([PARAMETER_TYPE][parameter])
                {
            // Implementation
            return default([RETURN_TYPE]);
        }
        #endregion
    }
}