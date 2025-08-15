library(DBI)
install.packages('RMySQL')
library(RMySQL)
library(dplyr)
install.packages('caret')
library(caret)

# MySQL connection
con <- dbConnect(RMySQL::MySQL(),
                 dbname = "telco_churn",
                 host = "localhost",
                 user = "root",
                 password = "12345")
library(RMySQL)

con <- dbConnect(
  MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)

dbListTables(con)

# Load data
telco <- dbReadTable(con, "telco_data")
# Convert churn column to factor (1 = Churned, 0 = Retained)
telco$Churn_Value <- as.factor(telco$Churn_Value)
# Remove columns not useful for modeling
telco <- telco %>%
  select(-CustomerID, -Churn_Label, -Churn_Reason)
#Train/Test split
set.seed(123)
trainIndex <- createDataPartition(telco$Churn_Value, p = 0.8, list = FALSE)
train <- telco[trainIndex, ]
test <- telco[-trainIndex, ]
# Remove columns with only one unique value
telco <- telco %>%
  select(where(~ n_distinct(.) > 1))

# Ensure character columns become factors
telco <- telco %>%
  mutate(across(where(is.character), as.factor))

#Train logistic regression model
model <- glm(Churn_Value ~ ., data = train, family = binomial)
summary(model)
#Predict probabilities
pred_probs <- predict(model, newdata = test, type = "response")
pred_class <- ifelse(pred_probs > 0.5, 1, 0)  # threshold at 0.5
# Evaluate
confusionMatrix(as.factor(pred_class), test$Churn_Value)
#Predict churn probability for ALL customers
telco$Churn_Prob <- predict(model, newdata = telco, type = "response")






# --- 2. quick overview ---
cat("Rows / Cols:", nrow(telco), "x", ncol(telco), "\n")
print(str(telco, max.level = 1))

# Make column names safe
names(telco) <- make.names(names(telco))

# --- 3. column stats: unique values and NAs ---
col_stats <- tibble::tibble(
  col = names(telco),
  n_unique = sapply(telco, function(x) length(unique(na.omit(x)))),
  n_na = sapply(telco, function(x) sum(is.na(x))),
  class = sapply(telco, function(x) class(x)[1])
)
print(col_stats)

# Show columns with only 0 or 1 unique non-NA value (these will cause contrasts error)
problem_cols <- col_stats %>% filter(n_unique <= 1) %>% pull(col)
cat("Columns with <=1 unique (will drop):\n"); print(problem_cols)

# If any columns are all NA, list them
all_na_cols <- col_stats %>% filter(n_unique == 0) %>% pull(col)
if(length(all_na_cols)>0) {
  cat("Columns with ALL NA:\n"); print(all_na_cols)
}

# --- 4. Ensure target column exists and is OK ---
# Adjust this name if your churn numeric is "Churn_Value" or similar
target_name <- "Churn_Value"  # change if your column is named differently (e.g., Churn_Value, Churn_Value, ChurnNum)
if(! target_name %in% names(telco)) stop(paste("Target column", target_name, "not found. Check exact name with names(telco)"))

cat("Target value counts:\n"); print(table(telco[[target_name]], useNA="ifany"))

# Convert common variations to 0/1 numeric then factor
telco[[target_name]] <- as.character(telco[[target_name]])
telco[[target_name]] <- ifelse(telco[[target_name]] %in% c("Yes","yes","Y","1",1, TRUE), 1,
                               ifelse(telco[[target_name]] %in% c("No","no","N","0",0, FALSE), 0, NA))
cat("After standardizing target, counts:\n"); print(table(telco[[target_name]], useNA="ifany"))

# Ensure we still have two classes
if(length(unique(na.omit(telco[[target_name]]))) < 2) {
  stop("Target has fewer than 2 classes after cleaning. Can't model. Show table(telco[[target_name]]) output above.")
}

# Convert target to factor
telco[[target_name]] <- factor(telco[[target_name]], levels=c(0,1))

# --- 5. Drop ID and text/leakage columns if present ---
drop_if_present <- c("CustomerID","Customer.Id","Customer.ID","Churn_Label","Churn.Reason","Churn_Reason")
drop_cols <- intersect(names(telco), drop_if_present)
if(length(drop_cols)>0) {
  cat("Dropping ID/leak columns:", paste(drop_cols, collapse=", "), "\n")
  telco <- telco %>% select(-all_of(drop_cols))
}

