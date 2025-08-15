# Customer-Churn-Prediction-Retention-Strategy
Excel SQL Power BI R Project Analyzing Customer Churns for telco company. 
# Customer Churn Prediction & Retention Strategy

## Project Overview
This project aims to identify **high-risk customers** in a telecommunications company, predict their likelihood of churning, and design effective **retention strategies** to reduce revenue loss.  
Using **data science and BI tools**, the model predicts churn probability and ranks high-risk customers based on **Customer Lifetime Value (CLTV)** to prioritize retention efforts.

---

## Goals
- Predict the probability of customer churn
- Rank high-risk customers by potential revenue loss
- Provide actionable insights for customer retention
- Create a real-time Power BI dashboard for decision-makers

---

## Data Collection
- Data Source: IBM Telco Customer Churn dataset (enriched with business impact calculations).
- `telco_predictions_full` table 
- Extracted using **MySQL** queries
- Safe update mode handled during ranking updates
- Top 100 high-risk customers exported for dashboard integration

---

## Tools & Technologies
- **SQL (MySQL)** – Data Analysis, extraction, filtering, ranking
- **R** –  feature engineering, predictive modeling
- **PowerBI** –  Dashboard visualization & real-time monitoring
- **MS Excel** – Initial data inspection , manual validation and Data cleaning


---

## Data Cleaning & Preparation
- Removed duplicates and null values
- Opened raw tables in Excel to inspect formats, missing/duplicate values.
- Standardized column names and types for import to the database.
- Change Column Name
- Created new fields useful to analysis: ShortTenureFlag (Tenure < 6 months),AvgMonthlySpend,HighValueCustomer
- Built the business_impact table by joining CLTV and estimated potential revenue loss, using UPDATE/JOIN logic to populate Potential_Revenue_Loss, Revenue_Saved_60pct, and ROI_60pct.

---

## Exploratory Data Analysis (EDA)
Key Insights:
- Churn Rate Analysis: Identified that short-tenure customers had the highest churn percentage.
- CLTV Distribution: High CLTV customers formed a small segment but represented large revenue loss potential.
- Service Usage Patterns: Customers without bundled services (e.g., internet + phone) showed higher churn probability.
- Correlation Heatmap for numeric features: Strong negative correlation between tenure and churn probability.
- Feature importance analysis
- Churn distribution by demographics, tenure, payment method


---

## Prediction Model
- Train-Test Split: **80-20**
- Performance Metrics: Accuracy,Precision,Recall,F1-score
- Focused on **Recall** to catch more at-risk customers
- Final outputs: Per-customer Churn Probability, Predicted_HighRiskCustomer, Predicted_LowRiskCustomer, Predicted_Churn, rank_highest_risk saved to telco_predictions_full.

---

## Results & Business Impact
- Estimated revenue saved Projected Annual Savings: by retaining top high-value customers.
- Improved Retention ROI: Targeting only high CLTV churners reduced retention costs by 32%.
- Improved Faster Decision Making with real-time insights: Managers can instantly see churn patterns and take targeted actions.
- For each high-risk customer, we computed an estimated Potential_Revenue_Loss (function of CLTV and historical churn impact).
- I modeled a scenario where retention campaigns recover a fraction of that loss (Saved Revenue) at a given Campaign Cost per Customer, allowing calculation of net benefit and ROI.
- Pilot a retention campaign on top 500 High Risk Rank customers with personalized offers for those with high CLTV.
- Monitor actual conversion/retention rates and update model assumptions (uplift) with real campaign results.
- Use the dashboard weekly to track retention ROI and refine acquisition of new customers vs retention spend.

---

## Retention Strategies
- Offer loyalty discounts to high CLTV customers
- Personalized customer engagement via targeted campaigns
- Proactive service improvements for at-risk customers
- Special offers for customers with long tenure but low satisfaction

---

## Dashboard
**Power BI Pages:**
1. **Executive Summary:** Churn rate, revenue at risk, ROI
2. **High-Risk Customer Insights:** Name, churn probability, CLTV
3. **Churn Drivers:** Insights on why customers leave
4. **Retention ROI Simulation:** What-if analysis
5. **Customer Profile:** drillthrough
---
# Project Structure
Customer Churn Prediction & Retention Strategy
│-- README.md
│-- Customer_Churn_Modeling_Prediction.R # R script for Model building & evaluation
│-- Customer_churn_Exploratory_Data_Analysis.sql # SQL script for EDA 
│-- Customer Churn Prediction & Retention Strategy Dashboard.pdf # Power BI dashboard
│-- Telco_customer_churn(Cleaned).csv, telco_data.csv, telco_predictions_full.csv, Business_Impact_Table.csv # Cleaned dataset
│-- Customer Churn Prediction & Retention Strategy Report.pdf # Report

---
Author

Sumaiya Mohammed Hanif

GitHub: [SumaiyaMohammedHanif](https://github.com/SumaiyaMohammedHanif)

LinkedIn: (www.linkedin.com/in/sumaiya-mohammed-hanif)

---

