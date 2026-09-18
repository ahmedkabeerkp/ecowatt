# ⚡ EcoWatt

**EcoWatt** is a proactive daily electricity usage monitor and savings tracker focused on helping households in **Kerala** understand, monitor, and reduce their electricity consumption. Built with Flutter and Firebase, it empowers users to take control of their energy consumption before the billing cycle ends.

## 🚨 The Problem
Electricity consumers often know their bill amount only after the billing period ends. This reactive process makes it difficult to understand:
* Which appliances are consuming the most electricity and driving up the cost.
* How daily usage and complex Time-of-Day (TOD) charges affect the overall bill.
* How close the household is to a higher KSEB tariff slab.
* When electricity usage should be shifted away from peak hours.
* How much can potentially be saved by changing usage habits.

## 💡 Project Focus
EcoWatt shifts energy management from reactive to proactive, designed around three main pillars:
* **Monitor** — Track and estimate household electricity consumption using appliance-specific profiles.
* **Understand** — Show daily/weekly consumption patterns, accurate KSEB billing estimates, and AI-driven insights.
* **Save** — Encourage users to shift usage away from peak hours, schedule appliances intelligently, and achieve monthly savings goals.

## ✨ Key Features
* **Hybrid Usage Engine:** Accurately estimates consumption across three distinct appliance types: Always-On, Scheduled, and Occasional with weekend weighting.
* **Smart TOD & Slab Tracking:** Built-in calculation logic for complex telescopic and Time-of-Day billing, specifically tuned for KSEB. Predicts and alerts when nearing higher tariff slabs.
* **AI Energy Insights:** Secure, personalized daily and weekly energy-saving tips powered by Gemini 2.5 via a Vercel serverless backend.
* **Actionable Notifications:** Strict priority-based alerts, including 5:00 PM peak-hour warnings, targeted morning usage tips, and high-power appliance confirmation.
* **Meter Calibration:** Allows users to input actual meter readings across Normal, Off-Peak, and Peak times to continuously auto-correct and improve estimation accuracy.
* **Appliance Cost Calculator:** Instantly calculate the estimated cost of running specific appliances.
* **Gamified Savings:** 7-day savings tracking, monthly goals, badges, and usage streaks to build better habits.

## 🛠 Tech Stack
* **Frontend:** Flutter, Dart, fl_chart, flutter_local_notifications
* **Backend & Auth:** Firebase Authentication, Cloud Firestore
* **AI Proxy:** Node.js on Vercel Serverless Functions calling the Gemini API

## 🌱 Goal
The goal of EcoWatt is to make electricity consumption **visible, understandable, and actionable**, while encouraging users to develop smarter electricity usage habits and reduce avoidable consumption.

> **Use electricity smarter. Save energy. Save money. ⚡🌱**
