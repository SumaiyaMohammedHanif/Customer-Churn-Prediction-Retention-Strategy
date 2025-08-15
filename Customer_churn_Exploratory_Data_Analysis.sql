USE telco_churn;
SELECT COUNT(*) FROM telco_data;
SELECT * FROM telco_data LIMIT 5;
SELECT * FROM telco_data LIMIT 10;
SELECT CustomerID FROM telco_data LIMIT 5;
ALTER TABLE telco_data 
CHANGE COLUMN `ï»¿CustomerID` CustomerID VARCHAR(50);
SELECT CustomerID, COUNT(*) 
FROM telco_data
GROUP BY CustomerID
HAVING COUNT(*) > 1;
SELECT Churn_Label, COUNT(*) AS total
FROM telco_data
GROUP BY Churn_Label;
SELECT ROUND(AVG(Monthly_Charges), 2) AS avg_monthly_charges
FROM telco_data;
SELECT 
    MIN(Tenure_Months) AS min_tenure, 
    MAX(Tenure_Months) AS max_tenure, 
    ROUND(AVG(Tenure_Months), 1) AS avg_tenure
FROM telco_data;
SELECT 
    ROUND(
        SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        2
    ) AS churn_rate_percentage
FROM telco_data;
SELECT 
    ROUND(SUM(Monthly_Charges) / COUNT(*), 2) AS avg_revenue_per_customer,
    ROUND(SUM(CASE WHEN Churn_Label = 'Yes' THEN Monthly_Charges ELSE 0 END), 2) AS total_monthly_revenue_lost
FROM telco_data;
SELECT COUNT(*) AS total_customers,
       AVG(Churn_Value) AS churn_rate,
       AVG(Monthly_Charges) AS avg_charge
