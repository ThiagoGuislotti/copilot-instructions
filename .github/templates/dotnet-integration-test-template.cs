// .NET Integration Test template (NUnit)
// Use: [HANDLER_CLASS] = MotorcycleHandlerTest
// Use: [ENTITY] = Motorcycle
// Use: [CATEGORY] = Commands/Queries/Services

using FluentAssertions;
using NetToolsKit.Mediator;
using Microsoft.Extensions.DependencyInjection;
using NetToolsKit.Observability.Loggers.Extensions;
using NUnit.Framework;
using [NAMESPACE].Application.Cqrs.Commands;
using [NAMESPACE].Application.Cqrs.Queries;
using [NAMESPACE].IntegrationTests.Assets;

namespace [NAMESPACE].IntegrationTests.Tests.[CATEGORY]
{
    [TestFixture]
    [RequiresThread]
    [SetCulture("pt-BR")]
    [Category("[CATEGORY]")]
    public class [HANDLER_CLASS]
    {
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
                var deleteCommand = new Delete[ENTITY]Command { Id = _testEntityId };
                await _mediator.Send(deleteCommand).ConfigureAwait(false);
            }
            catch
            {
                // Ignore cleanup errors
            }
        }
        #endregion

        #region Test Methods - CRUD Operations

        [Test]
        [Order(1)]
        public async Task Create_[ENTITY]_ReturnSuccess()
        {
            // Arrange
            var command = new Create[ENTITY]Command
            {
                Id = _testEntityId,
                // Configure required properties
                [PROPERTY] = "[TEST_VALUE]",
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
        public async Task Update_[ENTITY]_ReturnSuccess()
        {
            // Arrange
            await CreateTestEntity();
            var command = new Update[ENTITY]Command
            {
                Id = _testEntityId,
                // Properties for update
                [PROPERTY] = "[NEW_VALUE]",
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.IsSuccess.Should().BeTrue();
        }

        [Test]
        [Order(3)]
        public async Task GetById_[ENTITY]_ReturnEntity()
        {
            // Arrange
            await CreateTestEntity();
            var query = new [ENTITY]Query
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
        public async Task GetAll_[ENTITY]_ReturnList()
        {
            // Arrange
            await CreateTestEntity();
            var query = new [ENTITY]Query();

            // Act
            var result = await _mediator.Send(query).ConfigureAwait(false);
            ConsoleLogger.WriteLine(result);

            // Assert
            result.Should().NotBeEmpty();
            result.Should().Contain(x => x.Id == _testEntityId);
        }

        [Test]
        [Order(5)]
        public async Task Delete_[ENTITY]_ReturnSuccess()
        {
            // Arrange
            await CreateTestEntity();
            var command = new Delete[ENTITY]Command
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

        #region Test Methods - Business Rules

        [Test]
        public async Task Create_[ENTITY]_WithInvalidData_ShouldFail()
        {
            // Arrange
            var command = new Create[ENTITY]Command
            {
                Id = _testEntityId,
                // Invalid data to test validation
                [PROPERTY] = "", // Invalid value
            };

            // Act
            var result = await _mediator.Send(command).ConfigureAwait(false);

            // Assert
            result.IsSuccess.Should().BeFalse();
            result.Errors.Should().NotBeEmpty();
        }

        [Test]
        public async Task Create_[ENTITY]_WithDuplicateId_ShouldFail()
        {
            // Arrange
            await CreateTestEntity();
            var duplicateCommand = new Create[ENTITY]Command
            {
                Id = _testEntityId, // Same ID
                [PROPERTY] = "[TEST_VALUE]",
            };

            // Act
            var result = await _mediator.Send(duplicateCommand).ConfigureAwait(false);

            // Assert
            result.IsSuccess.Should().BeFalse();
            result.Errors.Should().Contain(e => e.Contains("duplicate") || e.Contains("exists"));
        }

        #endregion

        #region Test Methods - Performance

        [Test]
        [Category("Performance")]
        public async Task GetAll_[ENTITY]_WithLargeDataset_ShouldComplete()
        {
            // Arrange
            var stopwatch = System.Diagnostics.Stopwatch.StartNew();
            var query = new [ENTITY]Query();

            // Act
            var result = await _mediator.Send(query).ConfigureAwait(false);
            stopwatch.Stop();

            // Assert
            result.Should().NotBeNull();
            stopwatch.ElapsedMilliseconds.Should().BeLessThan(5000); // 5 seconds max
            ConsoleLogger.WriteLine($"Query executed in {stopwatch.ElapsedMilliseconds}ms");
        }

        #endregion

        #region Private Helper Methods

        private async Task CreateTestEntity()
        {
            var command = new Create[ENTITY]Command
            {
                Id = _testEntityId,
                [PROPERTY] = "[TEST_VALUE]",
                // Other required properties
            };

            var result = await _mediator.Send(command).ConfigureAwait(false);
            result.IsSuccess.Should().BeTrue("Setup entity creation should succeed");
        }

        #endregion
    }
}