# 🏗️ Architecture & Flow Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOBILE APP                                │
│                   (Flutter - Dart)                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS + Bearer Token
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API BACKEND                                   │
│              (Laravel - PHP)                                     │
│  https://smart-environment-web.citiasiainc.id/api/v1            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       PRESENTATION LAYER                          │
│                         (Screens)                                 │
│                                                                   │
│  ┌─────────────────────┐      ┌─────────────────────┐           │
│  │   RESIDENT/WARGA    │      │   COLLECTOR/KOLEKTOR │           │
│  ├─────────────────────┤      ├─────────────────────┤           │
│  │ EditAkunScreen      │      │ EditAkunScreen       │           │
│  │ ChangePasswordScreen│      │ ChangePasswordScreen │           │
│  └─────────────────────┘      └─────────────────────┘           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                       BUSINESS LAYER                              │
│                        (Services)                                 │
│                                                                   │
│  ┌─────────────────────┐      ┌──────────────────────────┐      │
│  │  ProfileService     │      │CollectorProfileService   │      │
│  ├─────────────────────┤      ├──────────────────────────┤      │
│  │ + getProfile()      │      │ + getProfile()           │      │
│  │ + updateProfile()   │      │ + updateProfile()        │      │
│  │ + changePassword()  │      │ + changePassword()       │      │
│  └─────────────────────┘      └──────────────────────────┘      │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                       DATA LAYER                                  │
│                                                                   │
│  ┌─────────────────────┐      ┌─────────────────────┐           │
│  │   ApiClient         │      │   Storage            │           │
│  ├─────────────────────┤      ├─────────────────────┤           │
│  │ - Dio HTTP Client   │      │ - TokenStorage       │           │
│  │ - Interceptors      │      │ - UserStorage        │           │
│  │ - Auto Auth Token   │      │ - SharedPreferences  │           │
│  └─────────────────────┘      └─────────────────────┘           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                       MODEL LAYER                                 │
│                                                                   │
│  ┌─────────────────────────────────────────────────┐             │
│  │          UserProfile Model                      │             │
│  ├─────────────────────────────────────────────────┤             │
│  │ - id: int                                       │             │
│  │ - name: String                                  │             │
│  │ - email: String                                 │             │
│  │ - phone: String?                                │             │
│  │ - roles: List<String>?                          │             │
│  │                                                 │             │
│  │ + fromJson()                                    │             │
│  │ + toJson()                                      │             │
│  │ + copyWith()                                    │             │
│  └─────────────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────────────┘
```

---

## Request Flow - Get Profile

```
┌─────────┐                                                     ┌─────────┐
│  USER   │                                                     │   API   │
└────┬────┘                                                     └────┬────┘
     │                                                                │
     │  1. Tap "Edit Akun"                                           │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  2. Screen calls getProfile()                                 │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  3. Service makes GET request                                 │
     │     + Bearer Token (auto-added)                               │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │                                            4. Validate Token   │
     │                                            5. Fetch Profile    │
     │                                                                │
     │  6. Return profile data                                       │
     │◀──────────────────────────────────────────────────────────────┤
     │                                                                │
     │  7. Update UI with data                                       │
     │  8. Save to local storage (cache)                             │
     │                                                                │
     
     IF API FAILS:
     │  9. Load from local storage                                   │
     │  10. Show warning message                                     │
```

---

## Request Flow - Update Profile

```
┌─────────┐                                                     ┌─────────┐
│  USER   │                                                     │   API   │
└────┬────┘                                                     └────┬────┘
     │                                                                │
     │  1. Fill form (name, phone)                                   │
     │  2. Tap "Simpan Perubahan"                                    │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  3. Validate input (client-side)                              │
     │     - name min 3 chars                                        │
     │     - phone min 10 digits                                     │
     │                                                                │
     │  4. Call updateProfile()                                      │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  5. Service makes PUT request                                 │
     │     + Bearer Token                                            │
     │     + { name, phone }                                         │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │                                            6. Validate Token   │
     │                                            7. Validate Data    │
     │                                            8. Update Database  │
     │                                                                │
     │  9. Return updated profile                                    │
     │◀──────────────────────────────────────────────────────────────┤
     │                                                                │
     │  10. Update local storage                                     │
     │  11. Update UserStorage                                       │
     │  12. Show success message                                     │
     │  13. Navigate back                                            │
