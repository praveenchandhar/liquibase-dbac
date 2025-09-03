# MongoDB Liquibase Database-as-Code

A comprehensive Database-as-Code solution for MongoDB using Liquibase free version, enabling automated database change management across all environments.

## 📋 Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Writing YAML Changesets](#writing-yaml-changesets)
- [Available Operations](#available-operations)
- [Sample Queries](#sample-queries)
- [Best Practices](#best-practices)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This project implements a Database-as-Code framework using Liquibase open-source MongoDB extension. It provides:

- ✅ **Automated database deployments** with version control
- ✅ **Zero manual database access** with full audit trails
- ✅ **Developer-friendly** YAML-based change management
- ✅ **Multi-environment support** (dev, staging, production)
- ✅ **Rollback capabilities** for safe deployments
- ✅ **CI/CD integration** ready

## 📁 Repository Structure

product-service-repo/
├── database/
│ └── mongodb/
│ └── db/
│ ├── changelog/
│ │ └── master.changelog.yaml # Master changelog file
│ ├── base/ # Schema migrations (DDL)
│ │ └── 2025/
│ │ └── 2025.08.1.x/
│ │ └── 2025.08.01.01.yaml # Individual changesets
│ ├── seed/ # Seed data (optional)
│ │ ├── common/
│ │ ├── dev/
│ │ ├── stage/
│ │ └── pre-prod/
│ └── local/ # Local developer overrides
│ └── config/
│ ├── liquibase.properties # Liquibase configuration
│ └── liquibase.yaml # YAML configuration
├── pom.xml # Maven configuration
└── README.md # This file




## 🔧 Prerequisites

- **Java 11+** - Required for Liquibase
- **Maven 3.6+** - Build tool
- **MongoDB 5.0+** - Target database
- **Git** - Version control

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd product-service-repo
```

### 2. Configure Database Connection

Update `database/config/liquibase.properties`:

```properties
# MongoDB Connection
url=mongodb://127.0.0.1:27017/liquibase_tracking?authSource=admin
username=your_username
password=your_password
changeLogFile=database/mongodb/db/changelog/master.changelog.yaml
contexts=dev,common
logLevel=INFO
```

### 3. Test Connection

```bash
# Test Liquibase connection
mvn liquibase:status

# Apply changes
mvn liquibase:update

# Check applied changes
mvn liquibase:status
```

## 📝 Writing YAML Changesets

### Basic Changeset Structure

```yaml
databaseChangeLog:
  - changeSet:
      id: unique-changeset-id              # Must be unique
      author: developer-name               # Your name/email
      comment: "Description of changes"    # What this changeset does
      labels: "feature-name,migration"     # Optional labels
      context: "dev,staging,prod"          # Which environments
      changes:
        # Your MongoDB operations here
      rollback:
        # Optional rollback operations
```

### Changeset Properties

| Property | Required | Description | Example |
|----------|----------|-------------|---------|
| `id` | ✅ | Unique identifier | `2025.08.01.01` |
| `author` | ✅ | Developer name | `john.doe` |
| `comment` | ❌ | Description | `"Add user permissions"` |
| `labels` | ❌ | Tags for grouping | `"auth,permissions"` |
| `context` | ❌ | Environment filter | `"dev,staging"` |
| `runOnChange` | ❌ | Re-run if changed | `true/false` |
| `runAlways` | ❌ | Run every time | `true/false` |

## 🛠 Available Operations

### 1. Collection Operations

#### Create Collection

```yaml
databaseChangeLog:
  - changeSet:
      id: create-collections
      author: developer
      changes:
        - createCollection:
            collectionName: users
        - createCollection:
            collectionName: products
            options: '{ "capped": false, "size": 1000000 }'
```

#### Drop Collection

```yaml
databaseChangeLog:
  - changeSet:
      id: drop-collection
      author: developer
      changes:
        - dropCollection:
            collectionName: old_table_name
```

### 2. Index Operations

#### Create Index

```yaml
databaseChangeLog:
  - changeSet:
      id: create-indexes
      author: developer
      changes:
        # Simple index
        - createIndex:
            collectionName: users
            keys: '{ "email": 1 }'
            options: '{ "unique": true, "name": "idx_users_email" }'
        
        # Compound index
        - createIndex:
            collectionName: orders
            keys: '{ "userId": 1, "createdAt": -1 }'
            options: '{ "name": "idx_orders_user_date" }'
```

#### Drop Index

```yaml
databaseChangeLog:
  - changeSet:
      id: drop-indexes
      author: developer
      changes:
        - dropIndex:
            collectionName: users
            indexName: idx_users_email
```

### 3. Document Operations

#### Insert One Document

```yaml
databaseChangeLog:
  - changeSet:
      id: insert-admin-user
      author: developer
      changes:
        - insertOne:
            collectionName: users
            document: '{
              "username": "admin",
              "email": "admin@company.com",
              "role": "administrator",
              "createdAt": "$$NOW",
              "isActive": true
            }'
```

#### Insert Many Documents

```yaml
databaseChangeLog:
  - changeSet:
      id: insert-default-permissions
      author: developer
      changes:
        - insertMany:
            collectionName: permissions
            documents: '[
              {
                "permission": "user.create",
                "description": "Create new users",
                "module": "user-management"
              },
              {
                "permission": "user.edit",
                "description": "Edit existing users",
                "module": "user-management"
              }
            ]'
```

### 4. Update Operations

#### Update One Document

```yaml
databaseChangeLog:
  - changeSet:
      id: update-user-status
      author: developer
      changes:
        - updateOne:
            collectionName: users
            filter: '{ "username": "admin" }'
            update: '{
              "$set": {
                "lastLoginAt": "$$NOW",
                "status": "active"
              }
            }'
