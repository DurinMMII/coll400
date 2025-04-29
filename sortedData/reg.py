import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression, LogisticRegression
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.metrics import accuracy_score, f1_score, classification_report

current_dir = os.path.dirname(os.path.abspath(__file__))

train_path = os.path.join(current_dir, 'train.csv')
test_path = os.path.join(current_dir, 'test.csv')

try:
    train_df = pd.read_csv(train_path)
    test_df = pd.read_csv(test_path)
    print("Successfully loaded train.csv and test.csv")
except FileNotFoundError:
    print("Error: train.csv or test.csv not found. Make sure they are in the 'sortedData' directory.")
    exit()

X_train = train_df.drop(columns=['Label'])
y_train_labels = train_df['Label']
X_test = test_df.drop(columns=['Label'])
y_test_labels = test_df['Label']

X_train = X_train.fillna(X_train.mean())
X_test = X_test.fillna(X_test.mean()) # Use train mean for test set consistency, or test mean

label_encoder = LabelEncoder()
y_train = label_encoder.fit_transform(y_train_labels)
y_test = label_encoder.transform(y_test_labels) # Use the same encoder fitted on training data

print(f"\nLabels observed: {label_encoder.classes_}")
print(f"Encoded labels mapping: {dict(zip(label_encoder.classes_, label_encoder.transform(label_encoder.classes_)))}")

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test) # Use scaler fitted on training data



print("\n--- Linear Regression (Illustrative, Not Recommended for Classification) ---")
lin_reg = LinearRegression()
lin_reg.fit(X_train_scaled, y_train)

y_pred_lin_raw = lin_reg.predict(X_test_scaled)
y_pred_lin = np.round(y_pred_lin_raw).astype(int)
y_pred_lin = np.clip(y_pred_lin, 0, len(label_encoder.classes_) - 1)

lin_accuracy = accuracy_score(y_test, y_pred_lin)
lin_f1_macro = f1_score(y_test, y_pred_lin, average='macro', zero_division=0)

print(f"Linear Regression Test Accuracy (approx): {lin_accuracy:.2f}")
print(f"Linear Regression Test Macro F1 (approx): {lin_f1_macro:.2f}")
print("\nClassification Report (Linear Regression - Rounded):")
print(classification_report(y_test, y_pred_lin, target_names=label_encoder.classes_, zero_division=0))



print("\n--- Logistic Regression ---")
log_reg = LogisticRegression(multi_class='auto', solver='lbfgs', max_iter=1000, random_state=42)
log_reg.fit(X_train_scaled, y_train)

y_pred_log = log_reg.predict(X_test_scaled)

log_accuracy = accuracy_score(y_test, y_pred_log)
log_f1_macro = f1_score(y_test, y_pred_log, average='macro', zero_division=0)

print(f"Logistic Regression Test Accuracy: {log_accuracy:.2f}") # Compare with C400 report's 0.83
print(f"Logistic Regression Test Macro F1: {log_f1_macro:.2f}")   # Compare with C400 report's 0.84
print("\nClassification Report (Logistic Regression):")
print(classification_report(y_test, y_pred_log, target_names=label_encoder.classes_, zero_division=0))
