import http from 'k6/http';
import { check, sleep, group } from 'k6';

// --- Configuration ---
const BASE_URL = 'http://localhost:6000/api/v1';
// Admin credentials will be generated dynamically

// Load the JSON templates for admission forms
const schoolAdmissionTemplate = JSON.parse(open('./test-admission-form.json'));
const collegeAdmissionTemplate = JSON.parse(open('./test-college-admission-form.json'));

// Enhanced logging function from test-auth-module.js
function logRequest(label, request, response) {
  console.log(`
=== ${label} ===`);
  console.log(`Request URL: ${request.method}  ${request.url}`);
  if (request.body) {
    console.log(`Request Body: ${request.body}`);
  }
  console.log(`Response Status: ${response.status}  ${response.timings.duration}ms`);
  console.log(`Response Body: ${response.body}`);
  if (response.error) {
    console.log(`Response Error: ${response.error}`);
  }
  console.log('================\n');
}

/**
 * Generates unique data for an admission form to ensure each test run is isolated.
 */
function createUniqueAdmissionData(template, type, vu) {
  const uniqueId = `${Date.now()}${vu}`;
  const data = JSON.parse(JSON.stringify(template)); // Deep copy

  data.student.email = `${type}-student-${uniqueId}@example.com`;
  data.student.primary_mobile = `9${uniqueId.slice(-13)}`;
  data.student.aadhaar_id = `8${uniqueId.slice(-11)}`;
  data.student.apaar_id = `8${uniqueId.slice(-11)}`;
  data.student.roll_no = `k6${uniqueId.slice(-6)}`; // Generate unique roll number

  return data;
}

/**
 * Executes the full admission workflow for a given application type.
 */
function runAdmissionWorkflow(type, formData, adminToken) {
  let enrollmentId = '';
  let applicationId = '';

  group(`${type} Admission Workflow`, function () {
    // Step 1: Create Draft Application
    group('Step 1: Create Draft', function () {
      const url = `${BASE_URL}/admissions/draft`;
      const payload = JSON.stringify(formData);
      const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json' } });
      logRequest(`CREATE DRAFT - ${type}`, { url, method: 'POST', body: payload }, res);
      
      const draftChecks = check(res, {
        'POST /admissions/draft - success': (r) => r.status === 201,
        'has enrollment_id': (r) => r.json('data.enrollment_id') !== '',
        'has application_id': (r) => r.json('data.application_id') !== '',
      });

      if (draftChecks) {
        enrollmentId = res.json('data.enrollment_id');
        applicationId = res.json('data.application_id');
        console.log(`✅ ${type} Draft Created: Enrollment ID ${enrollmentId}, App ID ${applicationId}`);
      } else {
        console.log(`❌ ${type} Draft Creation Failed: Status ${res.status}`);
      }
    });

    if (!enrollmentId) return;

    sleep(2);

    // Step 2: Edit Application (PATCH)
    group('Step 2: Edit Draft', function () {
        const url = `${BASE_URL}/admissions/draft/${enrollmentId}`;
        const payload = JSON.stringify({ student: { middle_name: 'HelloThere' } });
        const res = http.patch(url, payload, { headers: { 'Content-Type': 'application/json' } });
        logRequest(`EDIT DRAFT - ${type}`, { url, method: 'PATCH', body: payload }, res);
        check(res, { 'PATCH /admissions/draft/:id - success': (r) => r.status === 200 });
    });

    sleep(2);

    // Step 3: Submit Application
    group('Step 3: Submit Application', function () {
      const url = `${BASE_URL}/admissions/submit`;
      const payload = JSON.stringify({ enrollment_id: enrollmentId });
      const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json' } });
      logRequest(`SUBMIT APP - ${type}`, { url, method: 'POST', body: payload }, res);
      check(res, { 'POST /admissions/submit - success': (r) => r.status === 200 });
    });

    sleep(3);

    // Step 4: Document Verification (as Admin)
    group('Step 4: Document Verification', function () {
      const verificationHeaders = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` };
      const documentsToVerify = type === 'School' 
        ? ["birth_certificate", "aadhaar", "aapaar", "photograph", "previous_marksheet", "conduct_certificate"]
        : ["birth_certificate", "aadhaar", "aapaar", "photograph", "10th_marksheet", "12th_marksheet", "conduct_certificate"];

      for (const doc of documentsToVerify) {
        const url = `${BASE_URL}/admin/verify-document`;
        const payload = JSON.stringify({
          enrollment_id: enrollmentId,
          document_type: doc,
          status: 'verified',
          admin_id: 'admin-k6-tester',
          admin_name: 'K6 Test Admin',
          comments: `${doc} verified by k6 test.`, 
        });
        const res = http.post(url, payload, { headers: verificationHeaders });
        logRequest(`VERIFY DOC (${doc}) - ${type}`, { url, method: 'POST', body: payload }, res);
        check(res, { [`POST /admin/verify-document - ${doc}`]: (r) => r.status === 200 });
        sleep(1);
      }
    });

    // Step 4.5: Check Verification Status
    group('Step 4.5: Check Verification Status', function () {
        const url = `${BASE_URL}/admin/verification-status/${enrollmentId}`;
        const res = http.get(url, { headers: { 'Authorization': `Bearer ${adminToken}` } });
        logRequest(`GET STATUS - ${type}`, { url, method: 'GET' }, res);
        check(res, { 'GET /admin/verification-status/:id - success': (r) => r.status === 200 });
    });

    sleep(3);

    // Step 5: Admin Review
    group('Step 5: Admin Review Application', function () {
        const url = `${BASE_URL}/admin/review-application`;
        const payload = JSON.stringify({
            enrollment_id: enrollmentId,
            admin_id: 'admin-k6-tester',
            admin_name: 'K6 Test Admin',
            decision: 'accepted',
            comments: 'Application meets all requirements.',
        });
        const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` } });
        logRequest(`REVIEW APP - ${type}`, { url, method: 'POST', body: payload }, res);
        check(res, { 'POST /admin/review-application - success': (r) => r.status === 200 });
    });

    sleep(2);

    // Step 6: Issue Offer
    group('Step 6: Issue Offer', function () {
        const url = `${BASE_URL}/admin/issue-offer`;
        const payload = JSON.stringify({
            enrollment_id: enrollmentId,
            admin_id: 'admin-k6-tester',
            admin_name: 'K6 Test Admin',
            offer_amount: type === 'School' ? 50000 : 75000,
            offer_details: `${type} admission offer for academic year 2025-26`,
            expiry_days: 30,
        });
        const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` } });
        logRequest(`ISSUE OFFER - ${type}`, { url, method: 'POST', body: payload }, res);
        check(res, { 'POST /admin/issue-offer - success': (r) => r.status === 200 });
    });

    sleep(2);

    // Step 7: Student Accepts Offer
    group('Step 7: Student Accepts Offer', function () {
        const url = `${BASE_URL}/student/offer`;
        const payload = JSON.stringify({
            enrollment_id: enrollmentId,
            response: 'accepted',
            comments: `Happy to accept the ${type} offer`,
        });
        const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json' } });
        logRequest(`ACCEPT OFFER - ${type}`, { url, method: 'POST', body: payload }, res);
        check(res, { 'POST /student/offer - success': (r) => r.status === 200 });
    });

    sleep(2);

    // Step 8: Confirm Fee Payment
    group('Step 8: Confirm Fee Payment', function () {
        const url = `${BASE_URL}/finance/confirm-payment`;
        const payload = JSON.stringify({
            enrollment_id: enrollmentId,
            payment_amount: type === 'School' ? 50000 : 75000,
            payment_reference: `k6-payment-${type.toLowerCase()}-${__VU}`,
            payment_method: 'online_transfer',
            processed_by: 'finance-admin',
        });
        const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` } });
        logRequest(`CONFIRM PAYMENT - ${type}`, { url, method: 'POST', body: payload }, res);
        check(res, { 'POST /finance/confirm-payment - success': (r) => r.status === 200 });
    });

    console.log(`✅ ${type} admission workflow completed for Enrollment ID: ${enrollmentId}`);
  });
}