# --- 6. Drop columns with <=1 unique non-NA value (from earlier) ---
if(length(problem_cols) > 0) {
  telco <- telco %>% select(-all_of(problem_cols))
  cat("Dropped columns with <=1 unique value.\n")
}

# --- 7. Convert character columns to factor safely and trim whitespace ---
char_cols <- names(telco)[sapply(telco, is.character)]
for(col in char_cols) telco[[col]] <- as.factor(trimws(telco[[col]]))

# Recompute factor levels and find any factors with single level
factor_levels <- sapply(telco, function(x) if(is.factor(x)) nlevels(x) else NA)
single_level_factors <- names(factor_levels)[which(factor_levels == 1)]
if(length(single_level_factors) > 0) {
  cat("Dropping single-level factor columns:", paste(single_level_factors, collapse=", "), "\n")
  telco <- telco %>% select(-all_of(single_level_factors))
}

# --- 8. Impute simple NAs for numeric columns (median) and for factors add "Missing" level ---
num_cols <- names(telco)[sapply(telco, is.numeric)]
for(col in num_cols) {
  if(any(is.na(telco[[col]]))) {
    med <- median(telco[[col]], na.rm = TRUE)
    telco[[col]][is.na(telco[[col]])] <- med
    cat("Imputed NAs in", col, "with median:", med, "\n")
  }
}
# For factor columns
fac_cols <- names(telco)[sapply(telco, is.factor)]
for(col in fac_cols) {
  if(any(is.na(telco[[col]]))) {
    levels(telco[[col]]) <- c(levels(telco[[col]]), "Missing")
    telco[[col]][is.na(telco[[col]])] <- "Missing"
    cat("Filled NA factor in", col, "with 'Missing'\n")
  }
}

# --- 9. Final sanity check before model ---
cat("Final dataset dims:", dim(telco), "\n")
print(sapply(telco, function(x) if(is.factor(x)) nlevels(x) else length(unique(x))[1]))

# Show any remaining factors with one level (should be none)
remaining_single <- names(telco)[sapply(telco, function(x) is.factor(x) && nlevels(x)<=1)]
cat("Remaining single-level factors (should be none):"); print(remaining_single)

# --- 10. Create formula safely (exclude target) ---
predictors <- setdiff(names(telco), target_name)
# Optionally further drop columns with too many levels (high-cardinality factors) to keep model simple:
high_cardinality <- predictors[sapply(telco[predictors], function(x) is.factor(x) && nlevels(x) > 40)]
if(length(high_cardinality)>0) {
  cat("Dropping very high-cardinality factors (too many levels):", paste(high_cardinality, collapse=", "), "\n")
  predictors <- setdiff(predictors, high_cardinality)
  telco <- telco %>% select(-all_of(high_cardinality))
}

formula <- as.formula(paste(target_name, "~", paste(predictors, collapse = " + ")))
cat("Model formula:\n"); print(formula)

# --- 11. Train/test split and model ---
set.seed(42)
if(!requireNamespace("caret", quietly = TRUE)) install.packages("caret")
library(caret)
train_idx <- createDataPartition(telco[[target_name]], p = 0.8, list = FALSE)
train <- telco[train_idx, ]
test  <- telco[-train_idx, ]

# Final check: any factors in train with only 1 level? (should not)
fac_one_train <- names(train)[sapply(train, function(x) is.factor(x) && nlevels(x)==1)]
if(length(fac_one_train)>0) stop(paste("These factors have 1 level in training set:", paste(fac_one_train, collapse=", ")))

# Fit logistic regression
model <- glm(formula, data = train, family = binomial)
summary(model)

# Predict on test
test$pred_prob <- predict(model, newdata = test, type = "response")
library(pROC)
cat("AUC on test:", auc(roc(as.numeric(as.character(test[[target_name]])), test$pred_prob)), "\n")

# Save model predictions for full dataset
telco$Churn_Prob <- predict(model, newdata = telco, type = "response")

names(telco)
# After predicting, join predictions back to original dataset
predictions <- raw_telco %>%
  select(CustomerID) %>%
  bind_cols(Churn_Prob = telcoChurn_Prob)

telco <- telco %>%
  mutate(CustomerID = row_number())
predictions <- telco %>%
  mutate(Churn_Prob = telcoChurn_Prob) %>%
  select(CustomerID, Churn_Prob)

raw_telco <- dbReadTable(con, "telco_data")  

raw_telco <- raw_telco %>% filter(CustomerID %in% your_filter_condition)

#Predict churn probability
telcoChurn_Prob <- predict(model, newdata = telco, type = "response")