```

#### Update Many Documents

```yaml
databaseChangeLog:
  - changeSet:
      id: migrate-user-roles
      author: developer
      changes:
        - updateMany:
            collectionName: users
            filter: '{ "role": "manager" }'
            update: '{
              "$set": { "permissions": ["user.view", "user.edit"] },
              "$currentDate": { "updatedAt": true }
            }'
```

### 5. Delete Operations

#### Delete One Document

```yaml
databaseChangeLog:
  - changeSet:
      id: remove-test-user
      author: developer
      changes:
        - deleteOne:
            collectionName: users
            filter: '{ "username": "test-user" }'
```

#### Delete Many Documents

```yaml
databaseChangeLog:
  - changeSet:
      id: cleanup-inactive-users
      author: developer
      changes:
        - deleteMany:
            collectionName: users
            filter: '{
              "isActive": false,
              "lastLoginAt": {
                "$lt": "2024-01-01T00:00:00Z"
              }
            }'
```

## 📋 Sample Queries

### Real-World Permission Management Examples

#### 1. Add User Experience to Roles

```yaml
databaseChangeLog:
  - changeSet:
      id: add-user-experience-to-manager-roles
      author: developer
      comment: "Add TX experience to manager roles"
      changes:
        - updateMany:
            collectionName: sk_uam_role
            filter: '{ "roleKey": { "$in": ["MANAGER", "MANAGER_WITHCOMP"] } }'
            update: '{
              "$addToSet": {
                "userExperience": { "$each": ["TX"] }
              }
            }'
```

#### 2. Permission Group Management

```yaml
databaseChangeLog:
  - changeSet:
      id: update-permission-group-permissions
      author: developer
      comment: "Remove and add permissions to permission group"
      changes:
        # Remove permission
        - updateOne:
            collectionName: sk_uam_permission_group
            filter: '{ "permissionGroupName": "bros.ma.pp-projection.viewer" }'
            update: '{
              "$pull": {
                "permissions": {
                  "permission": {
                    "$in": ["bros.ma.pp-projection.claim.download"]
                  }
                }
              }
            }'
        
        # Add permission back
        - updateOne:
            collectionName: sk_uam_permission_group
            filter: '{ "permissionGroupName": "bros.ma.pp-projection.viewer" }'
            update: '{
              "$push": {
                "permissions": {
                  "$each": [
                    { "permission": "bros.ma.pp-projection.claim.download" }
                  ]
                }
              }
            }'
```

#### 3. Bulk Permission Creation

```yaml
databaseChangeLog:
  # Step 1: Remove old permissions
  - changeSet:
      id: cleanup-webtemplate-permissions
      author: developer
      comment: "Remove deprecated webtemplate permissions"
      changes:
        - deleteMany:
            collectionName: sk_uam_permission
            filter: '{
              "permission": {
                "$in": [
                  "scomp.meritcycle.webtemplate.list",
                  "scomp.meritcycle.webtemplate.view",
                  "scomp.meritcycle.webtemplate.create",
                  "scomp.meritcycle.webtemplate.edit",
                  "scomp.meritcycle.webtemplate.delete"
                ]
              }
            }'

  # Step 2: Create new permissions
  - changeSet:
      id: create-webtemplate-permissions
      author: developer
      comment: "Create new webtemplate permissions"
      changes:
        - insertMany:
            collectionName: sk_uam_permission
            documents: '[
              {
                "permission": "scomp.meritcycle.webtemplate.list",
                "suiteKey": "scomp",
                "productKey": "scomp.meritcycle",
                "type": "normal",
                "moduleKey": "scomp.meritcycle.meritplan",
                "createdBy": "1",
                "createdAt": "$$NOW",
                "updatedBy": "1",
                "updatedAt": "$$NOW",
                "description": "MeritCycle Plan web template list permission.",
                "featureKey": "scomp.meritcycle.meritplan.meritplan"
              },
              {
                "permission": "scomp.meritcycle.webtemplate.view",
                "suiteKey": "scomp",
                "productKey": "scomp.meritcycle",
                "type": "normal",
                "moduleKey": "scomp.meritcycle.meritplan",
                "createdBy": "1",
                "createdAt": "$$NOW",
                "updatedBy": "1",
                "updatedAt": "$$NOW",
                "description": "MeritCycle Plan web template view permission.",
                "featureKey": "scomp.meritcycle.meritplan.meritplan"
              }
            ]'
