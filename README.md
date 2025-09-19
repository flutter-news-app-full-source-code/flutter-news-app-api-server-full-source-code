<div align="center">
  <img src="https://avatars.githubusercontent.com/u/202675624?s=400&u=2daf23e8872a3b666bcd4f792a21fe2633097e79&v=4" alt="Flutter News App Toolkit Logo" width="220">
  <h1>Flutter News App API Server</h1>
  <p><strong>Complete, production-ready source code for a Flutter news app api server.</strong></p>
</div>

<p align="center">
<img src="https://img.shields.io/badge/coverage-0%25-green?style=for-the-badge" alt="coverage: 0%">
<a href="https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/"><img src="https://img.shields.io/badge/DOCUMENTATION-READ-slategray?style=for-the-badge" alt="Documentation: Read"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/TRIAL_LICENSE-VIEW_TERMS-blue?style=for-the-badge" alt="Trial License: View Terms"></a>
<a href="https://github.com/sponsors/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/LIFETIME_LICENSE-PURCHASE-purple?style=for-the-badge" alt="Lifetime License: Purchase"></a>
</p>

This repository contains the complete, production-ready source code for a robust Flutter news app api server that powers the entire Flutter News App toolkit. Built with the high-performance **Dart Frog** framework, it gives you all the server-side features you need, right out of the box. It is the core component of the [**Flutter News App Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code), serving the Flutter [mobile app](https://github.com/flutter-news-app-full-source-code/flutter-news-app-mobile-client-full-source-code) and the web-based [content dashboard](https://github.com/flutter-news-app-full-source-code/flutter-news-app-web-dashboard-full-source-code).

## ⭐ Feature Showcase: Everything You Get, Ready to Go

This API server comes packed with all the backend features you need to launch a professional and scalable news application.

Click on any category to explore.

<details>
<summary><strong>🔐 Identity & Access Management</strong></summary>

### 📧 Passwordless & Anonymous Authentication
- **Modern Flows:** Implements secure, passwordless email + code sign-in and allows users to start with anonymous guest accounts.
- **Seamless Account Linking:** Intelligently converts guest users to permanent accounts upon sign-up, migrating all their data (preferences, saved items) automatically.
> **Your Advantage:** You get a modern, frictionless, and secure user onboarding experience that reduces user friction and encourages sign-ups.

---

### 🛡️ Secure Session Management
- **JWT-Powered:** Uses industry-standard JSON Web Tokens (JWTs) for robust and stateless session management.
- **Instant Session Invalidation:** A token blacklisting service ensures that when a user signs out, their session is immediately and securely terminated.
> **Your Advantage:** Deliver a highly secure authentication system that protects user data and gives you full control over sessions.

---

### 👮 Granular Role-Based Access Control (RBAC)
- **Permission-Driven:** A flexible RBAC system controls what users can do based on their assigned roles (`AppUserRole`, `DashboardUserRole`).
- **Ownership Verification:** Built-in middleware automatically checks if a user owns a piece of data before allowing them to modify or delete it.
> **Your Advantage:** Easily enforce complex business rules and security policies, ensuring users can only access and manage the data they are supposed to.

---

### 🚦 API Abuse Prevention
- **Smart Rate Limiting:** Protects critical endpoints like `request-code` and the main data API from brute-force attacks, spam, and denial-of-service attempts.
- **IP & User-Based:** Applies rate limits based on IP for anonymous users and by user ID for authenticated users, providing fair and effective protection.
> **Your Advantage:** Your API is shielded from common threats, ensuring high availability and stability for your legitimate users.

</details>

<details>
<summary><strong>📦 Dynamic Content & Data API</strong></summary>

### ⚙️ Generic & Extensible Data API
- **Unified Endpoint Design:** A single, powerful set of RESTful endpoints (`/api/v1/data`) handles all CRUD operations for every data model in the system, driven by a `?model=` query parameter.
- **Registry-Based Architecture:** The API's extensibility is powered by two core components:
    - **`ModelRegistry`**: Maps a model name (e.g., `"headline"`) to a `ModelConfig` that defines its metadata: how to deserialize it from JSON, how to extract its ID, and the specific authorization rules for every action (Create, Read, Update, Delete).
    - **`DataOperationRegistry`**: Maps the same model name to the concrete functions that perform the CRUD operations, connecting the generic route to the specific `DataRepository<T>` for that model.
- **How to Add a New Model:** To add a new data type, you simply register its configuration in these two central registries. The generic middleware and route handlers automatically enforce its permissions and execute its data operations without requiring new routes or custom logic.
> **Your Advantage:** This architecture is incredibly easy to maintain and extend. Adding new data types to your application is fast, consistent, and requires minimal code, dramatically speeding up development.

---

### 🔍 Advanced Querying & Pagination
- **Rich Filtering:** Supports complex, MongoDB-style filtering directly through the API.
- **Flexible Sorting & Pagination:** Allows for multi-field sorting and efficient cursor-based pagination to handle large datasets.
> **Your Advantage:** Enable powerful, high-performance content discovery features in your client applications (like filtering, sorting, and infinite scrolling) with no extra backend work.

</details>

<details>
<summary><strong>🏗️ Architecture & Infrastructure</strong></summary>

### 🚀 High-Performance Dart Frog Core
- **Modern & Fast:** Built on Dart Frog, a minimalist and extremely fast backend framework from the creators of Very Good Ventures, ensuring excellent performance and low latency.
> **Your Advantage:** Your backend is built on a solid, modern foundation that is both powerful and easy to work with.

---

### 🧱 Clean, Layered Architecture
- **Separation of Concerns:** Strictly follows a layered architecture (Data Clients, Repositories, Services) that is clean, maintainable, and scalable.
- **Standardized Responses:** Consistent JSON response structures for both success and error scenarios make client-side handling predictable and simple.
> **Your Advantage:** You get a codebase that is easy to understand, modify, and extend, saving you significant development and maintenance time.

---

### 🔌 Robust Dependency Injection
- **Testable & Modular:** A centralized dependency injection system makes the entire application highly modular and easy to test.
- **Swappable Implementations:** Easily swap out core components—like the database (MongoDB), email provider (SendGrid), or storage services—without rewriting your business logic.
> **Your Advantage:** The architecture is not locked into specific services. You have the freedom to adapt and evolve your tech stack as your needs change.

---

### ⚙️ Secure Environment Configuration
- **Secure & Flexible:** Manages all sensitive keys, API credentials, and environment-specific settings through a `.env` file, keeping your secrets out of the codebase.
> **Your Advantage:** Deploy your application across different environments (local, staging, production) safely and efficiently.

</details>

## 🔑 License: Source-Available with a Free Trial

Get started for free and purchase when you're ready to launch!

- **TRY IT:** Download and explore the full source code under the PolyForm Free Trial [license](LICENSE). Perfect for evaluation.
- **BUY IT:** One-time payment for a lifetime license to publish unlimited commercial apps.
- **GET YOURS:** [**Purchase via GitHub Sponsors**](https://github.com/sponsors/flutter-news-app-full-source-code).

> A single purchase provides a commercial license for every repository within the [Flutter News App Full Source Code Toolkit](https://github.com/flutter-news-app-full-source-code). No other purchases are needed.

## 🚀 Getting Started & Running Locally

For a complete guide on setting up your local environment, running the server, and understanding the configuration, please see the **[Local Setup Guide](https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/)** in our official documentation.

Our documentation provides a detailed, step-by-step walkthrough to get you up and running smoothly.
