# Google Form & Google Sheet Quiz Score Sync Setup Guide

This guide explains how to link your Google Form Quiz to your Study Planner App so that scores are automatically fetched and recorded in SQLite for each student.

---

## 1. Create Your Google Form Quiz
1. Go to [Google Forms](https://forms.google.com) and create a quiz.
2. Go to **Settings**:
   - Turn on **"Make this a quiz"**.
   - Under **Responses**, set **"Collect email addresses"** to **"Verified"** or **"Responder input"** (or add a required question titled **"Student Email"**).
   - This email will be used to match the student in the Study Planner App.
3. Add your questions and assign points/correct answers.
4. Copy the public form link (e.g. `https://docs.google.com/forms/d/e/.../viewform`).

---

## 2. Link Responses to a Google Sheet
1. In your Google Form, click on the **Responses** tab.
2. Click **"Link to Sheets"** (the green spreadsheet icon) and create a new Google Sheet.
3. When responses are submitted, Google Forms automatically writes:
   - `Timestamp`
   - `Email Address`
   - `Score` (e.g., `8 / 10`)

---

## 3. Add Google Apps Script (Integration Layer)
1. In the Google Sheet with responses, click on **Extensions** > **Apps Script** in the top menu bar.
2. Delete any existing code in the editor.
3. Open [`Code.gs`](./Code.gs) in this directory, copy its entire contents, and paste it into the editor.
4. Click the **Save** (disk) icon.

---

## 4. Deploy as a Web App
1. In the Apps Script editor, click the blue **Deploy** button (top right) > **New deployment**.
2. Click the gear icon next to "Select type" and choose **Web app**.
3. Fill in the deployment settings:
   - **Description**: `Study Planner Quiz Sync`
   - **Execute as**: **Me** (`your_email@gmail.com`)
   - **Who has access**: **Anyone**
     *(Note: This allows the Flutter app to request scores over HTTPS without OAuth login)*
4. Click **Deploy**.
5. Grant permissions if prompted by Google (click *Advanced* > *Go to Study Planner Quiz Sync (unsafe)*).
6. Copy the **Web App URL** (it will look like: `https://script.google.com/macros/s/AKfycb.../exec`).

---

## 5. Add to Study Planner App
1. Log in to the Study Planner App as **Admin** (`admin` / `admin123`).
2. Go to **Manage Quizzes** > Click **+** (Add Quiz).
3. Enter:
   - **Semester**: (e.g. `Semester 1`)
   - **Subject**: (e.g. `Mathematics I`)
   - **Quiz Title**: (e.g. `Calculus Unit 1 Practice Quiz`)
   - **Google Form Link**: Paste your Google Form link from Step 1.
   - **Google Apps Script Sync URL**: Paste the Web App URL from Step 4.
   - **Total Marks**: (e.g. `10`)
4. Click **Add**.

---

## How it Works:
1. **Student attempts the quiz**:
   - The student logs in, goes to **Quizzes**, and clicks **Attempt**.
   - The app reminds the student to use their registered email, launches the Google Form, and records the attempt as `Attempted (Pending Result)` in SQLite.
2. **Student submits the form**:
   - Google Forms grades the quiz and writes the score to the Google Sheet.
3. **Student clicks "Sync Result"**:
   - The Flutter app calls the Apps Script Web App URL with `?action=getScore&email=student@example.com`.
   - The Apps Script reads the sheet, finds the student's row, extracts the score, and returns clean JSON.
   - The Flutter app saves the score to SQLite and updates the status to `Completed (Score: X/Y)`.
4. **Admin views results**:
   - The Admin can open **Manage Quizzes**, tap the **View Student Results** icon on any quiz, and see every student's attempt, status, and score.