```

---

## Request Flow - Change Password

```
┌─────────┐                                                     ┌─────────┐
│  USER   │                                                     │   API   │
└────┬────┘                                                     └────┬────┘
     │                                                                │
     │  1. Fill password form                                        │
     │     - current password                                        │
     │     - new password                                            │
     │     - confirm password                                        │
     │                                                                │
     │  2. Validate input (client-side)                              │
     │     - min 8 chars                                             │
     │     - has letter & number                                     │
     │     - passwords match                                         │
     │                                                                │
     │  3. Tap "Ubah Password"                                       │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  4. Call changePassword()                                     │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │  5. Service makes POST request                                │
     │     + Bearer Token                                            │
     │     + { current_password, new_password, confirmation }        │
     ├──────────────────────────────────────────────────────────────▶│
     │                                                                │
     │                                            6. Validate Token   │
     │                                            7. Verify Current   │
     │                                            8. Validate New     │
     │                                            9. Hash & Save      │
     │                                                                │
     │  10. Return success                                           │
     │◀──────────────────────────────────────────────────────────────┤
     │                                                                │
     │  11. Create local notification                                │
     │  12. Show success dialog                                      │
     │  13. Navigate back to profile                                 │
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      API Request Made                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   Network Call        │
                  │   (Dio HTTP)          │
                  └──────────┬────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
      ┌─────────────────┐      ┌─────────────────┐
      │   SUCCESS       │      │   ERROR         │
      │   (200-299)     │      │   (400-599)     │
      └────────┬────────┘      └────────┬────────┘
               │                        │
               ▼                        ▼
    ┌──────────────────┐    ┌──────────────────────┐
    │ Parse Response   │    │ Check Error Type     │
    │ Extract Data     │    │                      │
    └────────┬─────────┘    └──────────┬───────────┘
             │                         │
             │              ┌──────────┴──────────┐
             │              │                     │
             │              ▼                     ▼
             │    ┌─────────────────┐  ┌─────────────────┐
             │    │ 401 Unauthorized│  │ 422 Validation  │
             │    │ → Re-login      │  │ → Show Errors   │
             │    └─────────────────┘  └─────────────────┘
             │              │                     │
             │              ▼                     ▼
             │    ┌─────────────────┐  ┌─────────────────┐
             │    │ 500 Server Error│  │ Network Error   │
             │    │ → Retry Later   │  │ → Use Cache     │
             │    └─────────────────┘  └─────────────────┘
             │                          
             ▼
    ┌──────────────────────────────────────────────┐
    │         Return to Screen                     │
    │                                              │
    │  - Update UI                                 │
    │  - Show message (success/error)              │
    │  - Update local storage (if success)         │
    │  - Navigate (if needed)                      │
    └──────────────────────────────────────────────┘
```

---

## Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOGIN                                    │
│                                                                  │
│  1. User enters email + password                                │
│  2. POST /auth/login                                            │
│  3. Server validates & returns token                            │
│  4. Token saved to TokenStorage (secure)                        │
│  5. User data saved to UserStorage                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ALL API REQUESTS                              │
│                                                                  │
│  ApiClient Interceptor automatically adds:                      │
│  Authorization: Bearer {token}                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API VALIDATES                               │
│                                                                  │
│  - Check if token exists                                        │
│  - Check if token is valid                                      │
│  - Check if token is expired                                    │
│  - Check user permissions/roles                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
        ┌───────────────┐          ┌───────────────┐
        │  VALID TOKEN  │          │ INVALID TOKEN │
        │  → Process    │          │ → 401 Error   │
        │     Request   │          │ → Force Login │
        └───────────────┘          └───────────────┘
```

---

## Data Sync Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    ONLINE MODE                                   │
│                                                                  │
│  1. API Request made                                            │
│  2. Response received                                           │
│  3. Update local storage (cache)                                │
│  4. Show data to user                                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    OFFLINE MODE                                  │
│                                                                  │
│  1. API Request fails (network error)                           │
│  2. Check local storage                                         │
│  3. If data exists → show cached data                           │
│  4. If no data → show error message                             │
│  5. Show warning: "Using offline data"                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  SYNC STRATEGY                                   │
│                                                                  │
│  - Always try API first                                         │
│  - Fallback to cache on failure                                 │
│  - Update cache on every success                                │
│  - Cache expires after logout                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Interaction

```
EditAkunScreen
    │
    ├─ initState()
    │   └─ _loadUserData()
    │       ├─ ProfileService.getProfile()
    │       │   ├─ ApiClient.dio.get()
    │       │   └─ [SUCCESS] → Update UI
    │       │
    │       └─ [FAIL] → Load from UserStorage
    │
    └─ _saveChanges()
        └─ ProfileService.updateProfile()
            ├─ ApiClient.dio.put()
            ├─ [SUCCESS] → Update UserStorage
            ├─ [SUCCESS] → Update SharedPreferences
            └─ [SUCCESS] → Navigate back

ChangePasswordScreen
    │
    ├─ _saveNewPassword()
    │   ├─ Validate form
    │   └─ ProfileService.changePassword()
    │       ├─ ApiClient.dio.post()
    │       ├─ [SUCCESS] → Create notification
    │       └─ [SUCCESS] → Show dialog
    │
    └─ _showSuccessDialog()
        └─ Navigate back to Profile
```

---

## Security Layers

```
Layer 1: HTTPS
    └─ All API calls use HTTPS encryption

Layer 2: Authentication
    └─ Bearer Token required for all requests

Layer 3: Validation
    ├─ Client-side validation (immediate feedback)
    └─ Server-side validation (security)

Layer 4: Authorization
    ├─ Role-based access (resident vs collector)
    └─ User can only access own data

Layer 5: Data Protection
    ├─ Email cannot be changed
    ├─ Password validation (min 8, letter+number)
    └─ Current password required for change
```

---

## Performance Optimization

```
1. Caching Strategy
   ├─ Cache profile data locally
   ├─ Reduce API calls
   └─ Faster load times

2. Loading States
   ├─ Show loading indicator
   ├─ Prevent duplicate requests
   └─ Better user experience

3. Error Recovery
   ├─ Fallback to cache
   ├─ Retry mechanism
   └─ Graceful degradation

4. Validation
   ├─ Client-side first (fast feedback)
   ├─ Server-side confirmation (security)
   └─ Prevent invalid API calls
```

This architecture ensures a robust, secure, and user-friendly implementation! 🚀
