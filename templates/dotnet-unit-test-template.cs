#if !IMPLICIT_USINGS
using System;
using System.Threading;
using System.Threading.Tasks;
#if UNIT_XUNIT
using Xunit;
using Xunit.Abstractions;
#elif UNIT_NUNIT
using NUnit.Framework;
#endif
#endif

// .NET Unit Test template (xUnit or NUnit in a single file)
// Toggle the framework here:
//#define UNIT_XUNIT
//#define UNIT_NUNIT
// Parameterization guidance:
// - xUnit: prefer [Theory] + [InlineData] for simple constant datasets; use [MemberData] for larger/non-constant datasets.
// - NUnit: prefer [TestCase] for simple constant datasets; use [TestCaseSource] for larger/non-constant datasets.

// Use: [Namespace] = Project namespace
// Use: [TEST_CLASS] = ClassUnderTestTests
// Use: [MethodUnderTest] = CreateMotorcycle
// Use: [Category] = Commands/Queries/Services/Validators
// Use: [Entity] = Motorcycle (or similar)
// Use: [DependencyType] = Subject-under-test or Validator/Service/etc.

namespace [Namespace].UnitTests.Tests.[Category]
{
#if UNIT_XUNIT
    [Trait("[Category]", "[Entity]")]
#elif UNIT_NUNIT
    [TestFixture]
    [Category("[Category]")]
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
        private readonly [DependencyType] _[DependencyName];
        private readonly ITestOutputHelper _output;
#elif UNIT_NUNIT
        private [DependencyType] _[DependencyName];
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
            _[DependencyName] = new [DependencyType]();
        }
#elif UNIT_NUNIT
        /// <summary>
        /// NUnit uses [SetUp] and TestContext for logs.
        /// </summary>
        [SetUp]
        public void SetUp()
        {
            _[DependencyName] = new [DependencyType]();
        }
#endif
        #endregion

        #region Test Methods - [MethodUnderTest] Valid Cases
#if UNIT_XUNIT
        [Theory]
        [InlineData([ValidParameters])]
        [InlineData([OtherValidParameters])]
        public void [MethodUnderTest]_ValidData_ShouldBeValid([MethodParameters])
#elif UNIT_NUNIT
        [Test]
        [TestCase([ValidParameters])]
        [TestCase([OtherValidParameters])]
        public void [MethodUnderTest]_ValidData_ShouldBeValid([MethodParameters])
#endif
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                [Property] = [value],
                // ... other properties
            };

            // Act
            var result = _[DependencyName].[MethodUnderTest](request);

            // Assert
#if UNIT_XUNIT
            Assert.True(result.IsValid);
#elif UNIT_NUNIT
            Assert.That(result.IsValid, Is.True);
#endif
        }
        #endregion

        #region Test Methods - [MethodUnderTest] Invalid Cases
#if UNIT_XUNIT
        [Theory]
        [InlineData([InvalidParameters])]
        [InlineData([OTHER_INVALID_PARAMETERS])]
        public void [MethodUnderTest]_InvalidData_ShouldBeInvalid([MethodParameters])
#elif UNIT_NUNIT
        [Test]
        [TestCase([InvalidParameters])]
        [TestCase([OTHER_INVALID_PARAMETERS])]
        public void [MethodUnderTest]_InvalidData_ShouldBeInvalid([MethodParameters])
#endif
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                [Property] = [invalidValue],
                // ... other properties
            };

            // Act
            var result = _[DependencyName].[MethodUnderTest](request);

            // Assert + Output
#if UNIT_XUNIT
            Assert.False(result.IsValid);
            Assert.Contains(result.Errors, e => e.PropertyName == "[Property]");
#elif UNIT_NUNIT
            Assert.That(result.IsValid, Is.False);
            Assert.That(result.Errors, Has.Some.Property("PropertyName").EqualTo("[Property]"));
#endif

#if UNIT_XUNIT
            _output.WriteLine(result.ToString());
#elif UNIT_NUNIT
            TestContext.WriteLine(result.ToString());
#endif
        }
        #endregion

        #region Test Methods - [MethodUnderTest] Edge Cases
#if UNIT_XUNIT
        [Fact]
#elif UNIT_NUNIT
        [Test]
#endif
        public void [MethodUnderTest]_EdgeCase_ShouldHandleCorrectly()
        {
            // Arrange
            var request = new [REQUEST_TYPE]
            {
                // Configure edge case
            };

            // Act
            var result = _[DependencyName].[MethodUnderTest](request);

            // Assert
#if UNIT_XUNIT
            Assert.NotNull(result);
#elif UNIT_NUNIT
            Assert.That(result, Is.Not.Null);
#endif
        }
        #endregion

        #region Test Methods - [MethodUnderTest] Exception Cases
#if UNIT_XUNIT
        [Fact]
#elif UNIT_NUNIT
        [Test]
#endif
        public void [MethodUnderTest]_NullInput_ShouldThrowException()
        {
            // Arrange
            [REQUEST_TYPE] request = null;

            // Act & Assert
#if UNIT_XUNIT
            var ex = Assert.Throws<ArgumentNullException>(() => _[DependencyName].[MethodUnderTest](request));
            Assert.Equal("request", ex.ParamName);
#elif UNIT_NUNIT
            var ex = Assert.Throws<ArgumentNullException>(() => _[DependencyName].[MethodUnderTest](request));
            Assert.That(ex.ParamName, Is.EqualTo("request"));
#endif
        }
        #endregion
    }
}