export default function () {
  let adminAccessToken = '';
  
  // Generate unique admin credentials for this test run
  const uniqueId = Date.now();
  const adminUser = {
    email: `admin-k6-${uniqueId}@example.com`,
    password: 'password123',
    first_name: 'K6Admin',
    surname: 'TestUser'
  };

  group('Admin Registration', function () {
    const url = `${BASE_URL}/auth/register`;
    const payload = JSON.stringify(adminUser);
    const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json' } });
    logRequest('ADMIN REGISTRATION', { url, method: 'POST', body: payload }, res);

    check(res, {
      'Admin registration successful': (r) => r.status === 201 || r.status === 409, // 409 if user already exists
    });
  });

  group('Admin Login', function () {
    const url = `${BASE_URL}/auth/login`;
    const loginPayload = {
      email: adminUser.email,
      password: adminUser.password
    };
    const payload = JSON.stringify(loginPayload);
    const res = http.post(url, payload, { headers: { 'Content-Type': 'application/json' } });
    logRequest('ADMIN LOGIN', { url, method: 'POST', body: payload }, res);

    const loginChecks = check(res, {
      'Admin login successful': (r) => r.status === 200,
      'Admin token received': (r) => r.json('data.access_token') !== '',
    });

    if (loginChecks) {
        adminAccessToken = res.json('data.access_token');
        console.log('✅ Admin login successful, token stored.');
    } else {
        console.error('❌ Admin login failed. Skipping admission workflows.');
    }
  });

  if (adminAccessToken) {
    // --- Run School Admission Workflow ---
    const schoolData = createUniqueAdmissionData(schoolAdmissionTemplate, 'school', __VU);
    runAdmissionWorkflow('School', schoolData, adminAccessToken);
    
    console.log('พัก 5 วินาที (Waiting 5 seconds)...');
    sleep(5); // Wait before starting the next workflow

    // --- Run College Admission Workflow ---
    const collegeData = createUniqueAdmissionData(collegeAdmissionTemplate, 'college', __VU);
    runAdmissionWorkflow('College', collegeData, adminAccessToken);

  } 

  sleep(1);
}