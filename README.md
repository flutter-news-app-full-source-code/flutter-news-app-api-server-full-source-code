# ht_api

![coverage: percentage](https://img.shields.io/badge/coverage-XX-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

🚀 Accelerate the development of your news application backend with **ht_api**, the
dedicated API service for the Headlines Toolkit. Built on the high-performance
Dart Frog framework, `ht_api` provides the essential server-side infrastructure
specifically designed to power robust and feature-rich news applications.

`ht_api` is a core component of the **Headlines Toolkit**, a comprehensive,
source-available ecosystem designed for building feature-rich news
applications, which also includes a Flutter mobile app and a web-based content
management dashboard.

## ✨ Key Capabilities

*   🔒 **Effortless User Authentication:** Provide secure and seamless user access
    with flexible flows including passwordless sign-in, anonymous access, and
    the ability to easily link anonymous accounts to permanent ones. Focus on
    user experience while `ht_api` handles the security complexities.

*   ⚙️ **Synchronized App Settings:** Ensure a consistent and personalized user
    experience across devices by effortlessly syncing application preferences
    like theme, language, font styles, and more.

*   👤 **Personalized User Preferences:** Enable richer user interactions by
    managing and syncing user-specific data such as saved headlines, search
    history, or other personalized content tailored to individual users.

*   💾 **Robust Data Management:** Securely manage core news application data,
    including headlines, categories, and sources, through a well-structured
    and protected API.

*   🔧 **Solid Technical Foundation:** Built with Dart and the high-performance
    Dart Frog framework, offering a maintainable codebase, standardized API
    responses, and built-in access control for developers.

## 🔌 API Endpoints

`ht_api` provides a clear and organized API surface under the `/api/v1/` path.
Key endpoint groups cover authentication, data access, and user settings.

For complete API specifications, detailed endpoint documentation,
request/response schemas, and error codes, please refer to the dedicated
documentation website [todo:Link to the docs website].

## 🔑 Access and Licensing

`ht_api` is source-available as part of the Headlines Toolkit ecosystem.

The source code for `ht_api` is available for review as part of the Headlines
Toolkit ecosystem. To acquire a commercial license for building unlimited news
applications with the Headlines Toolkit repositories, please visit the
[Headlines Toolkit GitHub organization page](https://github.com/headlines-toolkit)
for more details.

## 💻 Setup & Running

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
    The API will typically be available at `http://localhost:8080`. Fixture data
    from `lib/src/fixtures/` will be loaded into the in-memory repositories on
    startup.

## ✅ Testing

Ensure the API is robust and meets quality standards by running the test suite:

```bash
# Ensure very_good_cli is activated: dart pub global activate very_good_cli
very_good test --min-coverage 90
```

Aim for a minimum of 90% line coverage.

## 📄 License

This package is licensed under the [PolyForm Free Trial](LICENSE). Please review the terms before use.
