// C# Interface template (Clean Architecture)
// Use: [NAMESPACE] = project namespace
// Use: [INTERFACE_NAME] = interface name

namespace [NAMESPACE]
{
    /// <summary>
    /// [INTERFACE_DESCRIPTION]
    /// </summary>
    public interface [INTERFACE_NAME]
    {
        #region Public Methods/Operators
        /// <summary>
        /// [METHOD_DESCRIPTION]
        /// </summary>
        /// <param name="[parameter]">[PARAMETER_DESCRIPTION]</param>
        /// <param name="cancellationToken">Cancellation token.</param>
        /// <returns>Task with [RETURN_TYPE_DESCRIPTION].</returns>
        Task<[RETURN_TYPE]> [MethodName]Async([PARAMETER_TYPE] [parameter], CancellationToken cancellationToken = default);
        #endregion
    }
}