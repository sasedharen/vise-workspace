#!/bin/bash

# VISE Admission System - Complete Workflow Test Script
# Tests: draft → edit → submit → pending → review → accepted → offer → fees → enrolled

set -e

BASE_URL="http://localhost:6000"
ADMIN_ID="admin-123"
ADMIN_NAME="Test Admin"
STUDENT_ID="student-456"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Starting VISE Admission Workflow Test...${NC}"
echo -e "${BLUE}Base URL: $BASE_URL${NC}"
echo

# Function to test both school and college applications
test_type_prompt() {
    echo -e "${YELLOW}Select test type:${NC}"
    echo -e "${BLUE}1) School Application (Institution Code: 00)${NC}"
    echo -e "${BLUE}2) College Application (Institution Code: 04)${NC}"
    echo -e "${BLUE}3) Both School and College${NC}"
    read -p "Enter choice (1-3): " choice
    
    case $choice in
        1) TEST_TYPE="school" ;;
        2) TEST_TYPE="college" ;;
        3) TEST_TYPE="both" ;;
        *) echo -e "${RED}Invalid choice. Defaulting to school.${NC}"; TEST_TYPE="school" ;;
    esac
    echo
}

# Function to update unique values in existing test files
update_unique_values() {
    local app_type=$1
    TIMESTAMP=$(date +%s)
    UNIQUE_ID="${TIMESTAMP}$(shuf -i 100-999 -n 1)"
    
    if [ "$app_type" = "school" ]; then
        # Generate unique values for school
        SCHOOL_ROLL_NO="2025${UNIQUE_ID: -3}"
        SCHOOL_AADHAAR_ID="87654321${UNIQUE_ID: -4}"
        SCHOOL_APAAR_ID="8765YXWV${UNIQUE_ID: -4}"
        SCHOOL_EMIS_NO="23456789${UNIQUE_ID: -2}"
        SCHOOL_EMAIL="maria.garcia.test.${UNIQUE_ID}@example.com"
        SCHOOL_MOBILE="987654${UNIQUE_ID: -4}"
        SCHOOL_FATHER_MOBILE="987654${UNIQUE_ID: -4}"
        SCHOOL_MOTHER_MOBILE="876543${UNIQUE_ID: -4}"
        SCHOOL_FATHER_EMAIL="carlos.father.${UNIQUE_ID}@example.com"
        SCHOOL_MOTHER_EMAIL="ana.mother.${UNIQUE_ID}@example.com"
        SCHOOL_FATHER_PAN="ABCDE${UNIQUE_ID: -3}H"
        SCHOOL_MOTHER_PAN="FGHIJ${UNIQUE_ID: -3}M"
        
        # Copy and update school test file
        cp test-admission-form.json test-school-data.json
        
        # Update unique fields using sed
        sed -i '' "s/\"roll_no\": \"[^\"]*\"/\"roll_no\": \"$SCHOOL_ROLL_NO\"/g" test-school-data.json
        sed -i '' "s/\"aadhaar_id\": \"[^\"]*\"/\"aadhaar_id\": \"$SCHOOL_AADHAAR_ID\"/g" test-school-data.json
        sed -i '' "s/\"apaar_id\": \"[^\"]*\"/\"apaar_id\": \"$SCHOOL_APAAR_ID\"/g" test-school-data.json
        sed -i '' "s/\"emis_no\": \"[^\"]*\"/\"emis_no\": \"$SCHOOL_EMIS_NO\"/g" test-school-data.json
        sed -i '' "s/\"email\": \"[^\"]*@[^\"]*\"/\"email\": \"$SCHOOL_EMAIL\"/g" test-school-data.json
        sed -i '' "s/\"primary_mobile\": \"[^\"]*\"/\"primary_mobile\": \"$SCHOOL_MOBILE\"/g" test-school-data.json
        sed -i '' "s/\"contact_number\": \"9876543220\"/\"contact_number\": \"$SCHOOL_FATHER_MOBILE\"/g" test-school-data.json
        sed -i '' "s/\"contact_number\": \"8765432120\"/\"contact_number\": \"$SCHOOL_MOTHER_MOBILE\"/g" test-school-data.json
        sed -i '' "s/\"email\": \"carlos.father@example.com\"/\"email\": \"$SCHOOL_FATHER_EMAIL\"/g" test-school-data.json
        sed -i '' "s/\"email\": \"ana.mother@example.com\"/\"email\": \"$SCHOOL_MOTHER_EMAIL\"/g" test-school-data.json
        sed -i '' "s/\"pan_card\": \"ABCDE1234H\"/\"pan_card\": \"$SCHOOL_FATHER_PAN\"/g" test-school-data.json
        sed -i '' "s/\"pan_card\": \"FGHIJ5678M\"/\"pan_card\": \"$SCHOOL_MOTHER_PAN\"/g" test-school-data.json
        
    else
        # Generate unique values for college
        COLLEGE_ROLL_NO="2025${UNIQUE_ID: -3}"
        COLLEGE_AADHAAR_ID="98765432${UNIQUE_ID: -4}"
        COLLEGE_APAAR_ID="9876ZYXW${UNIQUE_ID: -4}"
        COLLEGE_EMIS_NO="34567890${UNIQUE_ID: -2}"
        COLLEGE_EMAIL="rajesh.sharma.college.${UNIQUE_ID}@example.com"
        COLLEGE_MOBILE="923456${UNIQUE_ID: -4}"
        COLLEGE_FATHER_MOBILE="987654${UNIQUE_ID: -4}"
        COLLEGE_MOTHER_MOBILE="987654${UNIQUE_ID: -4}"
        COLLEGE_FATHER_EMAIL="suresh.sharma.college.${UNIQUE_ID}@example.com"
        COLLEGE_MOTHER_EMAIL="priya.sharma.college.${UNIQUE_ID}@example.com"
        COLLEGE_FATHER_PAN="ABCDE${UNIQUE_ID: -3}G"
        COLLEGE_MOTHER_PAN="FGHIJ${UNIQUE_ID: -3}H"
        COLLEGE_FATHER_AADHAAR="54321098${UNIQUE_ID: -4}"
        COLLEGE_MOTHER_AADHAAR="76543210${UNIQUE_ID: -4}"
        
        # Copy and update college test file
        cp test-college-admission-form.json test-college-data.json
        
        # Update unique fields using sed
        sed -i '' "s/\"roll_no\": \"[^\"]*\"/\"roll_no\": \"$COLLEGE_ROLL_NO\"/g" test-college-data.json
        sed -i '' "s/\"aadhaar_id\": \"987654321098\"/\"aadhaar_id\": \"$COLLEGE_AADHAAR_ID\"/g" test-college-data.json
        sed -i '' "s/\"apaar_id\": \"[^\"]*\"/\"apaar_id\": \"$COLLEGE_APAAR_ID\"/g" test-college-data.json
        sed -i '' "s/\"emis_no\": \"[^\"]*\"/\"emis_no\": \"$COLLEGE_EMIS_NO\"/g" test-college-data.json
        sed -i '' "s/\"email\": \"rajesh.sharma.college@example.com\"/\"email\": \"$COLLEGE_EMAIL\"/g" test-college-data.json
        sed -i '' "s/\"primary_mobile\": \"[^\"]*\"/\"primary_mobile\": \"$COLLEGE_MOBILE\"/g" test-college-data.json
        sed -i '' "s/\"contact_number\": \"9876543211\"/\"contact_number\": \"$COLLEGE_FATHER_MOBILE\"/g" test-college-data.json
        sed -i '' "s/\"contact_number\": \"9876543212\"/\"contact_number\": \"$COLLEGE_MOTHER_MOBILE\"/g" test-college-data.json
        sed -i '' "s/\"email\": \"suresh.sharma.college@example.com\"/\"email\": \"$COLLEGE_FATHER_EMAIL\"/g" test-college-data.json
        sed -i '' "s/\"email\": \"priya.sharma.college@example.com\"/\"email\": \"$COLLEGE_MOTHER_EMAIL\"/g" test-college-data.json
        sed -i '' "s/\"pan_card\": \"ABCDE1234G\"/\"pan_card\": \"$COLLEGE_FATHER_PAN\"/g" test-college-data.json
        sed -i '' "s/\"pan_card\": \"FGHIJ5678H\"/\"pan_card\": \"$COLLEGE_MOTHER_PAN\"/g" test-college-data.json
        sed -i '' "s/\"aadhaar_id\": \"543210987655\"/\"aadhaar_id\": \"$COLLEGE_FATHER_AADHAAR\"/g" test-college-data.json
        sed -i '' "s/\"aadhaar_id\": \"765432109876\"/\"aadhaar_id\": \"$COLLEGE_MOTHER_AADHAAR\"/g" test-college-data.json
    fi
    
    echo -e "${GREEN}📝 Generated unique values for $app_type:${NC}"
    echo -e "${BLUE}   Unique ID: $UNIQUE_ID${NC}"
    echo -e "${BLUE}   Timestamp: $TIMESTAMP${NC}"
    echo -e "${GREEN}✅ Test data file updated for $app_type${NC}"
    echo
}