FROM telco_data;
SELECT Contract, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM telco_data
GROUP BY Contract
ORDER BY churn_rate_percentage DESC;
SELECT Payment_Method, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM telco_data
GROUP BY Payment_Method
ORDER BY churn_rate_percentage DESC;
SELECT Senior_Citizen, 
       COUNT(*) AS total_customers,
       SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
       ROUND(SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_percentage
FROM telco_data
GROUP BY Senior_Citizen;
SELECT Internet_Service, 
       ROUND(100.0 * SUM(CASE WHEN Churn_Label = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate
FROM telco_data
GROUP BY Internet_Service
ORDER BY churn_rate DESC;

ALTER TABLE telco_data ADD COLUMN AvgMonthlySpend DECIMAL(10,2);
UPDATE telco_data 
SET AvgMonthlySpend = TotalCharges / NULLIF(tenure, 0);

ALTER TABLE telco_data ADD COLUMN HighValueCustomer VARCHAR(3);
UPDATE telco_data 
SET HighValueCustomer = CASE 
    WHEN CLTV > 5000 THEN 'Yes' ELSE 'No' END;  -- Adjust threshold

ALTER TABLE telco_data ADD COLUMN ShortTenureFlag VARCHAR(3);
UPDATE telco_data 
SET ShortTenureFlag = CASE 
    WHEN tenure < 12 THEN 'Yes' ELSE 'No' END;

SELECT * FROM telco_churn.telco_data;
SHOW DATABASES;
SELECT SCHEMA_NAME 
FROM INFORMATION_SCHEMA.SCHEMATA;
SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

SHOW COLUMNS FROM telco_data;
SHOW COLUMNS FROM telco_predictions;
##Merge predictions into main customer table/##Predicted_HighRiskCustomer flag/##Predicted_LowRiskCustomer flag
CREATE TABLE telco_predictions_full AS
SELECT 
    d.CustomerID,
    d.Monthly_Charges,
    d.Tenure_Months,
    COALESCE(d.CLTV, d.Monthly_Charges * d.Tenure_Months) AS CLTV,
    p.Churn_Prob,
    p.Predicted_Churn,
    CASE WHEN p.Predicted_Churn = 'Yes' THEN 'Yes' ELSE 'No' END AS Predicted_Churn_Flag,
    CASE WHEN p.Predicted_Churn = 'Yes' THEN 1 ELSE 0 END AS Predicted_HighRiskCustomer,
    CASE WHEN p.Predicted_Churn = 'No' THEN 1 ELSE 0 END AS Predicted_LowRiskCustomer
FROM telco_data d
JOIN telco_predictions p
    ON d.CustomerID = p.CustomerID;
SELECT Predicted_Churn, COUNT(*) AS total
FROM telco_predictions
GROUP BY Predicted_Churn;

SET SQL_SAFE_UPDATES = 0;
##Rank high-risk customers by CLTV
ALTER TABLE telco_predictions_full ADD rank_highest_risk INT;

SET @rank = 0;
UPDATE telco_predictions_full
SET rank_highest_risk = (@rank := @rank + 1)
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC;
SELECT CustomerID, CLTV, Churn_Prob, Predicted_Churn
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC;
##Calculate potential revenue loss
SELECT 
    SUM(CLTV) AS potential_revenue_loss
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1;
##Calculate ROI if you save a % of them  Save 60% of high-risk customers, campaign cost ₹50,000.
SELECT 
    SUM(CLTV) AS total_loss_if_churn,
    SUM(CLTV) * 0.60 AS revenue_saved,
    (SUM(CLTV) * 0.60 - 50000) / 50000 * 100 AS roi_percent
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1;
SELECT 
    SUM(CLTV) * 0.30 AS Revenue_Saved,
    (SUM(CLTV) * 0.30) - (SUM(CLTV) * 0.30 * 0.10) AS ROI_Estimate -- assuming 10% cost of retention campaigns
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1;
SET SQL_SAFE_UPDATES = 1;
## Save top 100 high-risk customers to CSV for Power BI
SELECT *
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC
LIMIT 100
INTO OUTFILE 'C:/Users/Admin/Documents/Data Analyst Project/Customer Churn Prediction & Retention Strategy/top_100_high_risk.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';
SHOW VARIABLES LIKE 'secure_file_priv';
## Save top 100 high-risk customers to CSV for Power BI
SELECT *
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC
LIMIT 100
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/top_100_high_risk.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';
SELECT CustomerID, CLTV, Churn_Prob, Predicted_Churn
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC
LIMIT 100
INTO OUTFILE '/var/lib/mysql-files/top_100_high_risk.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

ALTER TABLE telco_data ADD COLUMN Churn_Probs DECIMAL(5,4);

ALTER TABLE telco_data 
ADD COLUMN Predicted_Churn TINYINT(1),
ADD COLUMN Predicted_LowRiskCustomer TINYINT(1);

UPDATE telco_data d
JOIN telco_predictions p ON d.CustomerID = p.CustomerID
SET d.Churn_Prob = p.Churn_Prob
WHERE d.CustomerID IS NOT NULL;

SET GLOBAL net_read_timeout = 600;
SET GLOBAL net_write_timeout = 600;
SET GLOBAL wait_timeout = 600;

ALTER TABLE telco_data ADD INDEX idx_customerid (CustomerID);
ALTER TABLE telco_predictions_full ADD INDEX idx_customerid (CustomerID);

SET @batch_size = 5000;
SET @offset = 0;

SELECT COUNT(*) FROM telco_data;
UPDATE telco_data d
JOIN (
    SELECT CustomerID, Churn_Prob, Predicted_Churn
    FROM telco_predictions_full
    ORDER BY CustomerID
    LIMIT 5000 OFFSET 0
) p ON d.CustomerID = p.CustomerID
SET 
    d.Churn_Prob = p.Churn_Prob,
    d.Predicted_Churn = CASE WHEN p.Predicted_Churn = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_HighRiskCustomer = CASE WHEN p.Predicted_Churn = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_LowRiskCustomer = CASE WHEN p.Predicted_Churn = 'No' THEN 1 ELSE 0 END;
UPDATE telco_data d
JOIN (
    SELECT CustomerID, Churn_Prob, Predicted_Churn
    FROM telco_predictions_full
    ORDER BY CustomerID
    LIMIT 5000 OFFSET 5000
) p ON d.CustomerID = p.CustomerID
SET 
    d.Churn_Prob = p.Churn_Prob,
    d.Predicted_Churn = CASE WHEN p.Predicted_Churn = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_HighRiskCustomer = CASE WHEN p.Predicted_Churn = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_LowRiskCustomer = CASE WHEN p.Predicted_Churn = 'No' THEN 1 ELSE 0 END;
    
UPDATE telco_data d
JOIN telco_predictions_full p 
    ON d.CustomerID = p.CustomerID
SET 
    d.Churn_Prob = p.`Churn_Prob.y`,
    d.Predicted_Churn = CASE WHEN p.`Predicted_Churn.y` = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_HighRiskCustomer = CASE WHEN p.`Predicted_Churn.y` = 'Yes' THEN 1 ELSE 0 END,
    d.Predicted_LowRiskCustomer = CASE WHEN p.`Predicted_Churn.y` = 'No' THEN 1 ELSE 0 END;

SELECT COUNT(*) 
FROM telco_data d
JOIN telco_predictions_full p
ON d.CustomerID = p.CustomerID;
SELECT COUNT(*) 
FROM telco_predictions_full
WHERE `Churn_Prob.y` IS NULL;
SHOW WARNINGS;

##Business Impact Analysis 
##Purpose → Find the most valuable customers at risk so retention focuses on them first.
ALTER TABLE telco_predictions_full ADD rank_highest_risk INT;

SET @rank = 0;
UPDATE telco_predictions_full
SET rank_highest_risk = (@rank := @rank + 1)
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC;

## “If all high-risk customers churn, this is the total CLTV we lose.”
SELECT 
    SUM(CLTV) AS potential_revenue_loss
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1;

##“This is how much revenue we save and the percentage ROI of our campaign.
SELECT 
    SUM(CLTV) AS total_loss_if_churn,
    SUM(CLTV) * 0.60 AS revenue_saved,
    (SUM(CLTV) * 0.60 - 50000) / 50000 * 100 AS roi_percent
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1;

##Save Top 100 High-Risk Customers for Power BI
SELECT *
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC
LIMIT 100
INTO OUTFILE '/var/lib/mysql-files/top_100_high_risk.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

SHOW VARIABLES LIKE 'secure_file_priv';
SELECT *
FROM telco_predictions_full
WHERE Predicted_HighRiskCustomer = 1
ORDER BY CLTV DESC
LIMIT 100
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/top_100_highest_risk.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

SELECT * FROM telco_churn.telco_predictions_full;
SELECT Churn_Prob.y From telco_predictions_full;
SELECT CustomerID, Churn_Prob.y, Churn_Value
FROM telco_predictions_full
WHERE Churn_Prob.y > 0.70;

UPDATE telco_predictions t
JOIN (
    SELECT Churn_Value
    FROM telco_predictions_full p
    ORDER BY CustomerID
    LIMIT 5000 OFFSET 5000
) p  ON t.CustomerID = p.CustomerID
SET 
    t.Churn_Value = p.Churn_Value;
    
UPDATE telco_predictions t
JOIN telco_predictions_full p 
    ON t.CustomerID = p.CustomerID
SET 
    t.Churn_Value = p.`Churn_Value`;
    
SELECT
  COUNT(*) AS high_risk_count,
  AVG(Churn_Prob) AS avg_churn_prob_high,
  SUM(CASE WHEN Churn_Value = 1 THEN 1 ELSE 0 END) AS historical_churn_count,
  AVG(CASE WHEN Churn_Value = 1 THEN 1.0 ELSE 0.0 END) AS historical_churn_rate
FROM telco_predictions
WHERE Churn_Prob > 0.70;
























