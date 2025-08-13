const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.APP_PORT || process.env.PORT || 8080;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Database configuration
const dbConfig = {
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'appdb',
  port: 5432,
};

// Configure host based on environment
if (process.env.DB_CONNECTION) {
  // GCP Cloud SQL connection
  dbConfig.host = `/cloudsql/${process.env.DB_CONNECTION}`;
} else {
  // Local development
  dbConfig.host = process.env.DB_HOST || 'localhost';
}

const pool = new Pool(dbConfig);

// Test database connection
pool.on('connect', () => {
  console.log('Connected to the database');
});

pool.on('error', (err) => {
  console.error('Database connection error:', err);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    environment: process.env.ENVIRONMENT || 'dev',
    version: '1.0.0'
  });
});

// Readiness check endpoint
app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ 
      status: 'ready',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Readiness check failed:', error);
    res.status(503).json({ 
      status: 'not ready',
      database: 'disconnected',
      error: error.message
    });
  }
});

// API endpoints
app.get('/api/status', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW() as timestamp, version() as db_version');
    res.json({
      status: 'Database connected',
      database_time: result.rows[0].timestamp,
      database_version: result.rows[0].db_version,
      app_time: new Date().toISOString(),
      environment: process.env.ENVIRONMENT || 'dev'
    });
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ 
      status: 'error',
      error: 'Database connection failed',
      message: error.message
    });
  }
});

app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, created_at FROM users ORDER BY created_at DESC');
    res.json({
      users: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ 
      error: 'Failed to fetch users',
      message: error.message
    });
  }
});

app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ 
      error: 'Validation error',
      message: 'Name and email are required'
    });
  }

  // Basic email validation
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({
      error: 'Validation error',
      message: 'Invalid email format'
    });
  }

  try {
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    res.status(201).json({
      message: 'User created successfully',
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating user:', error);
    if (error.code === '23505') { // Unique violation
      res.status(409).json({ 
        error: 'Conflict',
        message: 'Email already exists'
      });
    } else {
      res.status(500).json({ 
        error: 'Failed to create user',
        message: error.message
      });
    }
  }
});

app.get('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  
  if (!id || isNaN(id)) {
    return res.status(400).json({
      error: 'Validation error',
      message: 'Invalid user ID'
    });
  }

  try {
    const result = await pool.query('SELECT id, name, email, created_at FROM users WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: 'User not found'
      });
    }
    
    res.json({
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ 
      error: 'Failed to fetch user',
      message: error.message
    });
  }
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to 3-Tier Architecture Test Application',
    version: '1.0.0',
    environment: process.env.ENVIRONMENT || 'dev',
    endpoints: {
      health: '/health',
      ready: '/ready',
      status: '/api/status',
      users: '/api/users',
      user_by_id: '/api/users/:id'
    },
    documentation: 'See README.md for more details'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: 'The requested resource was not found'
  });
});

// Initialize database tables
async function initializeDatabase() {
  try {
    // Create users table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Create updated_at trigger
    await pool.query(`
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
          NEW.updated_at = CURRENT_TIMESTAMP;
          RETURN NEW;
      END;
      $$ language 'plpgsql';
    `);
    
    await pool.query(`
      DROP TRIGGER IF EXISTS update_users_updated_at ON users;
      CREATE TRIGGER update_users_updated_at
          BEFORE UPDATE ON users
          FOR EACH ROW
          EXECUTE FUNCTION update_updated_at_column();
    `);
    
    // Insert sample data
    await pool.query(`
      INSERT INTO users (name, email) VALUES 
      ('John Doe', 'john.doe@example.com'),
      ('Jane Smith', 'jane.smith@example.com'),
      ('Alice Johnson', 'alice.johnson@example.com'),
      ('Bob Wilson', 'bob.wilson@example.com')
      ON CONFLICT (email) DO NOTHING
    `);
    
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
    throw error;
  }
}

// Start server
async function startServer() {
  try {
    await initializeDatabase();
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Environment: ${process.env.ENVIRONMENT || 'dev'}`);
      console.log(`Health check: http://localhost:${PORT}/health`);
      console.log(`API status: http://localhost:${PORT}/api/status`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    console.log('Database connections closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  pool.end(() => {
    console.log('Database connections closed');
    process.exit(0);
  });
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.error('Unhandled promise rejection:', err);
  process.exit(1);
});

// Start the application
if (require.main === module) {
  startServer();
}

module.exports = app;