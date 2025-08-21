import http from 'k6/http';
import { check, sleep, group } from 'k6';

// --- Configuration ---
const BASE_URL = 'http://localhost:6000/api/v1';
const USER = {
  firstName: 'k6-john',
  surname: 'doe',
  email: `k6-john-doe-${__VU}-${Date.now()}@example.com`, // Unique email with timestamp to avoid lockout
  password: 'password123',
  newPassword: 'newpassword456',
};

// Enhanced logging function
function logRequest(label, request, response) {
  console.log(`
=== ${label} ===`);
  console.log(`Request URL: ${request.method}  ${request.url}`);
  if (request.body) {
    console.log(`Request Body: ${request.body}`);
  }
  console.log(`Response Status: ${response.status}  ${response.timings.duration}ms  ${response.body}`);
  if (response.error) {
    console.log(`Response Error: ${response.error}`);
  }
  console.log('================\n');
}

export default function () {
  let accessToken = '';
  let refreshToken = '';

  console.log(`
🚀 Starting test with user: ${USER.email}`);

  group('User Registration', function () {
    const registerPayload = JSON.stringify({
      first_name: USER.firstName,
      surname: USER.surname,
      email: USER.email,
      password: USER.password,
    });
    
    console.log(`
📝 Registering user: ${USER.email}`);
    
    const registerRes = http.post(`${BASE_URL}/auth/register`, registerPayload, {
      headers: { 'Content-Type': 'application/json' }
    });
    
    logRequest('USER REGISTRATION', {
      url: `${BASE_URL}/auth/register`,
      method: 'POST',
      body: registerPayload
    }, registerRes);
    
    const registrationChecks = check(registerRes, {
      'POST /auth/register - success or user exists': (r) => {
        const isSuccess = r.status === 201 || r.status === 409;
        if (!isSuccess) {
          console.log(`❌ Registration failed: Status ${r.status}, Body: ${r.body}`);
        } else if (r.status === 201) {
          console.log(`✅ User registered successfully`);
        } else {
          console.log(`ℹ️ User already exists (409)`);
        }
        return isSuccess;
      },
      'register response has data': (r) => {
        if (r.status === 201) {
          const hasData = r.json('data') !== null;
          if (!hasData) {
            console.log(`❌ Registration success but no data in response`);
          }
          return hasData;
        }
        return true; // Skip check for 409 status
      },
      'user email_verified is true': (r) => {
        if (r.status === 201) {
          const emailVerified = r.json('data.email_verified') === true;
          if (!emailVerified) {
            console.log(`❌ User registered but email_verified is not true: ${r.json('data.email_verified')}`);
          } else {
            console.log(`✅ User registered with email_verified: true`);
          }
          return emailVerified;
        }
        return true; // Skip check for 409 status
      }
    });
    
    if (!registrationChecks) {
      console.log('❌ Registration checks failed - stopping test');
      return;
    }
  });

  group('User Login', function () {
    const loginPayload = JSON.stringify({
      email: USER.email,
      password: USER.password,
    });
    
   
    const loginRes = http.post(`${BASE_URL}/auth/login`, loginPayload, {
      headers: { 'Content-Type': 'application/json' }
    });
    
    logRequest('USER LOGIN', {
      url: `${BASE_URL}/auth/login`,
      method: 'POST',
      body: loginPayload
    }, loginRes);
    
    const loginChecks = check(loginRes, {
      'POST /auth/login - success': (r) => {
        const isSuccess = r.status === 200;
        if (!isSuccess) {
          console.log(`❌ Login failed: Status ${r.status}`);
          console.log(`❌ Error details: ${r.body}`);
          
          // Parse the error response
          try {
            const errorData = r.json();
            if (errorData.message) {
              console.log(`❌ Server message: ${errorData.message}`);
            }
            if (errorData.error && errorData.error.details) {
              console.log(`❌ Error details: ${errorData.error.details}`);
            }
          } catch (e) {
            console.log(`❌ Could not parse error response: ${e.message}`);
          }
        } else {
          console.log(`✅ Login successful`);
        }
        return isSuccess;
      },
      'has access token': (r) => {
        if (r.status === 200) {
          const hasToken = r.json('data.access_token') !== '';
          if (!hasToken) {
            console.log(`❌ Login success but no access token`);
          } else {
            console.log(`✅ Access token received`);
          }
          return hasToken;
        }
        return true; // Skip check if login failed
      },
      'has refresh token': (r) => {
        if (r.status === 200) {
          const hasRefreshToken = r.json('data.refresh_token') !== '';
          if (!hasRefreshToken) {
            console.log(`❌ Login success but no refresh token`);
          } else {
            console.log(`✅ Refresh token received`);
          }
          return hasRefreshToken;
        }
        return true; // Skip check if login failed
      },
      'user data is present': (r) => {
        if (r.status === 200) {
          const hasUserData = r.json('data.user') !== null;
          if (!hasUserData) {
            console.log(`❌ Login success but no user data`);
          } else {
            const userData = r.json('data.user');
            console.log(`✅ User data: ${userData.email}, active: ${userData.is_active}, verified: ${userData.email_verified}`);
          }
          return hasUserData;
        }
        return true; // Skip check if login failed
      }
    });
    
    if (loginRes.status === 200) {
      accessToken = loginRes.json('data.access_token');
      refreshToken = loginRes.json('data.refresh_token');
      console.log(`✅ Tokens stored for authenticated requests`);
    } else {
      console.log(`❌ No tokens stored - authenticated requests will fail`);
    }
  });

  group('Invalid Login Attempts', function () {
    console.log(`
🔒 Testing invalid login scenarios`);
    
    // Test invalid credentials
    const invalidLoginPayload = JSON.stringify({
      email: USER.email,
      password: 'wrongpassword',
    });
    
    const invalidLoginRes = http.post(`${BASE_URL}/auth/login`, invalidLoginPayload, {
      headers: { 'Content-Type': 'application/json' }
    });
    
    logRequest('INVALID LOGIN', {
      url: `${BASE_URL}/auth/login`,
      method: 'POST',
      body: invalidLoginPayload
    }, invalidLoginRes);
    
    check(invalidLoginRes, {
      'POST /auth/login - invalid credentials returns 401': (r) => {
        const isUnauthorized = r.status === 401;
        if (isUnauthorized) {
          console.log(`✅ Invalid credentials correctly rejected`);
        } else {
          console.log(`❌ Invalid credentials not properly handled: Status ${r.status}`);
        }
        return isUnauthorized;
      },
    });
  });

  if (accessToken) {
    const authHeaders = {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    };

    group('Authenticated Endpoints', function () {
      console.log(`
🔐 Testing authenticated endpoints`);
      
      // Test profile endpoint
      const profileRes = http.get(`${BASE_URL}/auth/profile`, { headers: authHeaders });
      
      logRequest('GET PROFILE', {
        url: `${BASE_URL}/auth/profile`,
        method: 'GET'
      }, profileRes);
      
      check(profileRes, {
        'GET /auth/profile - success': (r) => {
          const isSuccess = r.status === 200;
          if (isSuccess) {
            console.log(`✅ Profile retrieved successfully`);
            try {
              const profile = r.json('data');
              console.log(`✅ Profile data: ${profile.email}, verified: ${profile.email_verified}`);
            } catch (e) {
              console.log(`⚠️ Could not parse profile data`);
            }
          } else {
            console.log(`❌ Profile retrieval failed: Status ${r.status}`);
          }
          return isSuccess;
        },
      });
      

      // Test sessions endpoint
      const sessionsRes = http.get(`${BASE_URL}/auth/sessions`, { headers: authHeaders });
      
      logRequest('GET SESSIONS', {
        url: `${BASE_URL}/auth/sessions`,
        method: 'GET'
      }, sessionsRes);
      
      check(sessionsRes, {
        'GET /auth/sessions - success': (r) => {
          const isSuccess = r.status === 200;
          if (isSuccess) {
            console.log(`✅ Sessions retrieved successfully`);
            try {
              const sessions = r.json('data');
              console.log(`✅ Active sessions: ${sessions.length}`);
            } catch (e) {
              console.log(`⚠️ Could not parse sessions data`);
            }
          } else {
            console.log(`❌ Sessions retrieval failed: Status ${r.status}`);
          }
          return isSuccess;
        },
      });

      // Test authorization context
      const authzContextRes = http.get(`${BASE_URL}/authz/context`, { headers: authHeaders });
      
      logRequest('GET AUTHZ CONTEXT', {
        url: `${BASE_URL}/authz/context`,
        method: 'GET'
      }, authzContextRes);
      
      check(authzContextRes, {
        'GET /authz/context - success': (r) => {
          const isSuccess = r.status === 200;
          if (isSuccess) {
            console.log(`✅ Authorization context retrieved`);
            try {
              const context = r.json('data');
              console.log(`✅ User roles: ${JSON.stringify(context.roles)}`);
              console.log(`✅ Current branch: ${context.current_branch}`);
            } catch (e) {
              console.log(`⚠️ Could not parse authz context`);
            }
          } else {
            console.log(`❌ Authorization context failed: Status ${r.status}`);
          }
          return isSuccess;
        },
      });

      // Test permission check
      const permissionCheckPayload = JSON.stringify({
        department: 'admissions',
        resource: 'applications',
        action: 'read',
      });
      
      const permissionCheckRes = http.post(`${BASE_URL}/authz/check`, permissionCheckPayload, {
        headers: authHeaders
      });
      
      logRequest('PERMISSION CHECK', {
        url: `${BASE_URL}/authz/check`,
        method: 'POST',
        body: permissionCheckPayload
      }, permissionCheckRes);
      
      check(permissionCheckRes, {
        'POST /authz/check - success': (r) => {
          const isSuccess = r.status === 200;
          if (isSuccess) {
            try {
              const result = r.json('data');
              console.log(`✅ Permission check: allowed=${result.allowed}, reason="${result.reason}"`);
            } catch (e) {
              console.log(`✅ Permission check completed but could not parse result`);
            }
          } else {
            console.log(`❌ Permission check failed: Status ${r.status}`);
          }
          return isSuccess;
        },
      });
    });
  } else {
    console.log(`⚠️ Skipping authenticated endpoint tests - no access token available`);
  }

  group('Token Refresh', function () {
    if (refreshToken) {
      console.log(`
🔄 Testing token refresh`);
      
      const refreshRes = http.post(`${BASE_URL}/auth/refresh`, null, {
        headers: { 'Authorization': `Bearer ${refreshToken}` }
      });
      
      logRequest('TOKEN REFRESH', {
        url: `${BASE_URL}/auth/refresh`,
        method: 'POST'
      }, refreshRes);
      
      const refreshChecks = check(refreshRes, {
        'POST /auth/refresh - success': (r) => r.status === 200,
        'refresh response has data': (r) => r.json('data') !== null,
      });

      if (refreshChecks) {
        console.log(`✅ Token refresh successful`);
        console.log(`   Raw Refresh Response Body: ${refreshRes.body}`); // Log the raw body
        try {
          const newTokens = refreshRes.json('data');
          accessToken = newTokens.access_token;
          refreshToken = newTokens.refresh_token;
          console.log(`✅ New tokens received and stored`);
          console.log(`   New Access Token is present: ${accessToken ? 'true' : 'false'}`);
        } catch (e) {
          console.log(`⚠️ Token refresh success but could not parse tokens: ${e.message}`);
          accessToken = ''; // Invalidate token
        }
      } else {
        console.log(`❌ Token refresh failed: Status ${refreshRes.status}, Body: ${refreshRes.body}`);
        accessToken = ''; // Invalidate token
      }
    } else {
      console.log(`⚠️ Skipping token refresh test - no refresh token available`);
    }
  });

  group('Change Password', function () {
    if (!accessToken) {
      console.log(`⚠️ Skipping Change Password test - no access token available`);
      return;
    }

    console.log(`
🔑 Testing password change`);
    
    const changePasswordPayload = JSON.stringify({
      current_password: USER.password,
      new_password: USER.newPassword,
    });

    const authHeaders = {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    };

    const changePasswordRes = http.post(`${BASE_URL}/auth/change-password`, changePasswordPayload, {
      headers: authHeaders
    });

    logRequest('CHANGE PASSWORD', {
      url: `${BASE_URL}/auth/change-password`,
      method: 'POST',
      body: changePasswordPayload
    }, changePasswordRes);

    const changePasswordChecks = check(changePasswordRes, {
      'POST /auth/change-password - success': (r) => {
        const isSuccess = r.status === 200;
        if (isSuccess) {
          console.log(`✅ Password changed successfully`);
        } else {
          console.log(`❌ Password change failed: Status ${r.status}, Body: ${r.body}`);
        }
        return isSuccess;
      },
    });

    if (changePasswordChecks) {
      // --- Verify with new password ---
      console.log(`
🔐 Verifying login with new password...`);
      const loginNewPwdPayload = JSON.stringify({ email: USER.email, password: USER.newPassword });
      const loginNewPwdRes = http.post(`${BASE_URL}/auth/login`, loginNewPwdPayload, { headers: { 'Content-Type': 'application/json' } });
      
      logRequest('LOGIN WITH NEW PASSWORD', { url: `${BASE_URL}/auth/login`, method: 'POST', body: loginNewPwdPayload }, loginNewPwdRes);
      
      check(loginNewPwdRes, {
          'Login with new password succeeds': (r) => r.status === 200,
      });

      if (loginNewPwdRes.status === 200) {
          accessToken = loginNewPwdRes.json('data.access_token');
          refreshToken = loginNewPwdRes.json('data.refresh_token');
          console.log(`✅ New access token obtained after password change.`);
      } else {
          console.log(`❌ Failed to log in with new password, cannot continue to logout.`);
          accessToken = ''; // Invalidate token to skip logout
      }

      // --- Verify failure with old password ---
      console.log(`
🔐 Verifying login fails with old password...`);
      const loginOldPwdPayload = JSON.stringify({ email: USER.email, password: USER.password });
      const loginOldPwdRes = http.post(`${BASE_URL}/auth/login`, loginOldPwdPayload, { headers: { 'Content-Type': 'application/json' } });

      logRequest('LOGIN WITH OLD PASSWORD', { url: `${BASE_URL}/auth/login`, method: 'POST', body: loginOldPwdPayload }, loginOldPwdRes);

      check(loginOldPwdRes, {
          'Login with old password fails (401)': (r) => r.status === 401,
      });
    }
  });

  group('Logout', function () {
    if (accessToken) {
      console.log(`
👋 Testing logout`);
      
      const logoutRes = http.post(`${BASE_URL}/auth/logout`, null, {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      });
      
      logRequest('LOGOUT', {
        url: `${BASE_URL}/auth/logout`,
        method: 'POST'
      }, logoutRes);
      
      check(logoutRes, {
        'POST /auth/logout - success': (r) => {
          const isSuccess = r.status === 200;
          if (isSuccess) {
            console.log(`✅ Logout successful`);
          } else {
            console.log(`❌ Logout failed: Status ${r.status}`);
          }
          return isSuccess;
        },
      });
    } else {
      console.log(`⚠️ Skipping logout test - no access token available`);
    }
  });

  group('Unauthorized Access', function () {
    console.log(`
🚫 Testing unauthorized access`);
    
    const unauthorizedRes = http.get(`${BASE_URL}/auth/profile`, {});
    
    logRequest('UNAUTHORIZED ACCESS', {
      url: `${BASE_URL}/auth/profile`,
      method: 'GET'
    }, unauthorizedRes);
    
    check(unauthorizedRes, {
      'GET /auth/profile - unauthorized returns 401': (r) => {
        const isUnauthorized = r.status === 401;
        if (isUnauthorized) {
          console.log(`✅ Unauthorized access correctly rejected`);
        } else {
          console.log(`❌ Unauthorized access not properly handled: Status ${r.status}`);
        }
        return isUnauthorized;
      },
    });
  });

  console.log(`
✅ Test completed for user: ${USER.email}`);
  sleep(1);
}