#Bind predictions back to original CustomerID
predictions <- raw_telco %>%
  select(CustomerID) %>%
  mutate(
    Churn_Prob = telcoChurn_Prob,
    Predicted_Churn = ifelse(Churn_Prob >= 0.5, "Yes", "No")
  )


library(DBI)
library(RMySQL)

#Connect to MySQL
con <- dbConnect(
  RMySQL::MySQL(),
  dbname   = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user     = "root",
  password = "12345"
)
#Export predictions to MySQL
#Ensure table will store correct data types
dbWriteTable(
  conn = con,
  name = "telco_predictions",
  value = predictions,
  overwrite = TRUE,
  row.names = FALSE,
  field.types = c(
    CustomerID      = "VARCHAR(50)",
    Churn_Prob      = "DOUBLE",
    Predicted_Churn = "VARCHAR(3)"
  )
)

#Check if data was inserted
dbGetQuery(con, "SELECT * FROM telco_predictions LIMIT 10;")

#Close connection
dbDisconnect(con)

cat("Predictions saved to MySQL table 'telco_predictions'. Ready for Power BI!")
#Evaluate accuracy, precision, recall.
# Predict probabilities
pred_probs <- predict(model, test, type = "response")

# Convert probabilities to Yes/No churn predictions
pred_classes <- ifelse(pred_probs > 0.5, 1, 0)

# Evaluate
library(caret)
confusionMatrix(
  factor(pred_classes, levels = c(0, 1)),
  factor(test$Churn_Value, levels = c(0, 1))
)
# Confusion matrix
cm <- table(Predicted = pred_classes, Actual = test$Churn_Value)

# Accuracy
accuracy <- sum(diag(cm)) / sum(cm)

# Precision (Positive Predictive Value)
precision <- cm[2,2] / sum(cm[2,])

# Recall (Sensitivity / True Positive Rate)
recall <- cm[2,2] / sum(cm[,2])

# F1 Score
f1_score <- 2 * ((precision * recall) / (precision + recall))

# Print results
cat("Accuracy:", round(accuracy, 4), "\n")
cat("Precision:", round(precision, 4), "\n")
cat("Recall:", round(recall, 4), "\n")
cat("F1 Score:", round(f1_score, 4), "\n")


# Merge telco_data and predictions
telco_predictions_full <- merge(telco, predictions, by = "CustomerID", all.x = TRUE)
# High risk = predicted churn = 1
telco_predictions_full$Predicted_HighRiskCustomer <- ifelse(telco_predictions_full$Predicted_Churn == 1, 1, 0)
# Low risk = predicted churn = 0
telco_predictions_full$Predicted_LowRiskCustomer <- ifelse(telco_predictions_full$Predicted_Churn == 0, 1, 0)
library(dplyr)
telco_predictions_full <- telco_predictions_full %>%
  arrange(desc(Predicted_HighRiskCustomer), desc(CLTV)) %>%
  mutate(HighRisk_Rank = ifelse(Predicted_HighRiskCustomer == 1, row_number(), NA))
# Example: sum CLTV for top 50 high-risk customers
top_highrisk <- telco_predictions_full %>% filter(Predicted_HighRiskCustomer == 1) %>% head(50)
potential_revenue_loss <- sum(top_highrisk$CLTV, na.rm = TRUE)
cat("Potential Revenue Loss from top 50 high-risk customers: $", potential_revenue_loss, "\n")
# Example: saving 30% of high-risk customers
save_rate <- 0.3
roi <- potential_revenue_loss * save_rate
cat("ROI if we save 30%:", roi, "\n")
# View structure
str(telco_predictions_full)

library(RMySQL)

# Connect to MySQL
con <- dbConnect(MySQL(),
                 dbname = "telco_churn",
                 host = "127.0.0.1",
                 port = 3307,
                 user = "root",
                 password = "12345"
)
# Write predictions table to MySQL
dbWriteTable(con, "telco_predictions_full", telco_predictions_full, overwrite = TRUE, row.names = FALSE)
#CSV export from R for backup/import
write.csv(telco_predictions_full, "telco_predictions_full.csv", row.names = FALSE)
dbDisconnect(con)

library(dplyr)
library(DBI)
library(RMySQL)

# Clean CustomerID in both tables
telco$CustomerID <- trimws(as.character(telco$CustomerID))
predictions$CustomerID <- trimws(as.character(predictions$CustomerID))

# Merge (left join so all telco rows are kept)
telco_predictions_full <- telco %>%
  left_join(predictions, by = "CustomerID")