# Function to make API call and extract JSON values
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    local app_type=$5
    
    echo -e "${YELLOW}🔄 $description${NC}" >&2
    echo -e "${BLUE}   $method $BASE_URL$endpoint${NC}" >&2
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -X GET "$BASE_URL$endpoint" \
            -H "Content-Type: application/json")
    else
        if [ "$data" = "FILE" ]; then
            local file_name="test-${app_type}-data.json"
            response=$(curl -s -X $method "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d @"$file_name")
        else
            response=$(curl -s -X $method "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data")
        fi
    fi
    
    echo -e "${GREEN}   ✅ Response received${NC}" >&2
    echo >&2
    # Log the response for debugging
    echo "$response" > "api_response_${app_type}.log"
    
    # Add 2 second delay between API calls to prevent race conditions
    echo -e "${BLUE}   ⏱️  Waiting 2 seconds...${NC}" >&2
    sleep 2
    
    # Only return the response without any extra text
    printf "%s" "$response"
}

# Function to extract value from JSON response using new standardized format
extract_json_value() {
    local json=$1
    local key=$2
    
    if command -v jq &> /dev/null; then
        # New standardized format: data is in .data field
        local value=$(echo "$json" | jq -r ".data.${key} // empty")
        if [ "$value" != "null" ] && [ "$value" != "" ]; then
            echo "$value"
        else
            # Special handling for nested structures
            if [ "$key" = "application_id" ]; then
                # Try to extract from nested application object
                echo "$json" | jq -r '.data.application.id // empty'
            elif [ "$key" = "enrollment_id" ]; then
                # Handle both old and new field names
                echo "$json" | jq -r '.data.enrollment_id // .data.enrollmentId // empty'
            fi
        fi
    else
        # Fallback grep method for new format
        if [ "$key" = "application_id" ]; then
            echo "$json" | grep -o '"data":[^}]*"application"[^}]*"id":"[^"]*"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1
        elif [ "$key" = "enrollment_id" ]; then
            # Try both field names
            local enrollment_id=$(echo "$json" | grep -o '"enrollment_id":"[^"]*"' | cut -d'"' -f4 | head -1)
            if [ -z "$enrollment_id" ]; then
                enrollment_id=$(echo "$json" | grep -o '"enrollmentId":"[^"]*"' | cut -d'"' -f4 | head -1)
            fi
            echo "$enrollment_id"
        else
            # Look for the key in the data section
            echo "$json" | grep -o "\"data\":{[^}]*\"$key\":\"[^\"]*\"" | grep -o "\"$key\":\"[^\"]*\"" | cut -d'"' -f4 | head -1
        fi
    fi
}

