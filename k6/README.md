# VISE Authentication & Authorization Test Suite

This directory contains comprehensive k6 performance and functional tests for the VISE authentication and authorization system, including full OPA (Open Policy Agent) integration testing.

## 📋 Test Files

### 1. `test-auth-flow.js` (Original)
Your original k6 test covering basic auth flow:
- User registration and login
- Basic authorization checks
- Token refresh and logout

### 2. `test-auth-flow-complete.js` (Comprehensive)
Complete test coverage for ALL auth module endpoints:
- **Public Auth**: Registration, login with validation
- **Protected Auth**: Profile, password change, branch switching
- **Session Management**: List, revoke individual, revoke all sessions
- **Token Management**: Refresh token handling
- **Authorization**: Context management, permission checking, batch permissions
- **Admin Endpoints**: User, role, and permission management (placeholders)
- **OPA Integration**: Testing with registered OPA users
- **Security Testing**: Invalid credentials, unauthorized access, token validation

### 3. `test-opa-authorization.js` (OPA-Focused)
Specialized testing for OPA authorization system:
- **Direct OPA Testing**: Direct API calls to OPA service
- **Backend Integration**: Authorization through VISE backend
- **Role-Based Testing**: All registered OPA users and their permissions
- **Authorization Scenarios**: 20+ real-world permission test cases
- **Branch Isolation**: Multi-tenant access control testing
- **Performance Benchmarks**: Response time and throughput testing

## 🚀 Quick Start

### Prerequisites
1. **k6 installed**: https://k6.io/docs/get-started/installation/
2. **VISE backend running** on `localhost:6000`
3. **OPA service running** on `localhost:8181`

### Run All Tests
```bash
./run-auth-tests.sh
```

### Run Individual Tests
```bash
# Original auth flow
k6 run test-auth-flow.js

# Complete endpoint coverage
k6 run test-auth-flow-complete.js

# OPA authorization testing
k6 run test-opa-authorization.js
```

## 🔍 Test Coverage

### Auth Module Endpoints Tested

#### Public Authentication
- ✅ `POST /auth/register` - User registration
- ✅ `POST /auth/login` - User authentication

#### Protected Authentication  
- ✅ `GET /auth/profile` - Get user profile
- ✅ `POST /auth/logout` - User logout
- ✅ `POST /auth/change-password` - Password management
- ✅ `POST /auth/switch-branch` - Branch context switching

#### Session Management
- ✅ `GET /auth/sessions` - List user sessions
- ✅ `POST /auth/sessions/:id/revoke` - Revoke specific session
- ✅ `POST /auth/sessions/revoke-all` - Revoke all sessions

#### Token Management
- ✅ `POST /auth/refresh` - Refresh JWT tokens

#### Authorization
- ✅ `GET /authz/context` - Get authorization context
- ✅ `PUT /authz/context` - Update authorization context
- ✅ `POST /authz/check` - Single permission check
- ✅ `POST /authz/batch` - Batch permission checks

#### Admin Endpoints (Placeholders)
- ✅ `GET /admin/auth/users` - User management
- ✅ `GET /admin/auth/roles` - Role management  
- ✅ `GET /admin/auth/permissions` - Permission management

#### OPA Direct Testing
- ✅ `GET http://localhost:8181/health` - OPA health check
- ✅ `POST http://localhost:8181/v1/data/vise/authz/allow` - Direct authorization

## 👥 OPA Test Users

The tests use pre-configured OPA users with specific roles:

| User | Role | Description | Test Scenarios |
|------|------|-------------|----------------|
| `admin@vise.edu` | `co_admin` | Central Office Administrator | Full system access, all operations |
| `mike.wilson@vise.edu` | `co_sysadmin` + `it_admin` | IT System Administrator | Technical operations, no approve |
| `john.doe@vise.edu` | `hr_admin` | HR Administrator | Cross-department HR access |
| `jane.smith@vise.edu` | `admissions_admin` | Admissions Administrator | Full admissions access |
| `sarah.johnson@vise.edu` | `finance_admin` | Finance Administrator | Fee-related cross-department access |
| `lisa.davis@vise.edu` | `academics_operator` | Academic Operator | Limited teacher permissions |
| `viewer@vise.edu` | `co_viewer` | System Viewer | Read-only system access |

## 🧪 Authorization Test Scenarios

The OPA authorization tests include 20+ real-world scenarios:

### ✅ Positive Test Cases
- Central Office admin full access
- Department admin permissions within scope
- Cross-department access (HR → Admissions/Academics)
- Fee-related access (Finance → Admissions fees)
- Operator-level permissions (create, read, update, reports)
- System viewer read access

