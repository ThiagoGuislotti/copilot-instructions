#if !IMPLICIT_USINGS
using System.Threading;
using System.Threading.Tasks;
#endif
// C# Interface template (Clean Architecture)
// Use: [Namespace] = project namespace
// Use: [InterfaceName] = interface name

namespace [Namespace]
{
    /// <summary>
    /// [InterfaceDescription]
    /// </summary>
    public interface [InterfaceName]
    {
        #region Public Methods/Operators
        /// <summary>
        /// [MethodDescription]
        /// </summary>
        /// <param name="[ParameterName]">[ParameterDescription]</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>Task with [ReturnTypeDescription].</returns>
        Task<[ReturnType]> [MethodName]Async([ParameterType] [ParameterName], CancellationToken cancellationToken = default);
        #endregion
    }
}