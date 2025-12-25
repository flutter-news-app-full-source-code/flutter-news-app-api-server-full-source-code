<div align="center">
  <img src="https://repository-images.githubusercontent.com/946589707/1ee61062-ded3-44f9-bb6d-c35cd03b5d64" alt="Flutter News App Toolkit Mockup" width="440">
  <h1>Flutter News App API Server</h1>
  <p><strong>Complete, production-ready source code for a Flutter news app api server.</strong></p>
</div>

<p align="center">
<img src="https://img.shields.io/badge/coverage-53%25-green?style=for-the-badge" alt="coverage">
<a href="https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/"><img src="https://img.shields.io/badge/DOCUMENTATION-READ-slategray?style=for-the-badge" alt="Documentation: Read"></a>
</p>
<p align="center">
<a href="LICENSE"><img src="https://img.shields.io/badge/TRIAL_LICENSE-VIEW_TERMS-blue?style=for-the-badge" alt="Trial License: View Terms"></a>
<a href="https://github.com/sponsors/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/LIFETIME_LICENSE-PURCHASE-purple?style=for-the-badge" alt="Lifetime License: Purchase"></a>
</p>

This repository contains the complete, production-ready source code for a high-performance Flutter news app api server that powers the entire Flutter News App toolkit. Built with the high-performance **Dart Frog** framework, it gives you all the server-side features you need, right out of the box. It is the core component of the [**Flutter News App Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code), serving the Flutter [mobile app](https://github.com/flutter-news-app-full-source-code/flutter-news-app-mobile-client-full-source-code) and the web-based [content dashboard](https://github.com/flutter-news-app-full-source-code/flutter-news-app-web-dashboard-full-source-code).

## ⭐ Feature Showcase: Everything You Get, Ready to Go

This API is the powerful, secure, and scalable core of the entire news toolkit. Built on a high-performance Dart Frog foundation, it provides a complete backend solution designed for maintainability and rapid development.

Explore the high-level domains below to see how.

<details>
<summary><strong>🔐 Identity & Access Management</strong></summary>

### 🛡️ Modern, Secure Authentication
A complete identity system provides a frictionless and secure user journey from the very first interaction.
- **Flexible Onboarding:** Supports modern, passwordless sign-in for registered users and seamless anonymous access for guests, reducing barriers to entry.
- **Intelligent Account Conversion:** Automatically migrates all user data—including preferences and saved content—when a guest user creates a permanent account.
- **Robust Session Control:** Uses industry-standard JWTs for stateless sessions and includes a token blacklisting service to ensure sessions are instantly and securely terminated upon sign-out.
> **Your Advantage:** You get a complete, modern, and secure user management system out of the box, covering the entire user lifecycle from guest to registered user.

---

### 👮 Granular, Role-Based Security
A sophisticated and flexible security model ensures that users and administrators can only access and modify the data they are permitted to.
- **Multi-Layered Access Control:** Defines distinct permission sets for different user classes, such as mobile app consumers and dashboard administrators, ensuring a clear separation of capabilities.
- **Automated Ownership Enforcement:** Built-in middleware automatically verifies data ownership before any modification or deletion request is processed, preventing unauthorized actions.
> **Your Advantage:** Easily enforce complex business rules and security policies. The architecture guarantees data integrity and provides a secure foundation for scaling your user base.

---

### 🚦 Automated API Protection
The API is shielded from common threats with intelligent, built-in abuse prevention mechanisms.
- **Smart Rate Limiting:** Protects critical endpoints from brute-force attacks and denial-of-service attempts by applying fair and effective limits based on IP address for guests and user ID for authenticated users.
> **Your Advantage:** Ensure high availability and stability for your application. This automated defense layer protects your infrastructure and preserves a quality experience for legitimate users.

</details>

<details>
<summary><strong>📦 Dynamic Content & Data API</strong></summary>

### ⚙️ A Radically Efficient Data Engine
Instead of a rigid collection of hardcoded routes, the API is built around a single, unified data gateway. This metadata-driven architecture dramatically accelerates development and enhances scalability.
- **Unified Data Endpoint:** A central engine handles all data operations (CRUD) for every data type in the system—from articles and topics to user preferences and beyond.
- **Metadata-Driven Logic:** To add a completely new data type to your application, you simply define its rules—permissions, validation, and database connections—in a central registry. The engine handles the rest automatically.
> **Your Advantage:** This architecture eliminates boilerplate code and massively speeds up development. You can add new features and data models to your application without writing new API routes, enabling you to innovate and scale at a much faster pace.

---

### 🔍 Advanced Querying & Performance
The data API is equipped with powerful querying capabilities, enabling rich, high-performance content discovery features in your client applications.
- **Complex Filtering & Sorting:** Supports deep, multi-parameter filtering and flexible, multi-field sorting directly through the API.
- **High-Performance Pagination:** Utilizes efficient cursor-based pagination to handle massive datasets gracefully, perfect for infinite-scrolling feeds.
> **Your Advantage:** Empower your mobile and web clients with powerful data discovery features right out of the box, without needing to write any extra backend logic.

---

### 🛡️ Robust & Automated Validation
The API automatically validates the structure of all incoming data, ensuring that every request is well-formed before it's processed. This built-in mechanism catches missing fields, incorrect data types, and invalid enum values at the gateway, providing clear, immediate feedback to the client.
> **Your Advantage:** This eliminates an entire class of runtime errors and saves you from writing tedious, repetitive validation code. Your data models remain consistent and your API stays resilient against malformed requests.

---
- **Dart Frog Core:** Leverages the high-performance Dart Frog framework for a fast, efficient, and scalable backend.
- **Clean, Layered Architecture:** A strict separation of concerns into distinct layers makes the codebase clean, maintainable, and easy to reason about.
> **Your Advantage:** Your backend is built on a solid, modern foundation that is both powerful and a pleasure to work with, reducing maintenance overhead.

---

### 🔌 Extensible & Unlocked
The entire application is designed with a robust dependency injection system, giving you the freedom to choose your own infrastructure.
- **Swappable Implementations:** Easily swap out core components—like the database, email provider, or file storage service—without rewriting business logic.
> **Your Advantage:** Avoid vendor lock-in and future-proof your application. You have the freedom to adapt and evolve your tech stack as your business needs change.

---

### 🔄 Automated & Traceable Database Migrations
Say goodbye to risky manual database updates. A professional, versioned migration system ensures your database schema evolves safely and automatically.
- **Code-Driven Schema Evolution:** The system automatically applies schema changes to your database on application startup, ensuring consistency across all environments.
- **Traceable to Source:** Each migration is versioned and directly linked to the pull request that initiated it, providing a clear, auditable history of every change.
> **Your Advantage:** Deploy with confidence. This robust system eliminates an entire class of deployment errors, ensuring your data models evolve gracefully and reliably with full traceability.

</details>

<details>
<summary><strong>💰 Monetization & Subscriptions</strong></summary>

### 💳 Robust Subscription Engine
A complete, zero-trust backend infrastructure for managing in-app subscriptions and entitlements.
- **Multi-Provider Support:** Built-in support for Apple App Store, Google Play Store, and Stripe, unified under a single "Entitlement" interface.
- **Zero-Trust Validation:** Every purchase is cryptographically verified directly with Apple and Google servers before any entitlement is granted, eliminating client-side receipt spoofing.
- **Idempotent State Machine:** A dedicated idempotency layer ensures that every transaction and webhook event is processed exactly once, preventing duplicate entitlements or race conditions during network retries.
- **Real-Time Webhook Synchronization:** The system acts as an authoritative source of truth, listening for server-to-server webhooks to instantly reflect renewals, cancellations, and billing issues, ensuring the user's status is always accurate.
- **Type-Safe Integration:** Built with strongly-typed models for all provider interactions, eliminating fragile JSON parsing and ensuring long-term maintainability.
> **Your Advantage:** A secure, compliant, and battle-hardened monetization system that protects your revenue and guarantees a consistent experience for your subscribers.
 
</details>

<details>
<summary><strong>📲 User Engagement & Notifications</strong></summary>

### 🔔 A Dynamic, Multi-Channel Notification Engine
A complete, multi-provider notification engine empowers you to engage users with timely and relevant alerts, seamlessly integrated into their app experience.
- **Editorial-Driven Alerts:** Designate any content as "breaking news" from the dashboard to trigger immediate, high-priority push notifications to all relevant subscribers.
- **User-Crafted Notification Streams:** Allow users to create and save persistent filters based on any combination of content attributes (such as topics or sources) and subscribe to receive notifications that match their exact interests.
- **Centralized In-App Inbox:** Every push notification is automatically captured as a persistent in-app message, giving users a central place to catch up on alerts they may have missed.
- **Provider Agnostic & Scalable:** The engine is built to be provider-agnostic, with out-of-the-box support for Firebase (FCM) and OneSignal. The active provider can be switched remotely without any code changes.
- **Intelligent, Self-Healing Delivery:** The system is designed for long-term efficiency. It automatically detects and prunes invalid device tokens—for example, when a user uninstalls the app—ensuring your delivery infrastructure remains clean and performant.
> **Your Advantage:** Drive user re-engagement with a powerful and flexible notification system that delivers both broad-reaching alerts and deeply personalized content streams, all built on a scalable, self-healing, and provider-agnostic architecture.

</details>

<details>
<summary><strong>📊 Insightful Analytics Engine</strong></summary>

### 📈 A Unified Business Intelligence Engine
A complete, multi-provider analytics engine that transforms raw data from both external services and your own application database into insightful, aggregated metrics for your dashboard.
- **Dual-Source ETL:** A standalone worker process runs on a schedule to perform a full Extract, Transform, and Load (ETL) operation. It pulls behavioral data from your chosen analytics provider (Google Analytics or Mixpanel) and combines it with operational data by running direct, complex aggregations against the application's own database.
- **High-Performance Dashboard:** The web dashboard reads this pre-aggregated data, resulting in near-instant load times for all analytics charts and metrics. This architecture avoids slow, direct, on-the-fly queries from the client to the analytics provider.
- **Provider-Agnostic & Extensible:** The engine is built on a clean, abstract interface, decoupling the core logic from any specific provider. Switch between Google Analytics and Mixpanel with a simple configuration change, or integrate a new provider by implementing a single, well-defined contract. Adding new charts or KPIs is as simple as defining a new metric mapping.
> **Your Advantage:** Get a complete, production-grade BI pipeline out of the box. Deliver a fast, responsive dashboard and gain a holistic view of your business by combining user behavior analytics with real-time operational metrics—a capability that external analytics tools alone cannot provide.

</details>

<details>
<summary><strong>🏗️ Architecture & Infrastructure</strong></summary>

### 🚀 High-Performance by Design
- **Dart Frog Core:** Leverages the high-performance Dart Frog framework for a fast, efficient, and scalable backend.
- **Clean, Layered Architecture:** A strict separation of concerns into distinct layers makes the codebase clean, maintainable, and easy to reason about.
> **Your Advantage:** Your backend is built on a solid, modern foundation that is both powerful and a pleasure to work with, reducing maintenance overhead.

---

### 🔌 Extensible & Unlocked
The entire application is designed with a robust dependency injection system, giving you the freedom to choose your own infrastructure.
- **Swappable Implementations:** Easily swap out core components—like the database, email provider, or file storage service—without rewriting business logic.
> **Your Advantage:** Avoid vendor lock-in and future-proof your application. You have the freedom to adapt and evolve your tech stack as your business needs change.

---

### 🔄 Automated & Traceable Database Migrations
Say goodbye to risky manual database updates. A professional, versioned migration system ensures your database schema evolves safely and automatically.
- **Code-Driven Schema Evolution:** The system automatically applies schema changes to your database on application startup, ensuring consistency across all environments.
- **Traceable to Source:** Each migration is versioned and directly linked to the pull request that initiated it, providing a clear, auditable history of every change.
> **Your Advantage:** Deploy with confidence. This robust system eliminates an entire class of deployment errors, ensuring your data models evolve gracefully and reliably with full traceability.

</details>

## 🔑 Licensing
This `Flutter News App API Server` package is an integral part of the [**Flutter News App Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code). For comprehensive details regarding licensing, including trial and commercial options for the entire toolkit, please refer to the main toolkit organization page.

## 🚀 Getting Started & Running Locally
For a complete guide on setting up your local environment, running the server, and understanding the configuration, please see the **[Local Setup Guide](https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/)** in our official documentation.