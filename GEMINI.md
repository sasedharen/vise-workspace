# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Project Overview

This is VISE - a comprehensive multi-branch school management system built to serve 1000+ educational institutions with 13 integrated modules serving 100,000+ students and 80,000+ parents. The system follows a modular monolith architecture with a clear path to microservices extraction.

### Technology Stack

- **Backend**: Go 1.23+ with Gin framework, GORM ORM
- **Database**: PostgreSQL 15+ with schema-per-domain approach  
- **Cache**: Redis 7+ for sessions and application cache
- **Frontend**: React/TypeScript with Vite, Tailwind CSS
- **Auth**: JWT tokens with OAuth 2.0, role-based access control
- **Workflow**: Temporal.io for background processing
- **Migrations**: Flyway for database schema management
- **Testing**: Go testing, Playwright for E2E tests

## Repository Structure

```
vise/
├── vise-backend/          # Main Go backend service
│   ├── internal/          # Core business logic modules
│   │   ├── admissions/    # Student admissions system
│   │   ├── users/         # User management
│   │   └── pkg/           # Shared packages
│   ├── db/migrations/     # Flyway database migrations
│   ├── cmd/               # Entry points (web, seeder, worker)
│   ├── configs/           # Configuration files
│   └── Makefile          # Build and development commands
├── vise-frontend/         # React/TypeScript frontend
│   ├── src/
│   │   ├── components/    # UI components by module
│   │   ├── types/         # TypeScript interfaces
│   │   └── contexts/      # React contexts
│   ├── tests/             # Playwright E2E tests
│   └── package.json       # Node.js dependencies and scripts
└── auth-service/          # Separate authentication service
    ├── api/handler/       # Auth handlers
    ├── internal/          # Auth business logic
    └── frontend/          # Auth UI components
```

## Common Development Commands

### Backend (vise-backend/)
```bash
# Development
make run                  # Start the backend server
make seed                 # Seed development data
make lint                 # Run Go linting and formatting
make deps                 # Install dependencies and run checks
make build                # Build all binaries

# Testing
make test                 # Run unit tests
make test-coverage        # Run tests with coverage report
make test-integration     # Run integration tests

# Database
make migrate             # Run Flyway migrations
flyway migrate           # Direct Flyway command

# Database Access (Critical for Schema Verification)
PGPASSWORD=vise psql -U postgres -h localhost -d vise    # Direct database access

# Docker
make docker-run          # Start all services with Docker Compose
make docker-build        # Build Docker image

# Testing  
Always use the test-admission-form.json with updated data with curl to test the application workflow. Seeder is gone and forget about updating it.

# Admission Workflow Testing
When testing admission workflow, update these unique fields in test-admission-form.json for each test:
- **aadhaar_id**: 12-digit unique identifier (student.aadhaar_id)
- **apaar_id**: Alphanumeric unique identifier (student.apaar_id) 
- **emis_no**: 10-digit EMIS number (student.emis_no) - optional field
- **email**: Student email address (student.email)
- **primary_mobile**: Student mobile number (student.primary_mobile)
- **roll_no**: Student roll number (student.roll_no)
- **contact_number**: Father's contact (father.contact_number)
- **contact_number**: Mother's contact (mother.contact_number)
- **email**: Father's email (father.email) 
- **email**: Mother's email (mother.email)
- **pan_card**: Father's PAN (father.pan_card)
- **pan_card**: Mother's PAN (mother.pan_card)

## Complete Admission Workflow States
1. **draft** → 2. **submitted** → 3. **pending** → 4. **review** → 5. **accepted** → 6. **offer** → 7. **fees** → 8. **enrolled**

Alternative end states: **rejected**, **withdrawn**, **expired**, **offer_rejected**

### Workflow Progression:
- Draft → Submitted (via API: POST /api/v1/admissions/submit)
- Submitted → Pending (application submitted for document verification)
- Pending → Review (document verification in progress)
- Review → Accepted (admin approval after verification)
- Accepted → Offer (offer letter issued)
- Offer → Fees (student accepts offer) OR Offer → Offer_Rejected (student rejects)
- Fees → Enrolled (after fee payment confirmation)

## Working API Endpoints (Tested & Verified)

### Admission Endpoints
```bash
# Create Draft Application
POST /api/v1/admissions/draft
Content-Type: application/json
Body: @test-admission-form.json
Response: 201 Created - Returns application_id and enrollment_id

# Update Draft Application  
POST /api/v1/admissions/draft/:id
PATCH /api/v1/admissions/draft/:id
Content-Type: application/json
Body: @test-admission-form.json

# Submit Application for Review
POST /api/v1/admissions/submit
Content-Type: application/json
Body: {"enrollment_id": "3326110026599379"}
Response: 200 OK - Application status changed to "pending"
```

### Admin Verification Endpoints
```bash
# Check Pending Verifications (Placeholder)
GET /api/v1/admin/pending-verifications
Response: 200 OK - Returns filters and placeholder message

