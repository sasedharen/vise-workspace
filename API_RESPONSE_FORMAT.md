# VISE API Standardized Response Format

## Overview
All VISE API endpoints now return responses in a consistent, standardized JSON format that makes client-side parsing straightforward and error handling robust.

## Response Structure

### Success Response
```json
{
  "status": "success",
  "message": "Human-readable success message",
  "data": {
    "enrollment_id": "3326110025054727",
    "application": { ... },
    "status": "draft"
  }
}
```

### Error Response
```json
{
  "status": "error", 
  "message": "Human-readable error message",
  "error": {
    "code": "BAD_REQUEST",
    "details": "Technical error details",
    "fields": {
      "email": "Invalid email format",
      "age": "Must be a positive number"
    }
  }
}
```

## Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `VALIDATION_ERROR` | Input validation failed | 400 |
| `BAD_REQUEST` | Invalid request format | 400 |
| `NOT_FOUND` | Resource not found | 404 |
| `UNAUTHORIZED` | Authentication required | 401 |
| `FORBIDDEN` | Access denied | 403 |
| `CONFLICT` | Resource conflict | 409 |
| `INTERNAL_ERROR` | Server error | 500 |
| `SERVICE_ERROR` | External service error | 502 |

## Field Standards

- **Field Naming**: Consistent snake_case (e.g., `enrollment_id`, not `enrollmentId`)
- **Status Field**: Always included in data for workflow endpoints
- **Timestamps**: Unix timestamps for API consistency
- **IDs**: UUIDs for application_id, enrollment_id for applications

## Updated Endpoints

### Draft Application Creation
```bash
POST /api/v1/admissions/draft
```

**Success Response (201 Created):**
```json
{
  "status": "success",
  "message": "Draft saved successfully",
  "data": {
    "enrollment_id": "3326110025054727",
    "application": { ... }
  }
}
```

**Error Response (400 Bad Request):**
```json
{
  "status": "error",
  "message": "Invalid request body",
  "error": {
    "code": "BAD_REQUEST",
    "details": "json: cannot unmarshal string into Go struct field..."
  }
}
```

### Application Submission
```bash
POST /api/v1/admissions/submit
```

**Success Response (200 OK):**
```json
{
  "status": "success", 
  "message": "Application submitted successfully",
  "data": {
    "enrollment_id": "3326110025054727",
    "status": "pending"
  }
}
```

### Document Verification
```bash
POST /api/v1/admin/verify-document
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Document verification processed successfully", 
  "data": {
    "enrollment_id": "3326110025054727",
    "document_type": "birth_certificate",
    "status": "verified"
  }
}
```

**Validation Error Response (400 Bad Request):**
```json
{
  "status": "error",
  "message": "Invalid document type",
  "error": {
    "code": "VALIDATION_ERROR",
    "fields": {
      "document_type": "Must be one of: [birth_certificate, marksheet, aadhaar, photograph]"
    }
  }
}
```

### Admin Review
```bash
POST /api/v1/admin/review-application
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Application review processed successfully",
  "data": {
    "enrollment_id": "3326110025054727", 
    "decision": "accepted",
    "status": "accepted"
  }
}
```

### Offer Issuance
```bash
POST /api/v1/admin/issue-offer
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Offer issued successfully",
  "data": {
    "enrollment_id": "3326110025054727",
    "offer_amount": 50000,
    "expiry_days": 30,
    "status": "offer"
  }
}
```

### Offer Response
```bash
POST /api/v1/student/respond-to-offer
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Offer response processed successfully", 
  "data": {
    "enrollment_id": "3326110025054727",
    "response": "accepted",
    "status": "fees"
  }
}
```

### Fee Payment Confirmation
```bash
POST /api/v1/finance/confirm-payment
```

**Success Response (200 OK):**
```json
{
  "status": "success",
  "message": "Fees payment confirmed successfully",
  "data": {
    "enrollment_id": "3326110025054727",
    "payment_reference": "PAY_SCHOOL_1692345678",
    "payment_amount": 50000,
    "status": "enrolled"
  }
}
```

## Client-Side Usage

### JavaScript/TypeScript
```typescript
interface APIResponse<T = any> {
  status: 'success' | 'error';
  message: string;
  data?: T;
  error?: {
    code: string;
    details?: string;
    fields?: Record<string, string>;
  };
}

// Usage example
async function createDraft(applicationData: any): Promise<APIResponse> {
  const response = await fetch('/api/v1/admissions/draft', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(applicationData)
  });
  
  const result: APIResponse = await response.json();
  
  if (result.status === 'error') {
    if (result.error?.fields) {
      // Handle validation errors
      console.log('Validation errors:', result.error.fields);
    } else {
      // Handle general errors
      console.log('Error:', result.message);
    }
  } else {
    // Handle success
    console.log('Success:', result.data);
  }
  
  return result;
}
```

### Python
```python
import requests
from typing import Dict, Any, Optional

class APIResponse:
    def __init__(self, response_data: Dict[str, Any]):
        self.status = response_data['status']
        self.message = response_data['message']
        self.data = response_data.get('data')
        self.error = response_data.get('error')
    
    @property
    def is_success(self) -> bool:
        return self.status == 'success'
    
    @property
    def error_code(self) -> Optional[str]:
        return self.error.get('code') if self.error else None

# Usage example
def create_draft(application_data: dict) -> APIResponse:
    response = requests.post(
        'http://localhost:6000/api/v1/admissions/draft',
        json=application_data
    )
    
    result = APIResponse(response.json())
    
    if not result.is_success:
        if result.error and 'fields' in result.error:
            print(f"Validation errors: {result.error['fields']}")
        else:
            print(f"Error: {result.message}")
    else:
        print(f"Success: {result.data}")
    
    return result
```

## Benefits

1. **Consistent Parsing**: All responses follow the same structure
2. **Better Error Handling**: Specific error codes for different scenarios
3. **Validation Support**: Field-specific error messages
4. **Status Tracking**: Clear status progression through workflow
5. **Type Safety**: Predictable response format for strong typing
6. **Future-Proof**: Easy to extend with additional metadata

## Migration Notes

- All existing `gin.H{}` responses have been replaced
- Field naming standardized to snake_case
- Error responses now include structured error information
- Success responses always include relevant status information
- HTTP status codes remain unchanged for backward compatibility