# Function to check if API response indicates success
check_api_success() {
    local response=$1
    local operation=$2
    
    if command -v jq &> /dev/null; then
        local status=$(echo "$response" | jq -r '.status // empty')
        local message=$(echo "$response" | jq -r '.message // empty')
        
        if [ "$status" = "success" ]; then
            echo -e "${GREEN}✅ $operation successful: $message${NC}"
            return 0
        fi
    else
        # Fallback grep method
        if echo "$response" | grep -q '"status":"success"'; then
            local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            echo -e "${GREEN}✅ $operation successful: $message${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}⚠️  $operation response status unclear${NC}"
    return 1
}

# Function to test workflow for a specific application type
test_workflow() {
    local app_type=$1
    local app_name=$2
    
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${PURPLE}=== TESTING $app_name APPLICATION WORKFLOW ===${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo
    
    # Step 1: Create Draft Application
    echo -e "${CYAN}=== STEP 1: CREATE DRAFT APPLICATION ===${NC}"
    draft_response=$(api_call "POST" "/api/v1/admissions/draft" "FILE" "Creating draft $app_type application" "$app_type")
    
    # Check for API errors first
    if ! check_api_error "$draft_response" "Create Draft Application"; then
        echo -e "${YELLOW}🔍 Full API Response:${NC}"
        echo "$draft_response"
        return 1
    fi
    
    # Check for success and extract IDs
    if check_api_success "$draft_response" "Create Draft Application"; then
        APPLICATION_ID=$(extract_json_value "$draft_response" "application_id")
        ENROLLMENT_ID=$(extract_json_value "$draft_response" "enrollment_id")
        
        echo -e "${GREEN}📋 Extracted IDs:${NC}"
        echo -e "${BLUE}   Application ID: $APPLICATION_ID${NC}"
        echo -e "${BLUE}   Enrollment ID: $ENROLLMENT_ID${NC}"
        echo
        
        if [ -z "$APPLICATION_ID" ] || [ -z "$ENROLLMENT_ID" ]; then
            echo -e "${RED}❌ Failed to extract IDs from response${NC}"
            echo -e "${YELLOW}🔍 Full API Response:${NC}"
            echo "$draft_response"
            return 1
        fi
    else
        echo -e "${RED}❌ Draft creation did not return success status${NC}"
        echo -e "${YELLOW}🔍 Full API Response:${NC}"
        echo "$draft_response"
        return 1
    fi
    
    # Step 2: Edit Application (optional PATCH test)
    echo -e "${CYAN}=== STEP 2: EDIT APPLICATION (PATCH) ===${NC}"
    # Update middle name to "HelloTest" to test PATCH functionality
    patch_data="{\"student\":{\"middle_name\":\"HelloTest\"}}"
    patch_response=$(api_call "PATCH" "/api/v1/admissions/draft/$ENROLLMENT_ID" "$patch_data" "Updating draft $app_type application - changing middle name to HelloTest" "$app_type")
    
    # Check PATCH response
    if check_api_error "$patch_response" "Update Draft Application"; then
        if check_api_success "$patch_response" "Update Draft Application"; then
            echo -e "${GREEN}✅ Application updated - middle name changed to HelloTest${NC}"
        fi
    fi
    echo
    
    # Step 3: Submit Application (draft → pending)
    echo -e "${CYAN}=== STEP 3: SUBMIT APPLICATION (draft → pending) ===${NC}"
    submit_data="{\"enrollment_id\": \"$ENROLLMENT_ID\"}"
    submit_response=$(api_call "POST" "/api/v1/admissions/submit" "$submit_data" "Submitting $app_type application" "$app_type")
    
    # Check submit response
    if ! check_api_error "$submit_response" "Submit Application"; then
        return 1
    fi
    check_api_success "$submit_response" "Submit Application"
    echo
    
    # Step 4: Document Verification (pending → review)
    echo -e "${CYAN}=== STEP 4: DOCUMENT VERIFICATION (pending → review) ===${NC}"
    echo -e "${YELLOW}🔍 Verifying all required documents for $app_type admission...${NC}"
    
    # Required documents for admission - based on institution type (FULL LIST)
    if [ "$app_type" = "school" ]; then
        REQUIRED_DOCS=("birth_certificate" "aadhaar" "aapaar" "photograph" "previous_marksheet" "conduct_certificate")
    else
        REQUIRED_DOCS=("birth_certificate" "aadhaar" "aapaar" "photograph" "10th_marksheet" "12th_marksheet" "conduct_certificate")
    fi
    
    for doc_type in "${REQUIRED_DOCS[@]}"; do
        echo -e "${BLUE}   📄 Verifying $doc_type...${NC}"
        verify_data="{\"enrollment_id\": \"$ENROLLMENT_ID\", \"document_type\": \"$doc_type\", \"status\": \"verified\", \"admin_id\": \"$ADMIN_ID\", \"admin_name\": \"$ADMIN_NAME\", \"comments\": \"Document verified successfully\"}"
        verify_response=$(api_call "POST" "/api/v1/admin/verify-document" "$verify_data" "Verifying $doc_type for $app_type" "$app_type")
        
        # Check verification response
        if ! check_api_error "$verify_response" "Verify $doc_type"; then
            return 1
        fi
        check_api_success "$verify_response" "Verify $doc_type"
    done
    
    echo -e "${BLUE}📊 Checking verification status...${NC}"
    status_response=$(api_call "GET" "/api/v1/admin/verification-status/$APPLICATION_ID" "" "Getting verification status for $app_type" "$app_type")
    
    # Wait additional time for status transition from pending to review
    echo -e "${YELLOW}⏱️  Waiting additional 3 seconds for status transition to complete...${NC}"
    sleep 3
    echo
    
    # Step 5: Admin Review (review → accepted)
    echo -e "${CYAN}=== STEP 5: ADMIN REVIEW (review → accepted) ===${NC}"
    
    # Check current application status before attempting review
    echo -e "${BLUE}🔍 Checking current application status...${NC}"
    PGPASSWORD=vise psql -U postgres -h localhost -d vise -c "SELECT enrollment_id, application_status FROM users.application WHERE enrollment_id = '$ENROLLMENT_ID';" || echo "Failed to check status"
    echo
    
    review_data="{\"enrollment_id\": \"$ENROLLMENT_ID\", \"admin_id\": \"$ADMIN_ID\", \"admin_name\": \"$ADMIN_NAME\", \"decision\": \"accepted\", \"comments\": \"Application meets all requirements\"}"
    review_response=$(api_call "POST" "/api/v1/admin/review-application" "$review_data" "Reviewing $app_type application" "$app_type")
    
    # Check review response
    if ! check_api_error "$review_response" "Admin Review"; then
        return 1
    fi
    check_api_success "$review_response" "Admin Review"
    echo
    
    # Step 6: Issue Offer (accepted → offer)
    echo -e "${CYAN}=== STEP 6: ISSUE OFFER (accepted → offer) ===${NC}"
    local offer_amount=50000
    if [ "$app_type" = "college" ]; then
        offer_amount=75000
    fi
    offer_data="{\"enrollment_id\": \"$ENROLLMENT_ID\", \"admin_id\": \"$ADMIN_ID\", \"admin_name\": \"$ADMIN_NAME\", \"offer_amount\": $offer_amount, \"offer_details\": \"$app_name admission offer for academic year 2025-26\", \"expiry_days\": 30}"
    offer_response=$(api_call "POST" "/api/v1/admin/issue-offer" "$offer_data" "Issuing offer for $app_type" "$app_type")
    
    # Check offer response
    if ! check_api_error "$offer_response" "Issue Offer"; then
        return 1
    fi
    check_api_success "$offer_response" "Issue Offer"
    echo
    
    # Step 7: Student Accepts Offer (offer → fees)
    echo -e "${CYAN}=== STEP 7: STUDENT ACCEPTS OFFER (offer → fees) ===${NC}"
    accept_data="{\"enrollment_id\": \"$ENROLLMENT_ID\", \"response\": \"accepted\", \"comments\": \"Happy to accept the $app_name offer\"}"
    accept_response=$(api_call "POST" "/api/v1/student/offer" "$accept_data" "Accepting offer for $app_type" "$app_type")
    
    # Check accept response
    if ! check_api_error "$accept_response" "Accept Offer"; then
        return 1
    fi
    check_api_success "$accept_response" "Accept Offer"
    echo
    
    # Step 8: Confirm Fee Payment (fees → enrolled)
    echo -e "${CYAN}=== STEP 8: CONFIRM FEE PAYMENT (fees → enrolled) ===${NC}"
    # Convert app_type to uppercase for payment reference
    app_type_upper=$(echo "$app_type" | tr '[:lower:]' '[:upper:]')
    payment_data="{\"enrollment_id\": \"$ENROLLMENT_ID\", \"payment_amount\": $offer_amount, \"payment_reference\": \"PAY_${app_type_upper}_${TIMESTAMP}\", \"payment_method\": \"online_transfer\", \"processed_by\": \"finance-admin\"}"
    payment_response=$(api_call "POST" "/api/v1/finance/confirm-payment" "$payment_data" "Confirming fee payment for $app_type" "$app_type")
    
    # Check payment response
    if ! check_api_error "$payment_response" "Confirm Payment"; then
        return 1
    fi
    check_api_success "$payment_response" "Confirm Payment"
    echo
    
    echo -e "${GREEN}🎉 $app_name WORKFLOW TEST COMPLETED!${NC}"
    echo -e "${GREEN}📊 Final Status: ENROLLED${NC}"
    echo -e "${GREEN}🆔 Application ID: $APPLICATION_ID${NC}"
    echo -e "${GREEN}🎫 Enrollment ID: $ENROLLMENT_ID${NC}"
    echo
    
    # Store results for summary
    if [ "$app_type" = "school" ]; then
        SCHOOL_APPLICATION_ID="$APPLICATION_ID"
        SCHOOL_ENROLLMENT_ID="$ENROLLMENT_ID"
    else
        COLLEGE_APPLICATION_ID="$APPLICATION_ID"
        COLLEGE_ENROLLMENT_ID="$ENROLLMENT_ID"
    fi
    
    return 0
}

# Function to check for API errors in new standardized response format
check_api_error() {
    local response=$1
    local operation=$2
    
    # Check if response contains error using new format
    if command -v jq &> /dev/null; then
        local status=$(echo "$response" | jq -r '.status // empty')
        local message=$(echo "$response" | jq -r '.message // empty')
        local error_code=$(echo "$response" | jq -r '.error.code // empty')
        local error_details=$(echo "$response" | jq -r '.error.details // empty')
        local error_fields=$(echo "$response" | jq -r '.error.fields // empty')
        
        if [ "$status" = "error" ]; then
            echo -e "${RED}❌ API Error in $operation:${NC}"
            echo -e "${RED}   Message: $message${NC}"
            if [ -n "$error_code" ] && [ "$error_code" != "null" ]; then
                echo -e "${RED}   Error Code: $error_code${NC}"
            fi
            if [ -n "$error_details" ] && [ "$error_details" != "null" ]; then
                echo -e "${RED}   Details: $error_details${NC}"
            fi
            if [ -n "$error_fields" ] && [ "$error_fields" != "null" ]; then
                echo -e "${RED}   Field Errors: $error_fields${NC}"
            fi
            return 1
        fi
    else
        # Fallback grep method for new format
        if echo "$response" | grep -q '"status":"error"'; then
            echo -e "${RED}❌ API Error in $operation:${NC}"
            local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            local error_code=$(echo "$response" | grep -o '"code":"[^"]*"' | cut -d'"' -f4)
            local error_details=$(echo "$response" | grep -o '"details":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$message" ]; then
                echo -e "${RED}   Message: $message${NC}"
            fi
            if [ -n "$error_code" ]; then
                echo -e "${RED}   Error Code: $error_code${NC}"
            fi
            if [ -n "$error_details" ]; then
                echo -e "${RED}   Details: $error_details${NC}"
            fi
            return 1
        fi
    fi
    
    return 0
}

# Main execution
test_type_prompt

# Test based on user selection
if [ "$TEST_TYPE" = "school" ] || [ "$TEST_TYPE" = "both" ]; then
    update_unique_values "school"
    if ! test_workflow "school" "SCHOOL"; then
        echo -e "${RED}❌ School workflow test failed${NC}"
        exit 1
    fi
fi

if [ "$TEST_TYPE" = "college" ] || [ "$TEST_TYPE" = "both" ]; then
    update_unique_values "college"
    if ! test_workflow "college" "COLLEGE"; then
        echo -e "${RED}❌ College workflow test failed${NC}"
        exit 1
    fi
fi

# Cleanup
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f test-*-data.json api_response_*.log

echo
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}🎉 COMPLETE WORKFLOW TEST FINISHED!${NC}"
echo -e "${GREEN}=========================================${NC}"

if [ "$TEST_TYPE" = "school" ] || [ "$TEST_TYPE" = "both" ]; then
    echo -e "${BLUE}School Application:${NC}"
    echo -e "${BLUE}  🆔 Application ID: $SCHOOL_APPLICATION_ID${NC}"
    echo -e "${BLUE}  🎫 Enrollment ID: $SCHOOL_ENROLLMENT_ID${NC}"
fi

if [ "$TEST_TYPE" = "college" ] || [ "$TEST_TYPE" = "both" ]; then
    echo -e "${BLUE}College Application:${NC}"
    echo -e "${BLUE}  🆔 Application ID: $COLLEGE_APPLICATION_ID${NC}"
    echo -e "${BLUE}  🎫 Enrollment ID: $COLLEGE_ENROLLMENT_ID${NC}"
fi

echo
echo -e "${GREEN}Workflow progression completed:${NC}"
echo -e "${GREEN}1. ✅ Draft → Edit → Submit → Pending${NC}"
echo -e "${GREEN}2. ✅ Pending → Review (via document verification)${NC}"  
echo -e "${GREEN}3. ✅ Review → Accepted (via admin review)${NC}"
echo -e "${GREEN}4. ✅ Accepted → Offer (via offer issuance)${NC}"
echo -e "${GREEN}5. ✅ Offer → Fees (via student acceptance)${NC}"
echo -e "${GREEN}6. ✅ Fees → Enrolled (via payment confirmation)${NC}"
echo -e "${GREEN}=========================================${NC}"

# Database verification commands
echo -e "${YELLOW}💡 To verify in database:${NC}"
if [ "$TEST_TYPE" = "school" ] || [ "$TEST_TYPE" = "both" ]; then
    echo -e "${BLUE}PGPASSWORD=vise psql -U postgres -h localhost -d vise -c \"SELECT enrollment_id, application_status, created_time, enrolled_time FROM users.application WHERE enrollment_id = '$SCHOOL_ENROLLMENT_ID';\"${NC}"
fi

if [ "$TEST_TYPE" = "college" ] || [ "$TEST_TYPE" = "both" ]; then
    echo -e "${BLUE}PGPASSWORD=vise psql -U postgres -h localhost -d vise -c \"SELECT enrollment_id, application_status, created_time, enrolled_time FROM users.application WHERE enrollment_id = '$COLLEGE_ENROLLMENT_ID';\"${NC}"
fi