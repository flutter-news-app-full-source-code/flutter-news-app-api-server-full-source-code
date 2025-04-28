# ht_api

<!-- Badges (Update coverage XX value after running tests) -->
![coverage: percentage](https://img.shields.io/badge/coverage-XX-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

## Overview

`ht_api` is the backend API component of the Headlines Toolkit (HT) project. It serves as the central data provider for HT applications (like the mobile app and web dashboard), offering access to various data models required by the toolkit. Built with Dart using the Dart Frog framework, it prioritizes simplicity, maintainability, and scalability through a generic API design.

## Features

*   **Generic Data Endpoint (`/api/v1/data`):** Provides a unified RESTful interface for performing CRUD (Create, Read, Update, Delete) operations on multiple data models.
*   **Model Agnostic Design:** Supports various data types through a single endpoint structure, determined by the `?model=` query parameter.
*   **Currently Supported Models:**
    *   `headline`
    *   `category`
    *   `source`
    *   `country`
*   **Standardized Success Responses:** Returns consistent JSON success responses wrapped in a `SuccessApiResponse` structure, including request metadata (`requestId`, `timestamp`).
*   **Standardized Error Handling:** Returns consistent JSON error responses via centralized middleware (`lib/src/middlewares/error_handler.dart`) for predictable client-side handling.
*   **Request Traceability:** Generates a unique `requestId` (UUID v4) for each incoming request, included in success response metadata and available for server-side logging via context.
*   **In-Memory Demo Mode:** Utilizes pre-loaded fixture data (`lib/src/fixtures/`) for demonstration and development purposes, simulating a live backend without external dependencies.
*   **Standardized Error Handling:** Returns consistent JSON error responses via centralized middleware (`lib/src/middlewares/error_handler.dart`) for predictable client-side handling.

## Technical Overview

*   **Language:** Dart (`>=3.0.0 <4.0.0`)
*   **Framework:** Dart Frog (`^1.1.0`)
*   **Architecture:** Layered architecture leveraging shared packages and a generic API pattern.
*   **Key Packages & Shared Core:**
    *   `dart_frog`: The web framework foundation.
    *   `uuid`: Used to generate unique request IDs.
    *   `ht_shared`: Contains shared data models (`Headline`, `Category`, `Source`, `Country`, `SuccessApiResponse`, `ResponseMetadata`, etc.) used across the HT ecosystem.
    *   `ht_data_client`: Defines the generic `HtDataClient<T>` interface for data access operations.
    *   `ht_data_inmemory`: Provides the `HtDataInMemoryClient<T>` implementation, used here for the demo mode, seeded with fixture data.
    *   `ht_data_repository`: Defines the generic `HtDataRepository<T>` which abstracts the data client, providing a clean interface to the API route handlers.
    *   `ht_http_client`: Provides custom HTTP exceptions (`HtHttpException` subtypes) used for consistent error signaling, even by the in-memory client.
*   **Key Patterns:**
    *   **Generic Repository Pattern:** `HtDataRepository<T>` provides a type-safe abstraction over data fetching logic. Route handlers interact with repositories, not directly with data clients.
    *   **Generic Data Endpoint:** A single set of route handlers (`/api/v1/data/index.dart`, `/api/v1/data/[id].dart`) serves multiple data models.
    *   **Model Registry:** A central map (`lib/src/registry/model_registry.dart`) links model name strings (from the `?model=` query parameter) to model-specific configurations (`ModelConfig`), primarily containing serialization functions (`fromJson`) and ID extraction logic (`getId`).
    *   **Dependency Injection (Dart Frog Providers):** Middleware (`routes/_middleware.dart`) is used to instantiate and provide singleton instances of each `HtDataRepository<T>` (configured with the in-memory client and fixture data), the `ModelRegistryMap`, and a unique `RequestId` per request. Route-specific middleware (`routes/api/v1/data/_middleware.dart`) resolves the requested model, validates it, and provides the corresponding `ModelConfig` and model name string to the handler.
    *   **Centralized Error Handling:** The `errorHandler` middleware intercepts exceptions (especially `HtHttpException` subtypes and `FormatException`) and maps them to standardized JSON error responses with appropriate HTTP status codes.

## API Endpoint: `/api/v1/data`

This endpoint serves as the single entry point for accessing different data models. The specific model is determined by the `model` query parameter.

**Supported `model` values:** `headline`, `category`, `source`, `country`

**Standard Response Structure:**

*   **Success:**
    ```json
    {
      "data": <item_or_paginated_list>,
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

**Operations:**

1.  **Get All Items (Collection)**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/data?model=<model_name>`
    *   **Optional Query Parameters:**
        *   `limit=<int>`: Limit the number of items returned.
        *   `startAfterId=<string>`: Paginate results, starting after the item with this ID.
        *   *Other query parameters*: Passed directly to the repository's `readAllByQuery` method for filtering (e.g., `?model=headline&category=Technology`).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<PaginatedResponse<T>>`.
    *   **Example:** `GET /api/v1/data?model=headline&limit=10`

2.  **Create Item**
    *   **Method:** `POST`
    *   **Path:** `/api/v1/data?model=<model_name>`
    *   **Request Body:** JSON object representing the item to create (ID is usually omitted if auto-generated).
    *   **Success Response:** `201 Created` with `SuccessApiResponse<T>` containing the created item.
    *   **Example:** `POST /api/v1/data?model=category` with body `{"name": "Sports", "description": "News about sports"}`

3.  **Get Item by ID**
    *   **Method:** `GET`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Success Response:** `200 OK` with `SuccessApiResponse<T>` containing the requested item.
    *   **Error Response:** `404 Not Found` if the ID doesn't exist for the given model.
    *   **Example:** `GET /api/v1/data/some-headline-id?model=headline`

4.  **Update Item by ID**
    *   **Method:** `PUT`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Request Body:** JSON object representing the complete updated item (must include the correct `id`).
    *   **Success Response:** `200 OK` with `SuccessApiResponse<T>` containing the updated item.
    *   **Error Response:** `404 Not Found`, `400 Bad Request` (e.g., ID mismatch).
    *   **Example:** `PUT /api/v1/data/some-category-id?model=category` with updated category JSON in the body.

5.  **Delete Item by ID**
    *   **Method:** `DELETE`
    *   **Path:** `/api/v1/data/<item_id>?model=<model_name>`
    *   **Success Response:** `204 No Content` (No body).
    *   **Error Response:** `404 Not Found`.
    *   **Example:** `DELETE /api/v1/data/some-source-id?model=source`

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
*   Update the coverage badge in this README after tests pass.

## License

This package is licensed under the [PolyForm Free Trial 1.0.0](LICENSE). Please review the terms before use.