### ❌ Negative Test Cases  
- Branch isolation enforcement
- Role-level permission restrictions
- Cross-department access denial
- Operator permission limitations (no delete/approve)
- Viewer write access denial

### 🏗️ Edge Cases
- Invalid department/resource names
- Missing required fields
- Invalid JSON payloads
- Expired/malformed tokens

## 📊 Performance Thresholds

| Metric | Threshold | Purpose |
|--------|-----------|---------|
| Response Time P95 | < 2000ms | Overall API performance |
| Error Rate | < 10% | System reliability |
| OPA Direct Calls | < 500ms avg | Authorization decision speed |
| Backend Authorization | < 1000ms avg | End-to-end auth performance |

## 🔒 Security Tests

### Authentication Security
- ✅ Invalid credentials handling
- ✅ Missing authentication tokens
- ✅ Expired/malformed JWT validation
- ✅ Password complexity enforcement
- ✅ Session management security

### Authorization Security
- ✅ Role-based access control (RBAC)
- ✅ Branch-level data isolation  
- ✅ Permission escalation prevention
- ✅ Cross-department access rules
- ✅ Resource-level permissions

### Input Validation
- ✅ JSON payload validation
- ✅ Required field enforcement
- ✅ Data type validation
- ✅ Boundary condition testing

## 📈 Test Results

After running tests, results are saved in `./test-results/`:
- `auth-flow-original.json` - Original test results
- `auth-flow-complete.json` - Complete endpoint test results  
- `opa-authorization.json` - OPA authorization test results

### Analyzing Results

With `jq` installed, the test runner provides:
- Total request counts
- Error rates and failure analysis
- Response time metrics (avg, P95)
- Endpoint-specific performance data

### Sample Output
```
📊 Test Results Summary:
------------------------
📄 auth-flow-complete:
   Total Requests: 156
   Failed Requests: 2
   Avg Duration: 45ms
   P95 Duration: 120ms

📄 opa-authorization:
   Total Requests: 89
   Failed Requests: 0
   Avg Duration: 23ms
   P95 Duration: 67ms
```

## 🛠️ Customization

### Adding New Test Scenarios
1. **Authentication Tests**: Add new scenarios to `test-auth-flow-complete.js`
2. **Authorization Tests**: Add new scenarios to the `AUTH_SCENARIOS` array in `test-opa-authorization.js`
3. **New Users**: Add users to the `OPA_USERS` object

### Configuration
- **Base URL**: Change `BASE_URL` for different environments
- **User Data**: Modify `USER` object for test data
- **Load Testing**: Adjust `options.vus` and `options.duration`
- **Thresholds**: Modify `options.thresholds` for different performance targets

### Example Custom Test
```javascript
// Add to AUTH_SCENARIOS array
{
  user: 'customUser',
  department: 'transport',
  resource: 'vehicles',
  action: 'create',
  branch: 'branch_001',
  expected: true,
  description: 'Transport Admin vehicle creation'
}
```

## 🔧 Troubleshooting

### Common Issues

1. **VISE Backend Not Running**
   ```bash
   cd /path/to/vise-backend
   go run cmd/web/main.go
   ```

2. **OPA Service Not Available**
   ```bash
   docker-compose -f docker-compose/opa.yml up -d
   ```

3. **k6 Not Installed**
   ```bash
   # macOS
   brew install k6
   
   # Linux
   sudo apt-get install k6
   ```

4. **OPA Users Not Authenticated**
   - Ensure OPA users exist in your auth system
   - Update passwords in `OPA_USERS` object if needed
   - Check OPA data is properly loaded

### Debug Mode
Run tests with verbose output:
```bash
k6 run --verbose test-auth-flow-complete.js
```

### Performance Issues
If tests are failing performance thresholds:
1. Check system resource usage
2. Verify database performance
3. Monitor OPA response times
4. Adjust test concurrency (`options.vus`)

## 🎯 Best Practices

### Test Development
- Keep test scenarios realistic and business-relevant
- Use unique test data to avoid conflicts
- Test both positive and negative cases
- Include edge cases and error conditions

### Performance Testing
- Start with low load and gradually increase
- Monitor system resources during tests
- Set realistic performance thresholds
- Test under different load patterns

### Security Testing  
- Test all authentication mechanisms
- Verify authorization at every level
- Test input validation thoroughly
- Include security edge cases

## 📚 Additional Resources

- [k6 Documentation](https://k6.io/docs/)
- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [VISE Authentication Guide](../vise-backend/internal/auth/README.md)
- [JWT Best Practices](https://auth0.com/blog/a-look-at-the-latest-draft-for-jwt-bcp/)

---

**Created by**: VISE Development Team  
**Last Updated**: 2025-08-19  
**Version**: 1.0.0