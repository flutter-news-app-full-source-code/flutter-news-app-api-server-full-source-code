# ht_api (Headlines Toolkit API)

![coverage: percentage](https://img.shields.io/badge/coverage-100-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

## Overview

`ht_api` is the backend API component of the **Headlines Toolkit (HT)** project. Built with Dart Frog, it serves data and functionality to the corresponding HT Flutter mobile application and Flutter web dashboard. Currently, its primary focus is managing country-related data via the `ht_countries_client` package.

## Features

### Current

*   **🏠 API v1 Root:** Provides a base endpoint for API version 1 (`GET /api/v1/`).

*   **🌍 Country Endpoints (`/api/v1/countries`)**
    *   📜 **List All:** Retrieve a list of all available countries (`GET`).
    *   🔍 **Get by ISO Code:** Retrieve details for a specific country (`GET /{isoCode}`).
    *   ➕ **Create:** Add a new country (`POST`).
    *   🔄 **Update:** Modify an existing country (`PUT` or `PATCH /{isoCode}`).
    *   🗑️ **Delete:** Remove a country (`DELETE /{isoCode}`).

### Planned

*   (No specific planned features identified yet - can be updated as needed)

## Technical Overview

*   **Language:** Dart
*   **Framework:** Dart Frog
*   **Architecture:** Follows standard Dart Frog structure with route-based handlers and middleware. Uses dependency injection to provide the `HtCountriesClient`. Part of the larger Headlines Toolkit ecosystem.
*   **Key Libraries/Packages:**
    *   `dart_frog`: Core backend framework.
    *   `ht_countries_client`: Shared package used as the data source for country information.
    *   `very_good_analysis`: Linting rules.
*   **Error Handling:** Centralized error handling middleware is implemented.

## Setup & Running

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/headlines-toolkit/ht-api
    cd ht_api
    ```
2.  **Get dependencies:**
    ```bash
    dart pub get
    ```
3.  **Run the development server:**
    ```bash
    dart_frog dev
    ```
    The API will typically be available at `http://localhost:8080`.

## License

This package is licensed under the [PolyForm Free Trial](LICENSE). Please review the terms before use.