# Check for missing matches
missing_count <- sum(is.na(telco_predictions_full$Churn_Prob))
cat("Missing predictions:", missing_count, "\n")

if (missing_count > 0) {
  cat("WARNING: Some customers don't have predictions. Check CustomerID format.\n")
}

# Connect to MySQL
con <- dbConnect(
  RMySQL::MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)

# Push to MySQL (overwrite old table)
dbWriteTable(con, "telco_predictions_full", telco_predictions_full, overwrite = TRUE, row.names = FALSE)

# Close connection
dbDisconnect(con)

cat("telco_predictions_full table uploaded successfully.\n")

library(dplyr)
library(stringr)

#  Force everything to character and remove all whitespace + lowercase
telco_data$CustomerID <- telco_data$CustomerID %>%
  as.character() %>%
  str_trim() %>%
  str_squish() %>%
  str_to_lower()

predictions$CustomerID <- predictions$CustomerID %>%
  as.character() %>%
  str_trim() %>%
  str_squish() %>%
  str_to_lower()

#  Check overlap before merging
cat("In telco_data only:", sum(!telco_data$CustomerID %in% predictions$CustomerID), "\n")
cat("In predictions only:", sum(!predictions$CustomerID %in% telco_data$CustomerID), "\n")

#  Merge after cleaning
telco_predictions_full <- telco_data %>%
  left_join(predictions, by = "CustomerID")

#  Check NA count
sum(is.na(telco_predictions_full$Churn_Prob))


library(DBI)
library(RMySQL)
con <- dbConnect(
  RMySQL::MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)
# Fetch main cleaned telco dataset
telco_data <- dbReadTable(con, "telco_data")

# Fetch predictions table (CustomerID, Churn_Prob, Predicted_Churn)
predictions <- dbReadTable(con, "telco_predictions")

telco_predictions_full <- merge(
  telco_data,
  predictions,
  by = "CustomerID",
  all.x = TRUE
)
dbWriteTable(
  con,
  "telco_predictions_full", 
  telco_predictions_full,
  overwrite = TRUE,
  row.names = FALSE
)
telco_predictions_full <- merge(
  telco_data[, c("CustomerID", "Churn_Reason")],  
  predictions,                                    
  by = "CustomerID",
  all.x = TRUE
)
telco_predictions_full <- merge(
  telco_data,      
  predictions,     
  by = "CustomerID",
  all.x = TRUE     
)

dbWriteTable(
  con,
  "telco_predictions_full", 
  telco_predictions_full,
  overwrite = TRUE,
  row.names = FALSE
)

if (inherits(model, "glm")) {
  pred_probs <- predict(model, telco_data, type = "response")
  pred_class <- ifelse(pred_probs >= 0.5, "Yes", "No")
} else {
  pred_probs <- predict(model, telco_data, type = "prob")[, "Yes"]
  pred_class <- predict(model, telco_data)
}

predictions_all <- data.frame(
  CustomerID = telco_data$CustomerID,
  Churn_Prob = pred_probs,
  Predicted_Churn = pred_class
)
telco_predictions_full <- merge(
  telco_data,          
  predictions_all,     
  by = "CustomerID",
  all.x = TRUE         
)
library(DBI)
dbWriteTable(con, "telco_predictions_full", telco_predictions_full, overwrite = TRUE, row.names = FALSE)

library(dplyr)

telco_predictions_full <- merge(
  telco_data,
  predictions,
  by = "CustomerID",
  all.x = TRUE
)

# Remove .x/.y naming by keeping only needed columns and renaming
telco_predictions_full <- telco_predictions_full %>%
  select(CustomerID, Monthly_Charges, Tenure_Months, CLTV,
         Churn_Prob = Churn_Prob.y,
         Predicted_Churn = Predicted_Churn.y) %>%
  mutate(
    Predicted_HighRiskCustomer = ifelse(Predicted_Churn == "Yes", 1, 0),
    Predicted_LowRiskCustomer  = ifelse(Predicted_Churn == "No", 1, 0)
  )

# Replace NA with 0 or "No" if needed
telco_predictions_full$Churn_Prob[is.na(telco_predictions_full$Churn_Prob)] <- 0
telco_predictions_full$Predicted_Churn[is.na(telco_predictions_full$Predicted_Churn)] <- "No"
telco_predictions_full <- merge(
  telco_data[, c("CustomerID", "Monthly_Charges", "Tenure_Months", "CLTV", "Churn_Reason")],
  predictions,
  by = "CustomerID",
  all.x = TRUE
)
telco_predictions_full <- merge(
  telco_data,      # all original cleaned customer columns
  predictions,     # predictions (CustomerID, Churn_Prob, Predicted_Churn)
  by = "CustomerID",
  all.x = TRUE
)

