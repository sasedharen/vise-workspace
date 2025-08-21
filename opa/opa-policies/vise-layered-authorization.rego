package vise.authz

import future.keywords.if
import future.keywords.in

# Default deny all access
default allow := false

# HTTP service configuration for querying backend
backend_url := "http://host.docker.internal:6000"

# ============================================================================
# LAYERED AUTHORIZATION POLICY
# Layer 1: Role-Based Permissions (Capability Matrix)
# Layer 2: URL-Based Access Control List (Path Restrictions)  
# Layer 3: Context Validation (Multi-Unit, Self, Branch)
# ============================================================================

# Main authorization rule - all three layers must pass
allow if {
    # Layer 1: Check role-based capabilities
    user_role := get_user_role(input.user)
    action_allowed_for_role(input.action, user_role)
    
    # Layer 2: Check URL-based access control
    url_allowed_for_role(input.path, user_role)
    
    # Layer 3: Check context validation
    context_access_granted(input.user, input.path, input.unit, input.branch)
}

# Special rule for 'self' role - profile self-management only
allow if {
    user_role := get_user_role(input.user)
    user_role == "self"
    self_access_granted(input.user, input.path, input.action)
}

# Special rule for 'reporter' role - reporting access only
allow if {
    user_role := get_user_role(input.user)
    user_role == "reporter"
    reporter_access_granted(input.path, input.action)
}

# Special rule for 'student' role - student portal access
allow if {
    user_role := get_user_role(input.user)
    user_role == "student"
    student_access_granted(input.user, input.path, input.action)
}

# ============================================================================
# LAYER 1: ROLE-BASED CAPABILITY MATRIX
# ============================================================================

# Define role capabilities (what actions each role can perform)
role_capabilities := {
    "admin": ["create", "read", "update", "delete", "approve", "settings"],
    "operator": ["create", "read", "update", "approve"],  # No delete capability
    "sysadmin": ["create", "read", "update", "delete", "settings"],
    "viewer": ["read"],
    "self": ["read", "update"],      # Limited to own profile
    "reporter": ["read", "create", "delete"],  # Reports only
    "student": ["read", "create", "update"]  # Student portal access
}

# Check if action is allowed for the given role
action_allowed_for_role(action, role) if {
    allowed_actions := role_capabilities[role]
    action in allowed_actions
}

# ============================================================================
# LAYER 2: URL-BASED ACCESS CONTROL LIST
# ============================================================================

# Define URL access patterns per role
url_access_patterns := {
    "admin": [".*"],  # Admin can access all URLs
    "operator": [
        "^/api/v1/users/.*",
        "^/api/v1/finance/.*",
        "^/api/v1/academic/.*",
        "^/api/v1/sports/.*",
        "^/api/v1/transport/.*"
        # Explicitly blocks /api/v1/admissions/* - handled by url_blocked_patterns
    ],
    "sysadmin": [
        "^/api/v1/.*"  # System admin can access most URLs
    ],
    "viewer": [
        "^/api/v1/.*/view$",
        "^/api/v1/.*/list$", 
        "^/api/v1/reports/.*"
    ],
    "self": [
        "^/api/v1/users/[^/]+/?$"  # Only user profile endpoints
    ],
    "reporter": [
        "^/api/v1/reports/.*"  # Only reporting endpoints
    ],
    "student": [
        "^/api/v1/admissions/.*",  # Student applications
        "^/api/v1/students/[^/]+/?$",  # Own student records
        "^/api/v1/academic/.*",  # Academic records access
        "^/api/v1/courses/.*",  # Course information
        "^/api/v1/timetable/.*",  # Timetable access
        "^/api/v1/assignments/.*",  # Assignments
        "^/api/v1/fees/[^/]+/?$",  # Own fee records
        "^/api/v1/library/.*"  # Library access
    ]
}

# Define blocked URL patterns per role (takes precedence over allowed)
url_blocked_patterns := {
    "operator": [
        "^/api/v1/admissions/.*"  # Operator blocked from admissions
    ]
}

