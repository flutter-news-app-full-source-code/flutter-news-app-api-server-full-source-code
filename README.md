# ht_api

![coverage: percentage](https://img.shields.io/badge/coverage-48-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

## Overview

`ht_api` is the central backend API service for the Headlines Toolkit (HT) project. Built with Dart using the Dart Frog framework, it provides essential APIs to support HT client applications (like the mobile app and web dashboard). It aims for simplicity, maintainability, and scalability, currently offering APIs for data access and user settings management.

## Features

### Core Functionality

*   **Standardized Success Responses:** Returns consistent JSON success responses wrapped in a `SuccessApiResponse` structure, including request metadata (`requestId`, `timestamp`).
*   **Standardized Error Handling:** Returns consistent JSON error responses via centralized middleware (`lib/src/middlewares/error_handler.dart`) for predictable client-side handling.
*   **Request Traceability:** Generates a unique `requestId` (UUID v4) for each incoming request, included in success response metadata and available for server-side logging via context.
*   **In-Memory Demo Mode:** Utilizes pre-loaded fixture data (`lib/src/fixtures/`) for demonstration and development purposes, simulating a live backend without external dependencies for core data, settings, and email sending.
*   **Authentication:** Provides endpoints for user sign-in/sign-up via email code and anonymous sign-in. Includes token generation and validation via middleware.

### Data API (`/api/v1/data`)

*   **Generic Data Endpoint:** Provides a unified RESTful interface for performing CRUD (Create, Read, Update, Delete) operations on multiple data models.
*   **Model Agnostic Design:** Supports various data types through a single endpoint structure, determined by the `?model=` query parameter.
*   **Currently Supported Data Models:**
    *   `headline`
    *   `category`
    *   `source`
    *   `country`

### User Settings API (`/api/v1/users/me/settings`)

*   **User-Specific Settings Management:** Provides RESTful endpoints for managing application settings (currently treated globally, future enhancement for user-specific).
*   **Supported Settings:**
    *   Display Settings (Theme, Font, etc.)
    *   Language Preference

## Technical Overview

*   **Language:** Dart (`>=3.0.0 <4.0.0`)
*   **Framework:** Dart Frog (`^1.1.0`)
*   **Architecture:** Layered architecture leveraging shared packages.
*   **Key Packages & Shared Core:**
    *   `dart_frog`: The web framework foundation.
    *   `uuid`: Used to generate unique request IDs.
    *   `ht_shared`: Contains shared data models (`Headline`, `Category`, `User`, `AuthSuccessResponse`, etc.), API response wrappers (`SuccessApiResponse`, `ResponseMetadata`), and standard exceptions (`HtHttpException`).
    *   `ht_data_client`: Defines the generic `HtDataClient<T>` interface.
    *   `ht_data_inmemory`: Provides the `HtDataInMemoryClient<T>` implementation for data.
    *   `ht_data_repository`: Defines the generic `HtDataRepository<T>` for data access.
    *   `ht_app_settings_client`: Defines the `HtAppSettingsClient` interface for settings.
    *   `ht_app_settings_inmemory`: Provides the `HtAppSettingsInMemory` implementation for settings.
    *   `ht_app_settings_repository`: Defines the `HtAppSettingsRepository` for settings management.
    *   `ht_email_client`: Defines the `HtEmailClient` interface for sending emails.
    *   `ht_email_inmemory`: Provides the `HtEmailInMemoryClient` implementation for emails.
    *   `ht_email_repository`: Defines the `HtEmailRepository` for email operations.
    *   `ht_http_client`: Provides custom HTTP exceptions (`HtHttpException` subtypes) used for consistent error signaling.
*   **Key Patterns:**
    *   **Repository Pattern:** `HtDataRepository<T>`, `HtAppSettingsRepository`, and `HtEmailRepository` provide clean abstractions over data/settings/email logic. Route handlers interact with repositories.
    *   **Service Layer:** Services like `AuthService` orchestrate complex operations involving multiple repositories or logic (e.g., authentication flow).
    *   **Generic Data Endpoint:** A single set of route handlers serves multiple data models via `/api/v1/data`.
    *   **Model Registry:** A central map (`lib/src/registry/model_registry.dart`) links data model names to configurations (`ModelConfig`) for the generic data endpoint.
    *   **Dependency Injection (Dart Frog Providers):** Middleware (`routes/_middleware.dart`) provides singleton instances of repositories, services (`AuthService`, `AuthTokenService`, etc.), the `ModelRegistryMap`, and a unique `RequestId`.
    *   **Centralized Error Handling:** The `errorHandler` middleware intercepts exceptions and maps them to standardized JSON error responses.
    *   **Authentication Middleware:** `authenticationProvider` validates tokens and provides `User?` context; `requireAuthentication` enforces access for protected routes.

## API Endpoints: Authentication (`/api/v1/auth`)

These endpoints handle user authentication flows.

**Standard Response Structure:** Uses the same `SuccessApiResponse` and error structure as the Data API. Authentication success responses typically use `SuccessApiResponse<AuthSuccessResponse>` (containing User and token) or `SuccessApiResponse<User>`.

**Authentication Operations:**

1.  **Request Sign-In Code**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/auth/request-code`
    *   **Request Body:** JSON object `{"email": "user@example.com"}`.
    *   **Success Response:** `202 Accepted` (Indicates request accepted, email sending initiated).
    *   **Example:** `POST /api/v1/auth/request-code` with body `{"email": "test@example.com"}`

2.  **Verify Sign-In Code**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/auth/verify-code`
    *   **Request Body:** JSON object `{"email": "user@example.com", "code": "123456"}`.
    *   **Success Response:** `200 OK` with `SuccessApiResponse<AuthSuccessResponse>` containing the `User` object and the authentication `token`.
    *   **Error Response:** `400 Bad Request` (e.g., invalid code/email format), `400 Bad Request` via `InvalidInputException` (e.g., code incorrect/expired).
    *   **Example:** `POST /api/v1/auth/verify-code` with body `{"email": "test@example.com", "code": "654321"}`

3.  **Sign In Anonymously**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/auth/anonymous`
    *   **Request Body:** None.
    *   **Success Response:** `200 OK` with `SuccessApiResponse<AuthSuccessResponse>` containing the anonymous `User` object and the authentication `token`.
    *   **Example:** `POST /api/v1/auth/anonymous`

4.  **Get Current User Details**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/auth/me`
    *   **Authentication:** Required (Bearer Token).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<User>` containing the details of the authenticated user.
    *   **Error Response:** `401 Unauthorized`.
    *   **Example:** `GET /api/v1/auth/me` with `Authorization: Bearer <token>` header.

5.  **Sign Out**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/auth/sign-out`
    *   **Authentication:** Required (Bearer Token).
    *   **Request Body:** None.
    *   **Success Response:** `204 No Content` (Indicates successful server-side action, if any). Client is responsible for clearing local token.
    *   **Error Response:** `401 Unauthorized`.
    *   **Example:** `POST /api/v1/auth/sign-out` with `Authorization: Bearer <token>` header.

## API Endpoints: Data (`/api/v1/data`)

This endpoint serves as the single entry point for accessing different data models. The specific model is determined by the `model` query parameter.

**Supported `model` values:** `headline`, `category`, `source`, `country`

**Standard Response Structure:** (Applies to both Data and Settings APIs)

*   **Success:**
    ```json
    {
      "data": <item_or_paginated_list_or_settings_object>,
      "metadata": {
        "request_id": "unique-uuid-v4-per-request",
        "timestamp": "iso-8601-utc-timestamp"
      }
    }
    ```
*   **Error:**
    ```json
    {
      "error": {
        "code": "ERROR_CODE_STRING",
        "message": "Descriptive error message"
      }
    }
    ```

**Data Operations:**

1.  **Get All Items (Collection)**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/data?model=<model_name>`
    *   **Optional Query Parameters:** `limit=<int>`, `startAfterId=<string>`, other filtering params.
    *   **Success Response:** `200 OK` with `SuccessApiResponse<PaginatedResponse<T>>`.
    *   **Example:** `GET /api/v1/data?model=headline&limit=10`

2.  **Create Item**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/data?model=<model_name>`
    *   **Request Body:** JSON object representing the item to create (using `camelCase` keys).
    *   **Success Response:** `201 Created` with `SuccessApiResponse<T>` containing the created item.
    *   **Example:** `POST /api/v1/data?model=category` with body `{"name": "Sports", "description": "News about sports"}`

3.  **Get Item by ID**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Success Response:** `200 OK` with `SuccessApiResponse<T>`.
    *   **Error Response:** `404 Not Found`.
    *   **Example:** `GET /api/v1/data/some-headline-id?model=headline`

4.  **Update Item by ID**
    *   **Method:** `PUT`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Request Body:** JSON object representing the complete updated item (must include `id`, using `camelCase` keys).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<T>`.
    *   **Error Response:** `404 Not Found`, `400 Bad Request`.
    *   **Example:** `PUT /api/v1/data/some-category-id?model=category` with updated category JSON (e.g., `{"id": "...", "name": "...", "description": "..."}`).

5.  **Delete Item by ID**
    *   **Method:** `DELETE`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Success Response:** `204 No Content`.
    *   **Error Response:** `404 Not Found`.
    *   **Example:** `DELETE /api/v1/data/some-source-id?model=source`

## API Endpoints: User Settings (`/api/v1/users/me/settings`)

These endpoints manage application settings. Currently, they operate on a global set of settings due to the lack of authentication; future enhancements will make them user-specific.

**Standard Response Structure:** Uses the same `SuccessApiResponse` and error structure as the Data API.

**Settings Operations:**

1.  **Get Display Settings**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/users/me/settings/display`
    *   **Success Response:** `200 OK` with `SuccessApiResponse<DisplaySettings>`.
    *   **Example:** `GET /api/v1/users/me/settings/display`

2.  **Update Display Settings**
    *   **Method:** `PUT`
    *   **Path:** `/api/v1/users/me/settings/display`
    *   **Request Body:** JSON object representing the complete `DisplaySettings` (using `camelCase` keys).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<DisplaySettings>` containing the updated settings.
    *   **Example:** `PUT /api/v1/users/me/settings/display` with body `{"baseTheme": "dark", "accentTheme": "newsRed", ...}`.

3.  **Get Language Setting**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/users/me/settings/language`
    *   **Success Response:** `200 OK` with `SuccessApiResponse<Map<String, String>>` (e.g., `{"data": {"language": "en"}, ...}`).
    *   **Example:** `GET /api/v1/users/me/settings/language`

4.  **Update Language Setting**
    *   **Method:** `PUT`
    *   **Path:** `/api/v1/users/me/settings/language`
    *   **Request Body:** JSON object `{"language": "<code>"}` (e.g., `{"language": "es"}`).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<Map<String, String>>` containing the updated language setting.
    *   **Example:** `PUT /api/v1/users/me/settings/language` with body `{"language": "fr"}`.

5.  **Clear All Settings**
    *   **Method:** `DELETE`
    *   **Path:** `/api/v1/users/me/settings`
    *   **Success Response:** `204 No Content`.
    *   **Example:** `DELETE /api/v1/users/me/settings`

## Setup & Running

1.  **Prerequisites:**
    *   Dart SDK (`>=3.0.0`)
    *   Dart Frog CLI (`dart pub global activate dart_frog_cli`)
2.  **Clone the repository:**
    ```bash
    git clone https://github.com/headlines-toolkit/ht-api.git
    cd ht-api
    ```
3.  **Get dependencies:**
    ```bash
    dart pub get
    ```
4.  **Run the development server:**
    ```bash
    dart_frog dev
    ```
    The API will typically be available at `http://localhost:8080`. Fixture data from `lib/src/fixtures/` will be loaded into the in-memory repositories on startup.

## Testing

*   Run tests and check coverage (aim for >= 90%):
    ```bash
    # Ensure very_good_cli is activated: dart pub global activate very_good_cli
    very_good test --min-coverage 90
    ```
    
## License

This package is licensed under the [PolyForm Free Trial 1.0.0](LICENSE). Please review the terms before use.
