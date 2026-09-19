package httpapi

import (
    "net/http"
    "os"
    "testing"
)

// Runs only in the temporary test copy created by Scripts/run_test_backend.py.
// Uses the actual Go HTTP handlers, validations and token logic with the existing memory store.
// No MongoDB connection, .env, production data or SMS provider is used.
func TestIOSFixtureServer(t *testing.T) {
    if os.Getenv("CEKSEPET_IOS_FIXTURE") != "1" { t.Skip("explicit fixture opt-in required") }
    app := newTestApp(t)
    app.server.cfg.PublicBaseURL = "http://localhost:18080"
    step1 := requestJSON(t, app.handler, http.MethodPost, "/api/v1/auth/register/step-1", map[string]any{
        "firstName": "Ada", "lastName": "Yılmaz", "phone": "+905551112233", "pin": "123456",
    }, "")
    assertStatus(t, step1, http.StatusOK)
    var registration struct { RegistrationToken string `json:"registrationToken"` }
    decodeResponse(t, step1, &registration)
    step2 := requestJSON(t, app.handler, http.MethodPost, "/api/v1/auth/register/step-2", map[string]any{
        "registrationToken": registration.RegistrationToken, "avatarId": "avatar_01",
    }, "")
    assertStatus(t, step2, http.StatusOK)
    verified := requestJSON(t, app.handler, http.MethodPost, "/api/v1/auth/register/otp/verify", map[string]any{
        "registrationToken": registration.RegistrationToken, "otpCode": app.notifier.code("+905551112233"),
    }, "")
    assertStatus(t, verified, http.StatusOK)
    t.Log("iOS fixture ready at http://localhost:18080 (real handlers, isolated in-memory data)")
    t.Fatal(http.ListenAndServe("127.0.0.1:18080", app.handler))
}