# Check if URL is allowed for the given role
url_allowed_for_role(path, role) if {
    # First check if URL is explicitly blocked
    not url_blocked_for_role(path, role)
    
    # Then check if URL matches allowed patterns
    allowed_patterns := url_access_patterns[role]
    some pattern in allowed_patterns
    regex.match(pattern, path)
}

# Check if URL is blocked for the given role
url_blocked_for_role(path, role) if {
    blocked_patterns := url_blocked_patterns[role]
    some pattern in blocked_patterns
    regex.match(pattern, path)
}

# ============================================================================
# LAYER 3: CONTEXT VALIDATION
# ============================================================================

# Multi-unit and branch context validation
context_access_granted(user_email, path, unit, branch_id) if {
    # Get user's unit assignments
    user_units := get_user_units(user_email)
    
    # Check if user has access to the requested unit
    unit_access_valid(user_units, unit)
    
    # Check if user has access to the requested branch
    branch_access_valid(user_units.branch_id, branch_id)
}

# Validate unit access
unit_access_valid(user_units, requested_unit) if {
    # If no specific unit requested, allow (general access)
    requested_unit == ""
}

unit_access_valid(user_units, requested_unit) if {
    # Check if user has access to the requested unit
    some unit in user_units.units
    unit.unit_code == requested_unit
    unit.is_active == true
}

# Validate branch access
branch_access_valid(user_branch_id, requested_branch_id) if {
    # If no specific branch requested, allow
    requested_branch_id == ""
}

branch_access_valid(user_branch_id, requested_branch_id) if {
    # User can access their assigned branch
    user_branch_id == requested_branch_id
}

# ============================================================================
# SPECIAL ROLE HANDLERS
# ============================================================================

# Self role - can only access own profile data
self_access_granted(user_email, path, action) if {
    # Extract user ID from path (e.g., /api/v1/users/{user_id})
    path_parts := split(path, "/")
    count(path_parts) >= 5
    path_parts[1] == "api"
    path_parts[2] == "v1" 
    path_parts[3] == "users"
    
    # Get user data to find their ID
    user_data := get_user_data(user_email)
    user_id := user_data.id
    
    # URL user ID must match authenticated user's ID
    path_parts[4] == user_id
    
    # Only allow read and update actions
    action in ["read", "update"]
}

# Reporter role - can access reporting endpoints with full CRUD
reporter_access_granted(path, action) if {
    regex.match("^/api/v1/reports/.*", path)
    action in ["read", "create", "delete"]
}

# Student role - can access student portal endpoints with restricted access
student_access_granted(user_email, path, action) if {
    # Allow admission application access
    regex.match("^/api/v1/admissions/.*", path)
    action in ["read", "create", "update"]
}

student_access_granted(user_email, path, action) if {
    # Allow access to own student records only
    path_parts := split(path, "/")
    count(path_parts) >= 5
    path_parts[1] == "api"
    path_parts[2] == "v1"
    path_parts[3] == "students"
    
    # Get user data to find their student ID
    user_data := get_user_data(user_email)
    student_id := user_data.student_id  # Assuming this field exists
    
    # URL student ID must match authenticated user's student ID
    path_parts[4] == student_id
    action in ["read", "update"]
}

student_access_granted(user_email, path, action) if {
    # Allow general student portal access
    student_portal_paths := [
        "^/api/v1/academic/.*",
        "^/api/v1/courses/.*", 
        "^/api/v1/timetable/.*",
        "^/api/v1/assignments/.*",
        "^/api/v1/library/.*"
    ]
    
    some pattern in student_portal_paths
    regex.match(pattern, path)
    action in ["read"]
}

student_access_granted(user_email, path, action) if {
    # Allow access to own fee records
    regex.match("^/api/v1/fees/[^/]+/?$", path)
    path_parts := split(path, "/")
    count(path_parts) >= 5
    
    # Get user data to find their student ID
    user_data := get_user_data(user_email)
    student_id := user_data.student_id
    
    # URL student ID must match authenticated user's student ID
    path_parts[4] == student_id
    action in ["read"]
}

# ============================================================================
# HELPER FUNCTIONS - QUERY POSTGRESQL VIA HTTP
# ============================================================================

