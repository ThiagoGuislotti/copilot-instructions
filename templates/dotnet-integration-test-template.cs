#if !IMPLICIT_USINGS
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using NUnit.Framework;
#endif
using MediatR;
using Microsoft.Extensions.DependencyInjection;

// .NET Integration Test template (NUnit)
// Use: [HandlerClass] = MotorcycleHandlerTest
// Use: [Entity] = Motorcycle
// Use: [MethodUnderTest] = CRUD/Business Rules/Business Rules
// Use: [Category] = Commands/Queries/Services

using [Namespace].Application.Cqrs.Commands;
using [Namespace].Application.Cqrs.Queries;
using [Namespace].IntegrationTests.Assets;

namespace [Namespace].IntegrationTests.Tests.[Category]
{
    [TestFixture]
    [RequiresThread]
    [SetCulture("pt-BR")]
    [Category("[Category]")]
    public class [HandlerClass]
    {
        #region Nested types
        private sealed class Dto
        {
            public string? Name { get; set; }
        }
        #endregion

        #region Variables
        private ConfigureServices _configureServices;
        private IMediator _mediator;
        private string _testEntityId;
        #endregion

        #region SetUp Methods
        [SetUp]
        public void SetUp()
        {
            _configureServices = new ConfigureServices();
            _mediator = _configureServices.ServiceProvider.GetRequiredService<IMediator>();
            _testEntityId = $"test-{Guid.NewGuid():N}";
        }

        [TearDown]
        public async Task TearDown()
        {
            // Cleanup: remove test data if necessary
            try
            {
                var deleteCommand = new Delete[Entity]Command { Id = _testEntityId };
                await _mediator.Send(deleteCommand).ConfigureAwait(false);
            }
            catch
            {
                // Ignore cleanup errors
            }
        }
        #endregion

        #region Test Methods - [MethodUnderTest]
        [Test]
        [Order(1)]
        public async Task Create_[Entity]_ReturnSuccess()
        {
            // Arrange
            var command = new Create[Entity]Command
            {
                Id = _testEntityId,
                // Configure required properties
                [Property] = "[TestValue]",
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.IsSuccess.Should().BeTrue();
            result.Data.Should().NotBeNull();
        }

        [Test]
        [Order(2)]
        public async Task Update_[Entity]_ReturnSuccess()
        {
            // Arrange
            await CreateTestEntity();
            var command = new Update[Entity]Command
            {
                Id = _testEntityId,
                // Properties for update
                [Property] = "[NEW_VALUE]",
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.IsSuccess.Should().BeTrue();
        }

        [Test]
        [Order(3)]
        public async Task GetById_[Entity]_ReturnEntity()
        {
            // Arrange
            await CreateTestEntity();
            var query = new [Entity]Query
            {
                Id = _testEntityId,
            };

            // Act
            var result = await _mediator.Send(query).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.Should().HaveCount(1);
            result.First().Id.Should().Be(_testEntityId);
        }

        [Test]
        [Order(4)]
        public async Task GetAll_[Entity]_ReturnList()
        {
            // Arrange
            await CreateTestEntity();
            var query = new [Entity]Query();

            // Act
            var result = await _mediator.Send(query).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.Should().NotBeEmpty();
            result.Should().Contain(x => x.Id == _testEntityId);
        }

        [Test]
        [Order(5)]
        public async Task Delete_[Entity]_ReturnSuccess()
        {
            // Arrange
            await CreateTestEntity();
            var command = new Delete[Entity]Command
            {
                Id = _testEntityId,
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.IsSuccess.Should().BeTrue();
        }
        #endregion

        #region Test Methods - [MethodUnderTest]
        [Test]
        public async Task Create_[Entity]_WithInvalidData_ShouldFail()
        {
            // Arrange
            var command = new Create[Entity]Command
            {
                Id = _testEntityId,
                // Invalid data to test validation
                [Property] = "", // Invalid value
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);

            // Assert
            result.IsSuccess.Should().BeFalse();
            result.Errors.Should().NotBeEmpty();
        }

        [Test]
        public async Task Create_[Entity]_WithDuplicateId_ShouldFail()
        {
            // Arrange
            await CreateTestEntity();
            var duplicateCommand = new Create[Entity]Command
            {
                Id = _testEntityId, // Same ID
                [Property] = "[TestValue]",
            };

            // Act
            var result = await _mediator.Send(duplicateCommand).ConfigureAwait(false);

            // Assert
            result.IsSuccess.Should().BeFalse();
            result.Errors.Should().Contain(e => e.Contains("duplicate") || e.Contains("exists"));
        }
        #endregion

        #region Test Methods - [MethodUnderTest]
        [Test]
        [Category("Performance")]
        public async Task GetAll_[Entity]_WithLargeDataset_ShouldComplete()
        {
            // Arrange
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            var query = new [Entity]Query();

            // Act
            var result = await _mediator.Send(query).ConfigureAwait(false);
            stopwatch.Stop();

            // Assert
            result.Should().NotBeNull();
            stopwatch.ElapsedMilliseconds.Should().BeLessThan(5000); // 5 seconds max
            ConsoleLogger.WriteLine($"Query executed in {stopwatch.ElapsedMilliseconds}ms");
        }
        #endregion

        #region Private Methods/Operators
        private async Task CreateTestEntity()
        {
            var command = new Create[Entity]Command
            {
                Id = _testEntityId,
                [Property] = "[TestValue]",
                // Other required properties
            };

            var result = await _mediator.Send(command).ConfigureAwait(false);
            result.IsSuccess.Should().BeTrue("Setup entity creation should succeed");
        }
        #endregion
    }
}