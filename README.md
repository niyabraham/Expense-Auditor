### Live Link : https://expense-auditor-4ja5.onrender.com
### Demo Video : https://drive.google.com/file/d/1irx9JXEwABLdHZ4MDpSNndvc_3N3CCZH/view?usp=sharing

# Aetheris Enterprise Expense Auditor

## The Problem
Corporate expense auditing is traditionally a highly manual, slow, and error-prone process. Finance teams spend countless hours visually verifying receipts against complex company policies, leaving organizations vulnerable to expense fraud, date mismatches, and policy violations.

## The Solution
Aetheris is an AI-powered, policy-first expense auditing platform that automates compliance. By leveraging advanced Vision LLMs, the application instantly extracts receipt data (merchant, amount, date) and cross-references it against strict corporate policies in real-time. It automatically categorizes claims as Approved, Flagged, or Rejected, providing auditors with a real-time dashboard and exact policy snippets justifying the AI's decision.

## Tech Stack
* **Frontend:** Flutter (Web), Dart
* **Backend & Database:** Supabase (PostgreSQL, Storage)
* **Serverless Compute:** Supabase Edge Functions (Deno/TypeScript)
* **AI & OCR:** Groq API (Llama-3.2-90B-Vision model)
* **Containerization:** Docker, Docker Compose, NGINX
* **Data Visualization:** FL Chart

## Setup Instructions

### Prerequisites
* Docker Desktop installed and running.
* Git installed.

### Running Locally
1. **Clone the repository:**
   ```bash
   git clone [https://github.com/niyabraham/Expense-Auditor.git](https://github.com/niyabraham/Expense-Auditor.git)
   cd Expense-Auditor

### 2. Environment Variables
Create a file named `.env` inside the `assets/` folder and paste the following testing credentials so you can run the app immediately:

\`\`\`env
SUPABASE_URL=https://zcxgrnwpdlvovgotjwgl.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5c... (paste your actual anon key here)
\`\`\`

### 3. Build and Spin Up the Container:
Run the following command to build the Flutter web app and start the NGINX server:

Bash
docker-compose up --build -d

### 4.Access the Application:
Open your browser and navigate to:
http://localhost:8080

(Note: You can log in as david.miller@aetheris.com to test the employee upload flow, or admin@aetheris.com to view the Auditor Dashboard with login password = aetheris).