# Get Application Verification Status  
GET /api/v1/admin/verification-status/:application_id
Response: 200 OK - Returns document verification status

# Verify Document (Needs document_verification table)
POST /api/v1/admin/verify-document
Content-Type: application/json
Body: {
  "application_id": "uuid",
  "document_type": "birth_certificate|marksheet",
  "status": "verified|rejected|needs_resubmission", 
  "admin_id": "admin-123",
  "admin_name": "Test Admin",
  "comments": "Document verified successfully"
}
Status: Currently returns 500 (missing users.document_verification table)

# Reject Application
POST /api/v1/admin/reject-application
Content-Type: application/json

# Get Verification History
GET /api/v1/admin/verification-history/:application_id
```

### Code/Branch Information Endpoints
```bash
# Get Branch Information
GET /api/v1/branches/:state_code/:district_code/:branch_code

# Get Branch Institutions
GET /api/v1/branches/:state_code/:district_code/:branch_code/institutions

# Get Branch Curriculum
GET /api/v1/branches/:state_code/:district_code/:branch_code/curriculum

# Get Branches by District
GET /api/v1/districts/:state_code/:district_code/branches

# Get Institution Curriculum
GET /api/v1/institutions/:institution_code/curriculum

# Get Specific Curriculum
GET /api/v1/curriculum/:institution_code/:program_code/:department_code

# Validate Enrollment
POST /api/v1/enrollment/validate

# Validate Curriculum Access
GET /api/v1/access/validate
```

### Working Document Verification Flow
```bash
# 1. Create Draft Application
POST /api/v1/admissions/draft
Body: @test-admission-form.json
Response: 201 Created - Returns application_id and enrollment_id

# 2. Submit Application 
POST /api/v1/admissions/submit
Body: {"enrollment_id": "enrollment_id_from_step_1"}
Response: 200 OK - Status changes to "pending"

# 3. Verify Birth Certificate
POST /api/v1/admin/verify-document
Body: {
  "application_id": "uuid_from_step_1",
  "document_type": "birth_certificate",
  "status": "verified",
  "admin_id": "admin-123", 
  "admin_name": "Test Admin",
  "comments": "Document verified successfully"
}
Response: 200 OK - Document verification stored

# 4. Verify Marksheet
POST /api/v1/admin/verify-document  
Body: {
  "application_id": "uuid_from_step_1",
  "document_type": "marksheet",
  "status": "verified",
  "admin_id": "admin-123",
  "admin_name": "Test Admin", 
  "comments": "Document verified successfully"
}
Response: 200 OK - Auto-triggers admin verification completion

# 5. Check Verification Status
GET /api/v1/admin/verification-status/:application_id
Response: 200 OK - Returns document verification status
```

### Fixed Issues
- ✅ **Document Verification Table**: Created `users.document_verification` table with proper structure
- ✅ **Parent Records**: Fixed check constraint `chk_parent_type` to allow lowercase values
- ✅ **UUID Support**: Extended application_id column from VARCHAR(24) to VARCHAR(36)
- ✅ **Document Verification**: Core verification endpoints working and storing records

### Database Configuration
- ✅ **PostgreSQL Timezone**: Set to `Asia/Kolkata` (IST) for India-only deployment
- ✅ **Timestamp Types**: All tables use `timestamp without time zone` for consistency
- ✅ **Schema Updates**: Document verification system fully restructured with enrollment_id focus
- ✅ **EMIS Number**: Added nullable 10-digit EMIS number field to student table with validation

### Users Schema Table Dependency Order (for TRUNCATE operations)
**Critical:** When cleaning up users schema data, follow this exact order to respect foreign key constraints:
```sql
-- Dependency order for safe TRUNCATE CASCADE operations:
TRUNCATE users.document_verification CASCADE;  -- References enrollment_id
TRUNCATE users.document CASCADE;               -- References enrollment_id  
TRUNCATE users.academic CASCADE;               -- References enrollment_id
TRUNCATE users.skill CASCADE;                  -- References enrollment_id
TRUNCATE users.sport CASCADE;                  -- References enrollment_id
TRUNCATE users.sibling CASCADE;                -- References enrollment_id
TRUNCATE users.parent CASCADE;                 -- References enrollment_id
TRUNCATE users.application CASCADE;            -- Core table with enrollment_id
TRUNCATE users.student CASCADE;                -- Primary table with enrollment_id
```

### Fixed Issues
- ✅ **Document Verification Table**: Created with proper structure using enrollment_id
- ✅ **Parent Records**: Fixed check constraint to allow lowercase values
- ✅ **UUID Support**: Extended application_id column from VARCHAR(24) to VARCHAR(36)
- ✅ **Document Verification**: Core verification endpoints working with enrollment_id
- ✅ **Timestamp Consistency**: All _time columns use timestamp without time zone
- ✅ **Branch Structure**: Updated to use state_code/district_code/branch_code with CASCADE FKs
```