```

#### 4. Complex Array Updates with Filters

```yaml
databaseChangeLog:
  - changeSet:
      id: update-navigation-permissions
      author: developer
      comment: "Update navigation permissions with array filters"
      changes:
        - updateOne:
            collectionName: sk_kernelbackend_navigation
            filter: '{
              "navigation": "broker-org",
              "my-account.title": "GENERAL",
              "my-account.links.slug": "broker_org_roles_and_permission"
            }'
            update: '{
              "$set": {
                "my-account.$[account].links.$[link].permission": "sk.uam.scopedrole.edit"
              }
            }'
            options: '{
              "arrayFilters": [
                { "account.title": "GENERAL" },
                { "link.slug": "broker_org_roles_and_permission" }
              ]
            }'
```

#### 5. Role Permission Management

```yaml
databaseChangeLog:
  - changeSet:
      id: manage-employee-role-permissions
      author: developer
      comment: "Remove specific permission groups from employee role"
      changes:
        - updateMany:
            collectionName: sk_uam_role
            filter: '{ "roleKey": { "$in": ["EMPLOYEE"] } }'
            update: '{
              "$pull": {
                "permissionGroups": {
                  "permissionGroup": {
                    "$in": ["sk.uam.permission.viewer"]
                  }
                }
              }
            }'
```

## 🎯 Best Practices

### 1. Changeset Naming Convention

```yaml
# Good: Descriptive and date-based
id: 2025.08.01.01-add-user-permissions
id: 2025.08.01.02-update-role-structure

# Bad: Non-descriptive
id: changeset1
id: update
```

### 2. Use Preconditions

```yaml
databaseChangeLog:
  - changeSet:
      id: safe-collection-update
      author: developer
      preConditions:
        - collectionExists:
            collectionName: users
      changes:
        - updateMany:
            collectionName: users
            filter: '{ "status": "pending" }'
            update: '{ "$set": { "status": "active" } }'
```

### 3. Add Rollback Instructions

```yaml
databaseChangeLog:
  - changeSet:
      id: add-user-field
      author: developer
      changes:
        - updateMany:
            collectionName: users
            filter: '{}'
            update: '{ "$set": { "newField": "defaultValue" } }'
      rollback:
        - updateMany:
            collectionName: users
            filter: '{}'
            update: '{ "$unset": { "newField": 1 } }'
```

### 4. Use Labels and Contexts

```yaml
databaseChangeLog:
  - changeSet:
      id: dev-only-test-data
      author: developer
      labels: "test-data,development"
      context: "dev"
      changes:
        - insertMany:
            collectionName: test_users
            documents: '[{"name": "test", "email": "test@test.com"}]'
```

## 🚀 Deployment

### Local Development

```bash
# Apply all pending changes
mvn liquibase:update

# Check status
mvn liquibase:status

# Rollback last changeset
mvn liquibase:rollback -Dliquibase.rollbackCount=1

# Generate SQL preview (for supported operations)
mvn liquibase:updateSQL
```

### CI/CD Integration

#### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    stages {
        stage('Database Migration') {
            steps {
                script {
                    sh 'mvn liquibase:update -Dcontexts=dev'
                }
            }
        }
    }
}
```

### Environment-Specific Deployment

```bash
# Development
mvn liquibase:update -Dcontexts=dev

# Staging
mvn liquibase:update -Dcontexts=staging

# Production
mvn liquibase:update -Dcontexts=prod
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Connection Issues

```bash
# Test connection
mvn liquibase:status

# Check logs
mvn liquibase:status -X
```

#### 2. Changeset Validation Errors

```yaml
# Ensure proper YAML formatting
databaseChangeLog:  # No tabs, use spaces
  - changeSet:      # Proper indentation
      id: valid-id  # Required fields present
```

#### 3. MongoDB Command Errors

```yaml
# Ensure JSON is properly quoted
filter: '{ "field": "value" }'  # ✅ Good
filter: { "field": "value" }    # ❌ Bad
```

### Debug Commands

```bash
# Verbose output
mvn liquibase:status -X

# Validate changelog
mvn liquibase:validate

# List applied changesets
mvn liquibase:history
```

## 🔄 MongoDB Operations Reference

### Date Functions

```yaml
# Current timestamp
"createdAt": "$$NOW"

# Specific date
"expireAt": "2025-12-31T23:59:59Z"
```

### Query Operators

```yaml
# Comparison
filter: '{ "age": { "$gte": 18 } }'

# Array operations
filter: '{ "tags": { "$in": ["important", "urgent"] } }'

# Logical operators
filter: '{ "$and": [{ "active": true }, { "verified": true }] }'
```

### Update Operators

```yaml
# Set fields
update: '{ "$set": { "status": "active" } }'

# Unset fields
update: '{ "$unset": { "tempField": 1 } }'

# Array operations
update: '{ "$push": { "tags": "new-tag" } }'
update: '{ "$pull": { "tags": "old-tag" } }'
update: '{ "$addToSet": { "categories": "unique-item" } }'
```

## 📞 Support

For issues and questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review [Liquibase MongoDB Extension Documentation](https://github.com/liquibase/liquibase-mongodb)
3. Open an issue in this repository
4. Contact the database team

---

**Happy Database Management! 🎉**
