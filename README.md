<div align="center">
<img src="https://avatars.githubusercontent.com/u/202675624?s=400&u=2daf23e8872a3b666bcd4f792a21fe2633097e79&v=4" alt="Flutter News App Toolkit Logo" width="220">

# Flutter News App API Server Full Source Code

<p>
<img src="https://img.shields.io/badge/coverage-0%25-green?style=for-the-badge" alt="coverage: 0%">
<a href="https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/"><img src="https://img.shields.io/badge/DOCUMENTATION-READ-slategray?style=for-the-badge" alt="Documentation: Read"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/TRIAL_LICENSE-VIEW_TERMS-blue?style=for-the-badge" alt="Trial License: View Terms"></a>
<a href="https://github.com/sponsors/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/LIFETIME_LICENSE-PURCHASE-purple?style=for-the-badge" alt="Lifetime License: Purchase"></a>
</p>
</div>

This repository contains the complete, production-ready source code for the backend API server that powers the entire Flutter News App ecosystem. Built with the high-performance Dart Frog framework, it gives you all the server-side features you need, right out of the box. It is the core component of the [**Flutter News App - Full Source Code Toolkit**](https://github.com/flutter-news-app-full-source-code), serving the Flutter [mobile app](https://github.com/flutter-news-app-full-source-code/flutter-news-app-mobile-client-full-source-code) and the web-based [content dashboard](https://github.com/flutter-news-app-full-source-code/flutter-news-app-web-dashboard-full-source-code).

## ⭐ Everything You Get, Ready to Go

This API server comes packed with all the features you need to launch a professional, scalable news application.

#### 🔐 **Robust & Flexible Authentication**
*   Provides secure, modern authentication flows, including passwordless email sign-in and anonymous guest accounts.
*   Intelligently handles converting guest users to permanent accounts, preserving all their settings and saved content.
*   Includes a separate, role-aware login flow for privileged dashboard users.
> **Your Advantage:** You get a complete, secure authentication system without the complexity. All the user management logic is done for you. ✅

#### ⚡️ **Granular Role-Based Access Control (RBAC)**
*   Implement precise permissions with a dual-role system: `appRole` for mobile app features and `dashboardRole` for admin functions.
*   Securely control access to API features and data management capabilities based on user roles.
> **Your Advantage:** A powerful, built-in security model that protects your data and ensures users only access what they're supposed to. 🛡️

#### 🛡️ **Built-in API Rate Limiting**
*   Protects critical endpoints like email verification and data access from abuse and denial-of-service attacks.
*   Features configurable, user-aware limits that distinguish between guests and authenticated users.
*   Includes a bypass for trusted roles (admin, publisher) to ensure dashboard functionality is never impeded.
> **Your Advantage:** Your API is protected from day one against common abuse vectors, ensuring stability and preventing costly overages on services like email providers. ✅

#### ⚙️ **Centralized App & User Settings**
*   Effortlessly sync user-specific settings like theme, language, and font styles across devices.
*   Manage personalized content preferences, including saved headlines and followed topics/sources.
> **Your Advantage:** Deliver a seamless, personalized experience that keeps users' settings in sync, boosting engagement and retention. ❤️

#### 💾 **Robust Data Management API**
*   Securely manage all your core news data, including headlines, topics, sources, and countries.
*   The API supports flexible querying, filtering, and sorting, allowing your app to display dynamic content feeds.
> **Your Advantage:** A powerful and secure data backend that's ready to scale with your content needs. 📈

#### 🌐 **Dynamic Remote Configuration**
*   Centrally manage your app's behavior without shipping an update.
*   Control ad frequency, feature flags, force-update prompts, and maintenance status directly from the server.
> **Your Advantage:** Adapt your app on the fly, run experiments, and respond to issues instantly, giving you maximum operational control. 🕹️

#### 📊 **Real-Time Dashboard Analytics**
*   Access real-time, aggregated metrics on key data points like total headlines, topics, and sources.
*   Provides an at-a-glance overview perfect for administrative dashboards.
> **Your Advantage:** Instantly feed your content dashboard with the data it needs to provide valuable insights. 🎯

#### 🏗️ **Clean & Modern Architecture**
*   Built with Dart and the high-performance Dart Frog framework.
*   Features a clean, layered architecture with standardized API responses and built-in dependency injection.
> **Your Advantage:** A solid, maintainable codebase that's easy to understand, extend, and build upon. 🔧

---

## 🔑 License: Source-Available with a Free Trial

Get started for free and purchase when you're ready to launch!

*   **TRY IT:** Download and explore the full source code under the PolyForm Free Trial [license](LICENSE). Perfect for evaluation.
*   **BUY IT:** One-time payment for a lifetime license to publish unlimited commercial apps.
*   **GET YOURS:** [**Purchase via GitHub Sponsors**](https://github.com/sponsors/flutter-news-app-full-source-code).

> [!NOTE]
> *A single purchase provides a commercial license for every repository within the [Flutter News App - Full Source Code Toolkit](https://github.com/flutter-news-app-full-source-code). No other purchases are needed..*

---

## 🚀 Getting Started & Running Locally

For a complete guide on setting up your local environment, running the server, and understanding the configuration, please see the **[Local Setup Guide](https://flutter-news-app-full-source-code.github.io/docs/api-server/local-setup/)** in our official documentation.

Our documentation provides a detailed, step-by-step walkthrough to get you up and running smoothly.

---

## ✅ Testing

This project aims for high test coverage to ensure quality and reliability.

*   Run tests with:
    ```bash
    very_good test --min-coverage 90