### Frontend (vise-frontend/)
```bash
# Development
npm run dev              # Start development server
npm run build            # Build for production
npm run lint             # Run ESLint

# Testing
npm run test             # Run Playwright tests
npm run test:ui          # Run Playwright with UI mode
npm run test:admissions  # Run admission-specific tests
```

### Auth Service (auth-service/)
```bash
go run main.go           # Start auth service
```

## Architecture Principles

### Schema Synchronization Rule (Critical)
When creating or modifying data structures, **always maintain consistency** across:
1. **Database schema**: `vise-backend/db/migrations/V{number}__{description}.sql`
2. **GORM model**: `vise-backend/internal/{module}/domain/{entity}.go`  
3. **TypeScript interface**: `vise-frontend/src/types/index.ts`

All three layers must match exactly in fields and types.

**Schema Verification Protocol**: 
- **ALWAYS** verify actual database schema using: `PGPASSWORD=vise psql -U postgres -h localhost -d vise`
- Use `\d table_name` to inspect actual table structure before making changes
- Cross-reference with Flyway migration files in `db/migrations/` 
- Ensure GORM domain models match actual database columns
- Validate that repository layer properly handles all database fields

### Multi-tenancy Design
- Every table includes `branch_id` for branch isolation
- All queries must filter by `branch_id`
- Proper indexing on `branch_id` for performance

### Module Structure
Each business module follows this pattern:
```
internal/{module}/
├── domain/          # GORM models and business entities
├── handler/         # HTTP handlers and API endpoints
├── repository/      # Data access layer
├── service/         # Business logic layer
├── routes/          # API route definitions
└── seeder/          # Development data seeding
```

### API Conventions
- RESTful endpoints: `GET /api/v1/{module}`, `POST /api/v1/{module}`, etc.
- Consistent error handling and response formats
- JWT authentication for all protected endpoints
- Role-based access control validation

## Core Business Modules

1. **Admissions** - Student application and enrollment workflow
2. **Users** - User management across all roles
3. **Administration** - Multi-branch organizational management  
4. **Finance** - Fee collection and financial operations
5. **Academic** - Course management and grading
6. **Sports** - Sports programs and performance tracking
7. **Health** - Student health records and wellness
8. **Transport** - Vehicle and route management
9. **Food** - Nutrition and canteen management
10. **Media** - Digital content and announcements

## Database Guidelines

### Type Mappings
| PostgreSQL | GORM (Go) | TypeScript |
|------------|-----------|------------|
| UUID | uuid.UUID | string |
| VARCHAR | string | string |
| INTEGER | int32 | number |
| BOOLEAN | bool | boolean |
| TIMESTAMP | time.Time | Date \| string |
| JSONB | json.RawMessage | any/object |

### Standard Model Structure
```go
type Entity struct {
    ID        uuid.UUID      `gorm:"type:uuid;default:gen_random_uuid();primaryKey" json:"id"`
    BranchID  string         `json:"branch_id" gorm:"column:branch_id;index"`
    CreatedAt time.Time      `json:"created_at"`
    UpdatedAt time.Time      `json:"updated_at"`
    DeletedAt gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
    // Entity-specific fields...
}
```

## Testing Strategy

### Test Distribution
- **Unit Tests (70%)**: Individual functions and components
- **Integration Tests (25%)**: Cross-component functionality  
- **E2E Tests (5%)**: Complete user workflows with Playwright

### Key Test Scenarios
- Authentication flows and role-based access
- Student admission workflow end-to-end
- Multi-branch data isolation
- Payment processing integration
- Form validation and error handling

## Development Workflow

### Performance Considerations
- Designed for 10,000+ concurrent users
- Database query optimization with proper indexing
- Redis caching for frequently accessed data
- Connection pooling for database efficiency
- Sub-2s response time targets

### Code Quality Standards
- All modules must include proper error handling
- Comprehensive input validation (frontend and backend)
- Structured logging with correlation IDs
- Security best practices (SQL injection prevention, XSS protection)
- GDPR and FERPA compliance for student data

## Special Notes

### Temporal Workflows
The system uses Temporal.io for background processing:
- Draft application saving
- Document processing workflows
- Application submission processing

### Authentication Integration
- JWT-based authentication via separate auth-service
- OAuth 2.0 support for external providers
- Multi-factor authentication (2FA) capability
- Hierarchical role system across branches

### Frontend Architecture
- React with TypeScript for type safety
- Tailwind CSS for styling
- Responsive design for mobile/tablet/desktop
- Context-based state management
- Toast notifications for user feedback

This system is designed to scale to millions of users while maintaining performance and data integrity across multiple school branches.
