<div align="center">
<img src="https://avatars.githubusercontent.com/u/202675624?s=400&u=2daf23e8872a3b666bcd4f792a21fe2633097e79&v=4" alt="Flutter News App Toolkit Logo" width="220">

# Flutter News App - API Server Full Source Code

<p>
<img src="https://img.shields.io/badge/coverage-XX-green?style=for-the-badge" alt="coverage: percentage">
<a href="https://github.com/sponsors/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/DOCS-READ-purple?style=for-the-badge" alt="DOCS READ"></a>
<a href="https://github.com/sponsors/flutter-news-app-full-source-code"><img src="https://img.shields.io/badge/LICENSE-BUY-pink?style=for-the-badge" alt="License: Buy"></a>
</p>
</div>

This is the complete and fully-functional backend API server for the Flutter News App Toolkit. Built with the high-performance Dart Frog framework, it gives you all the server-side features you need to power your news app, right out of the box. It is a key component of the [**Flutter News App Toolkit**](https://github.com/flutter-news-app-full-source-code), an ecosystem that also includes a flutter [mobile app](https://github.com/flutter-news-app-full-source-code/flutter-news-app-mobile-client-full-source-code) and a web-based [content dashboard](https://github.com/flutter-news-app-full-source-code/flutter-news-app-web-dashboard-full-source-code).

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
*   **BUY IT:** Get an unlimited commercial lifetime license with a **one-time payment**. No subscriptions!
*   **GET YOURS:** [**Purchase via GitHub Sponsors**](https://github.com/sponsors/flutter-news-app-full-source-code).

> *<p style="color:grey">Note: The single purchase provides a comprehensive commercial license covering every repository within the [Flutter News App Toolkit](https://github.com/flutter-news-app-full-source-code) organization. No separate purchases are needed for the mobile app or dashboard.</p>*

---

## 🚀 Getting Started & Running Locally

1.  **Prerequisites:**
    *   Dart SDK (`>=3.0.0`)
    *   MongoDB (`>=5.0` recommended)
    *   Dart Frog CLI (`dart pub global activate dart_frog_cli`)

2.  **Clone the repository:**
    ```bash
    git clone https://github.com/flutter-news-app-full-source-code/flutter-news-app-api-server-full-source-code.git
    cd flutter-news-app-api-server-full-source-code
    ```

3.  **Configure your environment:**
    Copy the `.env.example` file to a new file named `.env`:
    ```bash
    cp .env.example .env
    ```
    Then, open the new `.env` file and update the variables with your actual configuration values (e.g., `DATABASE_URL`).

4.  **Get dependencies:**
    ```bash
    dart pub get
    ```

5.  **Run the development server:**
    ```bash
    dart_frog dev
    ```
    The API will be available at `http://localhost:8080`. On startup, the server will connect to your MongoDB database and seed it with initial data. This process is idempotent, so it can be run multiple times without creating duplicates.

---

## ✅ Testing

This project aims for high test coverage to ensure quality and reliability.

*   Run tests with:
    ```bash
    very_good test --min-coverage 90
