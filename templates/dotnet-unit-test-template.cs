// .NET Unit Test template (xUnit or NUnit in a single file)
// Toggle the framework here:
//#define UNIT_XUNIT
//#define UNIT_NUNIT

// Use: [NAMESPACE] = Project namespace
// Use: [TEST_CLASS] = ClassUnderTestTests
// Use: [METHOD_UNDER_TEST] = CreateMotorcycle
// Use: [CATEGORY] = Commands/Queries/Services/Validators
// Use: [ENTITY] = Motorcycle (or similar)
// Use: [DEPENDENCY_TYPE] = Subject-under-test or Validator/Service/etc.

namespace [NAMESPACE].UnitTests.Tests.[CATEGORY]
{
#if UNIT_XUNIT
    [Trait("[CATEGORY]", "[ENTITY]")]
#elif UNIT_NUNIT
    [TestFixture]
    [Category("[CATEGORY]")]
#endif
    public class [TEST_CLASS]
    {
        #region Nested types
        private sealed class Dto
        {
            public string? Name { get; set; }
        }
        #endregion

        #region Variables
#if UNIT_XUNIT
        private readonly [DEPENDENCY_TYPE] _[dependencyName];
        private readonly ITestOutputHelper _output;
#elif UNIT_NUNIT
        private [DEPENDENCY_TYPE] _[dependencyName];
#endif
        #endregion

        #region SetUp Methods
#if UNIT_XUNIT
        /// <summary>
        /// xUnit uses constructor for per-test setup and ITestOutputHelper for logs.
        /// </summary>
        public [TEST_CLASS] (ITestOutputHelper output)
        {
            _output = output;
            _[dependencyName] = new [DEPENDENCY_TYPE]();
        }
#elif UNIT_NUNIT
        /// <summary>
        /// NUnit uses [SetUp] and TestContext for logs.
        /// </summary>
        [SetUp]
        public void SetUp()
        {
            _[dependencyName] = new [DEPENDENCY_TYPE]();
        }
#endif
        #endregion

        #region Test Methods - [METHOD_UNDER_TEST] Valid Cases
#if UNIT_XUNIT
        [Theory]
        [InlineData([VALID_PARAMETERS])]
        [InlineData([OTHER_VALID_PARAMETERS])]
        public void [METHOD_UNDER_TEST]_ValidData_ShouldBeValid([METHOD_PARAMETERS])
#elif UNIT_NUNIT
        [Test]
        [TestCase([VALID_PARAMETERS])]
        [TestCase([OTHER_VALID_PARAMETERS])]
        public void [METHOD_UNDER_TEST]_ValidData_ShouldBeValid([METHOD_PARAMETERS])
#endif
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                [PROPERTY] = [value],
                // ... other properties
            };

            // Act
            var result = _[dependencyName].[METHOD_UNDER_TEST](request);

            // Assert
            result.IsValid.Should().BeTrue();
        }
        #endregion

        #region Test Methods - [METHOD_UNDER_TEST] Invalid Cases
#if UNIT_XUNIT
        [Theory]
        [InlineData([INVALID_PARAMETERS])]
        [InlineData([OTHER_INVALID_PARAMETERS])]
        public void [METHOD_UNDER_TEST]_InvalidData_ShouldBeInvalid([METHOD_PARAMETERS])
#elif UNIT_NUNIT
        [Test]
        [TestCase([INVALID_PARAMETERS])]
        [TestCase([OTHER_INVALID_PARAMETERS])]
        public void [METHOD_UNDER_TEST]_InvalidData_ShouldBeInvalid([METHOD_PARAMETERS])
#endif
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                [PROPERTY] = [invalidValue],
                // ... other properties
            };

            // Act
            var result = _[dependencyName].[METHOD_UNDER_TEST](request);

            // Assert + Output
            result.IsValid.Should().BeFalse();
            result.Errors.Should().Contain(e => e.PropertyName == "[PROPERTY]");

#if UNIT_XUNIT
            _output.WriteLine(result.ToString());
#elif UNIT_NUNIT
            TestContext.WriteLine(result.ToString());
#endif
        }
        #endregion

        #region Test Methods - [METHOD_UNDER_TEST] Edge Cases
#if UNIT_XUNIT
        [Fact]
#elif UNIT_NUNIT
        [Test]
#endif
        public void [METHOD_UNDER_TEST]_EdgeCase_ShouldHandleCorrectly()
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                // Configure edge case
            };

            // Act
            var result = _[dependencyName].[METHOD_UNDER_TEST](request);

            // Assert
            result.Should().NotBeNull();
        }
        #endregion

        #region Test Methods - [METHOD_UNDER_TEST] Exception Cases
#if UNIT_XUNIT
        [Fact]
#elif UNIT_NUNIT
        [Test]
#endif
        public void [METHOD_UNDER_TEST]_NullInput_ShouldThrowException()
        {
            // Arrange
            [REQUEST_TYPE] request = null;

            // Act & Assert
#if UNIT_XUNIT
            var ex = Assert.Throws<ArgumentNullException>(() => _[dependencyName].[METHOD_UNDER_TEST](request));
            ex.ParamName.Should().Be("request");
#elif UNIT_NUNIT
            Assert.Throws<ArgumentNullException>(() => _[dependencyName].[METHOD_UNDER_TEST](request));
#endif
        }
        #endregion
    }
}