# Create risk flags
telco_predictions_full <- telco_predictions_full %>%
  mutate(
    Predicted_HighRiskCustomer = ifelse(Predicted_Churn.y == "Yes", 1, 0),
    Predicted_LowRiskCustomer  = ifelse(Predicted_Churn.y == "No", 1, 0)
  )
predictions <- predictions %>%
  rename(
    Churn_Prob_Pred = Churn_Prob,
    Predicted_Churn_Label = Predicted_Churn
  )

library(DBI)
library(RMySQL)
con <- dbConnect(
  RMySQL::MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)
dbWriteTable(
  con,
  "telco_predictions_full", 
  telco_predictions_full,
  overwrite = TRUE,
  row.names = FALSE
)
write.csv(telco_predictions_full, "telco_predictions_full.csv", row.names = FALSE)
dbDisconnect(con)


library(dplyr)
library(DBI)

# Fixed campaign cost
campaign_cost <- 50000

# Create Business Impact Table
business_impact <- telco_predictions_full %>%
  mutate(
    Potential_Revenue_Loss = ifelse(Predicted_HighRiskCustomer == 1, CLTV, 0),
    Revenue_Saved_60pct = Potential_Revenue_Loss * 0.60,
    ROI_60pct = ((Revenue_Saved_60pct - campaign_cost) / campaign_cost) * 100
  )

# Summary metrics for management
impact_summary <- business_impact %>%
  summarise(
    Total_Potential_Loss = sum(Potential_Revenue_Loss, na.rm = TRUE),
    Revenue_Saved_60pct = sum(Revenue_Saved_60pct, na.rm = TRUE),
    ROI_60pct = ((Revenue_Saved_60pct - campaign_cost) / campaign_cost) * 100
  )
# View results
print(impact_summary)
# Export for Power BI
# 1. Save to CSV
write.csv(business_impact, "Business_Impact_Table.csv", row.names = FALSE)

# 2. Push to MySQL
library(DBI)
library(RMySQL)
con <- dbConnect(
  RMySQL::MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)
dbWriteTable(
  con,
  "business_impact",
  business_impact,
  overwrite = TRUE,
  row.names = FALSE
)


library(dplyr)
library(DBI)

# Fixed campaign cost
campaign_cost <- 50000

# Merge Churn_Reason from telco_data to predictions
telco_predictions_full <- telco_predictions_full %>%
  left_join(
    telco_data %>% select(CustomerID, Churn_Reason),
    by = "CustomerID"
  )

# Create Business Impact Table
business_impact <- telco_predictions_full %>%
  mutate(
    Potential_Revenue_Loss = ifelse(Predicted_HighRiskCustomer == 1, CLTV, 0),
    Revenue_Saved_60pct = Potential_Revenue_Loss * 0.60,
    ROI_60pct = ((Revenue_Saved_60pct - campaign_cost) / campaign_cost) * 100
  ) %>%
  select(CustomerID, Churn_Reason.y, CLTV, Churn_Prob.y, Predicted_Churn.y,
         Predicted_HighRiskCustomer, Predicted_LowRiskCustomer,
         Potential_Revenue_Loss, Revenue_Saved_60pct, ROI_60pct)

# Summary metrics
impact_summary <- business_impact %>%
  group_by(Churn_Reason.y) %>%
  summarise(
    Total_Potential_Loss = sum(Potential_Revenue_Loss, na.rm = TRUE),
    Revenue_Saved_60pct = sum(Revenue_Saved_60pct, na.rm = TRUE),
    ROI_60pct = ((Revenue_Saved_60pct - campaign_cost) / campaign_cost) * 100,
    .groups = "drop"
  )

print(impact_summary)

# 1. Save to CSV
write.csv(business_impact, "Business_Impact_Table.csv", row.names = FALSE)

# 2. Push to MySQL
library(DBI)
library(RMySQL)
con <- dbConnect(
  RMySQL::MySQL(),
  dbname = "telco_churn",
  host = "127.0.0.1",
  port = 3307,
  user = "root",
  password = "12345"
)
dbWriteTable(
  con,
  "business_impact",
  business_impact,
  overwrite = TRUE,
  row.names = FALSE
)