# Get user role from PostgreSQL via VISE backend API
get_user_role(email) := role if {
    user_data := get_user_data(email)
    user_data.is_active == true
    user_data.role_name != null
    role := user_data.role_name
}

# Get user data from PostgreSQL via VISE backend API
get_user_data(email) := user_data if {
    url := sprintf("%s/api/v1/opa/user/%s", [backend_url, email])
    response := http.send({
        "method": "GET",
        "url": url,
        "headers": {
            "Content-Type": "application/json",
            "User-Agent": "OPA-Policy-Agent/1.0"
        },
        "raise_error": false,
        "force_json_decode": true
    })
    
    response.status_code == 200
    user_data := response.body.data
}

# Get user's unit assignments from PostgreSQL via VISE backend API
get_user_units(email) := units_data if {
    url := sprintf("%s/api/v1/opa/user/unit/%s", [backend_url, email])
    response := http.send({
        "method": "GET",
        "url": url,
        "headers": {
            "Content-Type": "application/json",
            "User-Agent": "OPA-Policy-Agent/1.0"
        },
        "raise_error": false,
        "force_json_decode": true
    })
    
    response.status_code == 200
    units_data := response.body.data
}

# Get branch data from PostgreSQL via VISE backend API  
get_branch_data(branch_id) := branch_data if {
    url := sprintf("%s/api/v1/opa/branch/%s", [backend_url, branch_id])
    response := http.send({
        "method": "GET", 
        "url": url,
        "headers": {
            "Content-Type": "application/json",
            "User-Agent": "OPA-Policy-Agent/1.0"
        },
        "raise_error": false,
        "force_json_decode": true
    })
    
    response.status_code == 200
    branch_data := response.body.data
}

# ============================================================================
# AUDIT TRAIL AND DECISION LOGGING
# ============================================================================

# Audit trail: Log authorization decisions with layered context
decision_log := {
    "timestamp": time.now_ns(),
    "user": input.user,
    "action": input.action,
    "path": input.path,
    "unit": input.unit,
    "branch": input.branch,
    "allowed": allow,
    "reason": decision_reason,
    "authorization_model": "layered",
    "layers_checked": {
        "role_capability": layer1_result,
        "url_access": layer2_result,
        "context_validation": layer3_result
    },
    "data_source": "postgresql"
}

# Determine the reason for the authorization decision
decision_reason := reason if {
    allow
    user_role := get_user_role(input.user)
    user_role == "self"
    reason := "Self Role - Profile Management Access"
} else := reason if {
    allow
    user_role := get_user_role(input.user)
    user_role == "reporter"
    reason := "Reporter Role - Reporting Access"
} else := reason if {
    allow
    user_role := get_user_role(input.user)
    user_role == "student"
    reason := "Student Role - Student Portal Access"
} else := reason if {
    allow
    user_role := get_user_role(input.user)
    reason := sprintf("Layered Authorization - Role: %s", [user_role])
} else := "Access Denied - Failed Layered Authorization"

# Layer results for debugging
layer1_result := result if {
    user_role := get_user_role(input.user)
    result := action_allowed_for_role(input.action, user_role)
}

layer2_result := result if {
    user_role := get_user_role(input.user)
    result := url_allowed_for_role(input.path, user_role)
}

layer3_result := result if {
    result := context_access_granted(input.user, input.path, input.unit, input.branch)
}

# ============================================================================
# DEBUG AND TESTING FUNCTIONS
# ============================================================================

# Debug function to get raw user data
debug_user_data := get_user_data(input.user) if {
    input.debug == true
}

# Debug function to get user units
debug_user_units := get_user_units(input.user) if {
    input.debug == true
}

# Debug function to test HTTP connectivity
debug_connectivity := response if {
    input.debug == true
    url := sprintf("%s/api/v1/opa/health", [backend_url])
    response := http.send({
        "method": "GET",
        "url": url,
        "raise_error": false
    })
}

# Debug function to show authorization layers
debug_authorization_layers := {
    "layer1_role_capabilities": role_capabilities,
    "layer2_url_patterns": url_access_patterns,
    "layer2_blocked_patterns": url_blocked_patterns,
    "layer3_context_validation": "multi_unit_and_branch_access"
} if {
    input.debug == true
}