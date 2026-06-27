# Run this entire script in PowerShell from D:\Kubernetes-Practice\ott-platform

$base = "D:\Kubernetes-Practice\ott-platform"

function Write-NoBom($path, $content) {
    $dir = Split-Path $path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content.TrimStart(), $utf8NoBom)
    Write-Host "OK: $path"
}

# ── backend/auth/package.json ─────────────────────────────────
Write-NoBom "$base\backend\auth\package.json" @'
{
  "name": "ott-auth-service",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1",
    "express-validator": "^7.0.1"
  }
}
'@

# ── backend/auth/index.js ─────────────────────────────────────
Write-NoBom "$base\backend\auth\index.js" @'
const express = require("express");
const { Pool } = require("pg");
const redis = require("redis");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.POSTGRES_HOST || "postgres",
  port: 5432,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

const redisClient = redis.createClient({
  url: `redis://${process.env.REDIS_HOST || "redis"}:6379`,
});
redisClient.connect().catch(console.error);

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id         SERIAL PRIMARY KEY,
      email      VARCHAR(255) UNIQUE NOT NULL,
      password   VARCHAR(255) NOT NULL,
      name       VARCHAR(255),
      role       VARCHAR(50) DEFAULT 'viewer',
      created_at TIMESTAMP DEFAULT NOW()
    );
  `);
  console.log("Database initialised");
}

const generateToken = (user) =>
  jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "No token provided" });
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const blacklisted = await redisClient.get(`blacklist:${token}`);
    if (blacklisted) return res.status(401).json({ error: "Token revoked" });
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
};

app.get("/health", (req, res) => res.json({ status: "ok", service: "auth" }));

app.post("/auth/register", [
  body("email").isEmail(),
  body("password").isLength({ min: 6 }),
  body("name").notEmpty(),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  const { email, password, name } = req.body;
  try {
    const hashed = await bcrypt.hash(password, 10);
    const result = await pool.query(
      "INSERT INTO users (email, password, name) VALUES ($1, $2, $3) RETURNING id, email, name, role",
      [email, hashed, name]
    );
    const token = generateToken(result.rows[0]);
    res.status(201).json({ user: result.rows[0], token });
  } catch (err) {
    if (err.code === "23505") return res.status(409).json({ error: "Email already exists" });
    res.status(500).json({ error: "Server error" });
  }
});

app.post("/auth/login", [
  body("email").isEmail(),
  body("password").notEmpty(),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  const { email, password } = req.body;
  try {
    const result = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
    if (!result.rows.length) return res.status(401).json({ error: "Invalid credentials" });
    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(401).json({ error: "Invalid credentials" });
    await redisClient.setEx(`session:${user.id}`, 604800, JSON.stringify({ id: user.id, email: user.email, role: user.role }));
    const token = generateToken(user);
    res.json({ user: { id: user.id, email: user.email, name: user.name, role: user.role }, token });
  } catch (err) {
    res.status(500).json({ error: "Server error" });
  }
});

app.post("/auth/logout", authMiddleware, async (req, res) => {
  const token = req.headers.authorization.split(" ")[1];
  await redisClient.setEx(`blacklist:${token}`, 604800, "1");
  await redisClient.del(`session:${req.user.id}`);
  res.json({ message: "Logged out successfully" });
});

app.get("/auth/verify", authMiddleware, (req, res) => {
  res.json({ valid: true, user: req.user });
});

app.get("/auth/profile", authMiddleware, async (req, res) => {
  const result = await pool.query(
    "SELECT id, email, name, role, created_at FROM users WHERE id = $1",
    [req.user.id]
  );
  res.json(result.rows[0]);
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, async () => {
  await initDB();
  console.log(`Auth service running on port ${PORT}`);
});
'@

# ── backend/auth/Dockerfile ───────────────────────────────────
Write-NoBom "$base\backend\auth\Dockerfile" @'
FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm install --production
COPY index.js .
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
USER ottuser
EXPOSE 3001
CMD ["node", "index.js"]
'@

# ── frontend/web/package.json ─────────────────────────────────
Write-NoBom "$base\frontend\web\package.json" @'
{
  "name": "ott-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.1.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  }
}
'@

# ── frontend/web/next.config.js ───────────────────────────────
Write-NoBom "$base\frontend\web\next.config.js" @'
/** @type {import("next").NextConfig} */
const nextConfig = {
  output: "standalone",
  images: {
    domains: ["via.placeholder.com"],
  },
  env: {
    NEXT_PUBLIC_AUTH_API: process.env.NEXT_PUBLIC_AUTH_API || "http://localhost:3001",
    NEXT_PUBLIC_CATALOG_API: process.env.NEXT_PUBLIC_CATALOG_API || "http://localhost:3002",
  },
}
module.exports = nextConfig
'@

# ── frontend/web/Dockerfile ───────────────────────────────────
Write-NoBom "$base\frontend\web\Dockerfile" @'
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -S ottgroup && adduser -S ottuser -G ottgroup
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
USER ottuser
EXPOSE 3000
CMD ["node", "server.js"]
'@

# ── k8s/ott-backend/secrets.yaml ─────────────────────────────
Write-NoBom "$base\k8s\ott-backend\secrets.yaml" @'
apiVersion: v1
kind: Secret
metadata:
  name: ott-secrets
  namespace: ott-backend
type: Opaque
data:
  POSTGRES_USER: b3R0dXNlcg==
  POSTGRES_PASSWORD: b3R0cGFzc3dvcmQxMjM=
  POSTGRES_DB: b3R0ZGI=
  JWT_SECRET: c3VwZXJzZWNyZXRqd3RrZXkyMDI0
'@

# ── k8s/ott-backend/postgres.yaml ────────────────────────────
Write-NoBom "$base\k8s\ott-backend\postgres.yaml" @'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: ott-backend
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_DB
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ott-backend
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  clusterIP: None
'@

# ── k8s/ott-backend/redis.yaml ───────────────────────────────
Write-NoBom "$base\k8s\ott-backend\redis.yaml" @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ott-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
          command: ["redis-server", "--appendonly", "yes"]
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ott-backend
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
'@

# ── k8s/ott-backend/auth-deployment.yaml ─────────────────────
Write-NoBom "$base\k8s\ott-backend\auth-deployment.yaml" @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
  namespace: ott-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: auth-service
  template:
    metadata:
      labels:
        app: auth-service
    spec:
      containers:
        - name: auth-service
          image: rakeshv12/ott-auth-service:latest
          ports:
            - containerPort: 3001
          env:
            - name: PORT
              value: "3001"
            - name: POSTGRES_HOST
              value: "postgres"
            - name: REDIS_HOST
              value: "redis"
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: POSTGRES_DB
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: ott-secrets
                  key: JWT_SECRET
          livenessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: auth-service
  namespace: ott-backend
spec:
  selector:
    app: auth-service
  ports:
    - port: 3001
      targetPort: 3001
'@

# ── k8s/ott-frontend/frontend-deployment.yaml ────────────────
Write-NoBom "$base\k8s\ott-frontend\frontend-deployment.yaml" @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-web
  namespace: ott-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend-web
  template:
    metadata:
      labels:
        app: frontend-web
    spec:
      containers:
        - name: frontend-web
          image: rakeshv12/ott-frontend-web:latest
          ports:
            - containerPort: 3000
          env:
            - name: NEXT_PUBLIC_AUTH_API
              value: "http://auth-service.ott-backend.svc.cluster.local:3001"
          resources:
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "512Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-web
  namespace: ott-frontend
spec:
  selector:
    app: frontend-web
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 3000
'@

# ── infra/argocd/ott-backend-app.yaml ────────────────────────
Write-NoBom "$base\infra\argocd\ott-backend-app.yaml" @'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ott-backend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/rakeshv12/ott-platform.git
    targetRevision: main
    path: k8s/ott-backend
  destination:
    server: https://kubernetes.default.svc
    namespace: ott-backend
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
'@

Write-Host ""
Write-Host "All files written. Verifying sizes..."
Get-ChildItem -Recurse -File "$base\backend", "$base\frontend", "$base\k8s", "$base\infra" |
    Select-Object FullName, Length |
    Format-Table -AutoSize