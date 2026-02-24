---
description: Generate Entity Framework Core migrations with validations and rollback scripts
mode: ask
tools: ['codebase', 'search', 'findFiles', 'readFile', 'terminal']
---

# Create EF Core Migration
Generate an Entity Framework Core migration following repository standards with proper validation and rollback support.

## Instructions
Create a new EF Core migration based on:
- [database.instructions.md](../.github/instructions/database.instructions.md)
- [orm.instructions.md](../.github/instructions/orm.instructions.md)
- [dotnet-csharp.instructions.md](../.github/instructions/dotnet-csharp.instructions.md)

## Input Variables
- `${input:migrationName:Migration name (PascalCase)}` - Migration name (e.g., AddOrderNumberIndex)
- `${input:dbContext:DbContext class name}` - The DbContext to use
- `${input:description:Migration description}` - What this migration does
- `${input:hasSeedData:Include seed data? (yes/no)}` - Whether to include data seeding

## Pre-Migration Checklist

### 1. Review Entity Changes
- Verify entity configurations in DbContext
- Check FluentAPI configurations
- Ensure proper relationships defined
- Validate constraints and indexes

### 2. Naming Conventions
Migration names should be descriptive:
- `AddTableName` - New table
- `AddColumnNameToTableName` - New column
- `CreateIndexOnTableName` - New index
- `UpdateTableNameConstraints` - Constraint changes
- `RemoveColumnNameFromTableName` - Column removal

### 3. Generate Migration Command
```bash
dotnet ef migrations add ${migrationName} --context ${dbContext} --project src/ProjectName.Infrastructure --startup-project src/ProjectName.Api
```

## Migration Structure

### Up Migration (Apply Changes)
```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    // Table creation
    migrationBuilder.CreateTable(
        name: "TableName",
        columns: table => new
        {
            Id = table.Column<int>(nullable: false)
                .Annotation("SqlServer:Identity", "1, 1"),
            Name = table.Column<string>(maxLength: 200, nullable: false),
            CreatedAt = table.Column<DateTime>(nullable: false, defaultValueSql: "GETUTCDATE()")
        },
        constraints: table =>
        {
            table.PrimaryKey("PK_TableName", x => x.Id);
        });

    // Index creation
    migrationBuilder.CreateIndex(
        name: "IX_TableName_Name",
        table: "TableName",
        column: "Name",
        unique: true);

    // Data seeding (if applicable)
    if (${hasSeedData})
    {
        migrationBuilder.InsertData(
            table: "TableName",
            columns: new[] { "Id", "Name" },
            values: new object[] { 1, "Default Value" });
    }
}
```

### Down Migration (Rollback)
```csharp
protected override void Down(MigrationBuilder migrationBuilder)
{
    // Remove in reverse order
    migrationBuilder.DropTable(name: "TableName");
}
```

## Post-Generation Steps

### 1. Review Generated SQL
```bash
dotnet ef migrations script --context ${dbContext} --idempotent --output migration.sql
```

### 2. Validate Migration
- Check column types and lengths
- Verify default values and constraints
- Ensure foreign keys are correctly defined
- Review index definitions

### 3. Test Migration
```bash
# Apply to local database
dotnet ef database update --context ${dbContext}

# Test rollback
dotnet ef database update PreviousMigration --context ${dbContext}

# Reapply
dotnet ef database update --context ${dbContext}
```

### 4. Document Breaking Changes
If migration includes breaking changes, document:
- Data transformations required
- Dependent code changes needed
- Rollback procedures
- Deployment order requirements

## Common Migration Patterns

### Adding a Column
```csharp
migrationBuilder.AddColumn<string>(
    name: "NewColumn",
    table: "ExistingTable",
    maxLength: 100,
    nullable: true);
```

### Modifying a Column
```csharp
migrationBuilder.AlterColumn<string>(
    name: "ExistingColumn",
    table: "TableName",
    maxLength: 200,  // Changed from 100
    nullable: false);
```

### Creating a Relationship
```csharp
migrationBuilder.CreateIndex(
    name: "IX_Orders_CustomerId",
    table: "Orders",
    column: "CustomerId");

migrationBuilder.AddForeignKey(
    name: "FK_Orders_Customers_CustomerId",
    table: "Orders",
    column: "CustomerId",
    principalTable: "Customers",
    principalColumn: "Id",
    onDelete: ReferentialAction.Cascade);
```

## Data Migration Example
```csharp
// Transform existing data
migrationBuilder.Sql(@"
    UPDATE TableName 
    SET NewColumn = OldColumn 
    WHERE OldColumn IS NOT NULL;
");
```

## Quality Gates
- ✅ Migration generates without errors
- ✅ SQL script reviewed and validated
- ✅ Rollback tested successfully
- ✅ Breaking changes documented
- ✅ Applied to local database without issues
- ✅ DbContext model matches database schema

Generate the migration following all repository conventions and EF Core best practices.