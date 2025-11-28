require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const {
  S3Client,
  ListBucketsCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand
} = require('@aws-sdk/client-s3');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;

// ==========================================
// BEARER TOKEN MIDDLEWARE (OpenAI Required)
// ==========================================
const bearerAuthMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Bearer token required. Use header: Authorization: Bearer <your-token>'
    });
  }
  
  const token = authHeader.substring(7); // Remove 'Bearer ' prefix
  const serverToken = process.env.SERVER_BEARER_TOKEN;
  
  if (!serverToken) {
    return res.status(500).json({
      error: 'Server configuration error',
      message: 'SERVER_BEARER_TOKEN not set in environment'
    });
  }
  
  if (token !== serverToken) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Invalid Bearer token'
    });
  }
  
  next();
};

// ==========================================
// MIDDLEWARE
// ==========================================
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(morgan('combined'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Serve static files (including .well-known)
app.use(express.static(path.join(__dirname, 'public')));

// ==========================================
// CLIENTS INITIALIZATION
// ==========================================
let supabase = null;
let s3 = null;

// Initialize Supabase
if (process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY) {
  supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
  console.log('✓ Supabase client initialized');
} else {
  console.warn('⚠ Supabase credentials not found');
}

// Initialize S3 (AWS SDK v3)
if (process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY) {
  const endpoint = process.env.S3_ENDPOINT || 'https://s3.amazonaws.com';
  const region = process.env.S3_REGION || 'us-east-1';
  const config = {
    region,
    endpoint,
    forcePathStyle: true,
    credentials: {
      accessKeyId: process.env.S3_ACCESS_KEY_ID,
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
    }
  };
  s3 = new S3Client(config);
  console.log('✓ S3 client (v3) initialized');
} else {
  console.warn('⚠ S3 credentials not found');
}

// Multer for file uploads (memory storage)
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 } // 100MB max
});

// ==========================================
// PUBLIC ENDPOINTS (No Bearer Token Required)
// ==========================================

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '2.0.0',
    bearerAuthEnabled: !!process.env.SERVER_BEARER_TOKEN,
    supabaseConnected: !!supabase,
    s3Connected: !!s3
  });
});

// OpenAPI 3.1.0 Spec
app.get('/actions.json', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'actions.json'));
});

// Domain verification is served via static files
// GET /.well-known/openai.json

// ==========================================
// PROTECTED ENDPOINTS (Bearer Token Required)
// ==========================================

// Apply Bearer Auth to all /api/* routes
app.use('/api/*', bearerAuthMiddleware);

// ==========================================
// SUPABASE ENDPOINTS
// ==========================================

// List all tables
app.get('/api/supabase/tables', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    
    const { data, error } = await supabase
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public');
    
    if (error) throw error;
    
    res.json({
      success: true,
      tables: data.map(t => t.table_name)
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to list tables',
      message: error.message
    });
  }
});

// Execute SELECT query
app.post('/api/supabase/query', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    
    const { table, select = '*', filters = {}, limit = 100, offset = 0 } = req.body;
    
    if (!table) {
      return res.status(400).json({ error: 'Table name required' });
    }
    
    let query = supabase.from(table).select(select);
    
    // Apply filters
    Object.entries(filters).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    query = query.limit(limit).range(offset, offset + limit - 1);
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    res.json({
      success: true,
      data,
      count: data.length
    });
  } catch (error) {
    res.status(500).json({
      error: 'Query failed',
      message: error.message
    });
  }
});

// Insert data
app.post('/api/supabase/insert', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    
    const { table, data } = req.body;
    
    if (!table || !data) {
      return res.status(400).json({ error: 'Table and data required' });
    }
    
    const { data: result, error } = await supabase
      .from(table)
      .insert(data)
      .select();
    
    if (error) throw error;
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(500).json({
      error: 'Insert failed',
      message: error.message
    });
  }
});

// Update data
app.put('/api/supabase/update', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    
    const { table, data, filters } = req.body;
    
    if (!table || !data || !filters) {
      return res.status(400).json({ error: 'Table, data, and filters required' });
    }
    
    let query = supabase.from(table).update(data);
    
    // Apply filters
    Object.entries(filters).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { data: result, error } = await query.select();
    
    if (error) throw error;
    
    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    res.status(500).json({
      error: 'Update failed',
      message: error.message
    });
  }
});

// Delete data
app.delete('/api/supabase/delete', async (req, res) => {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Supabase not configured' });
    }
    
    const { table, filters } = req.body;
    
    if (!table || !filters) {
      return res.status(400).json({ error: 'Table and filters required' });
    }
    
    let query = supabase.from(table).delete();
    
    // Apply filters
    Object.entries(filters).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
    
    const { data, error } = await query.select();
    
    if (error) throw error;
    
    res.json({
      success: true,
      deleted: data
    });
  } catch (error) {
    res.status(500).json({
      error: 'Delete failed',
      message: error.message
    });
  }
});

// ==========================================
// S3 ENDPOINTS
// ==========================================

// List buckets
app.get('/api/s3/buckets', async (req, res) => {
  try {
    if (!s3) {
      return res.status(503).json({ error: 'S3 not configured' });
    }
    
    const data = await s3.send(new ListBucketsCommand({}));
    
    res.json({
      success: true,
      buckets: data.Buckets.map(b => ({
        name: b.Name,
        createdAt: b.CreationDate
      }))
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to list buckets',
      message: error.message
    });
  }
});

// List files in bucket
app.get('/api/s3/files', async (req, res) => {
  try {
    if (!s3) {
      return res.status(503).json({ error: 'S3 not configured' });
    }
    
    const bucket = req.query.bucket || process.env.S3_BUCKET;
    const prefix = req.query.prefix || '';
    const maxKeys = parseInt(req.query.maxKeys) || 1000;
    
    if (!bucket) {
      return res.status(400).json({ error: 'Bucket name required' });
    }
    
    const data = await s3.send(new ListObjectsV2Command({
      Bucket: bucket,
      Prefix: prefix,
      MaxKeys: maxKeys
    }));
    
    res.json({
      success: true,
      bucket,
      files: data.Contents.map(f => ({
        key: f.Key,
        size: f.Size,
        lastModified: f.LastModified,
        etag: f.ETag
      })),
      count: data.KeyCount,
      isTruncated: data.IsTruncated
    });
  } catch (error) {
    res.status(500).json({
      error: 'Failed to list files',
      message: error.message
    });
  }
});

// Upload file
app.post('/api/s3/upload', upload.single('file'), async (req, res) => {
  try {
    if (!s3) {
      return res.status(503).json({ error: 'S3 not configured' });
    }
    
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }
    
    const bucket = req.body.bucket || process.env.S3_BUCKET;
    const key = req.body.key || req.file.originalname;
    const contentType = req.file.mimetype;
    
    if (!bucket) {
      return res.status(400).json({ error: 'Bucket name required' });
    }
    
    const params = {
      Bucket: bucket,
      Key: key,
      Body: req.file.buffer,
      ContentType: contentType,
      ACL: 'private'
    };
    
    const result = await s3.send(new PutObjectCommand(params));
    
    res.json({
      success: true,
      file: {
        bucket,
        key,
        etag: result.ETag || null
      }
    });
  } catch (error) {
    res.status(500).json({
      error: 'Upload failed',
      message: error.message
    });
  }
});

// Download file
app.get('/api/s3/download/:key(*)', async (req, res) => {
  try {
    if (!s3) {
      return res.status(503).json({ error: 'S3 not configured' });
    }
    
    const bucket = req.query.bucket || process.env.S3_BUCKET;
    const key = req.params.key;
    
    if (!bucket) {
      return res.status(400).json({ error: 'Bucket name required' });
    }
    
    const params = {
      Bucket: bucket,
      Key: key
    };
    
    const data = await s3.send(new GetObjectCommand(params));
    const streamToBuffer = async (stream) => new Promise((resolve, reject) => {
      const chunks = [];
      stream.on('data', (c) => chunks.push(c));
      stream.on('end', () => resolve(Buffer.concat(chunks)));
      stream.on('error', reject);
    });
    const bodyBuffer = await streamToBuffer(data.Body);

    if (data.ContentType) res.set('Content-Type', data.ContentType);
    if (data.ContentLength) res.set('Content-Length', String(data.ContentLength));
    res.set('Content-Disposition', `attachment; filename="${key.split('/').pop()}"`);
    res.send(bodyBuffer);
  } catch (error) {
    if (error.code === 'NoSuchKey') {
      return res.status(404).json({
        error: 'File not found',
        message: error.message
      });
    }
    
    res.status(500).json({
      error: 'Download failed',
      message: error.message
    });
  }
});

// Delete file
app.delete('/api/s3/delete', async (req, res) => {
  try {
    if (!s3) {
      return res.status(503).json({ error: 'S3 not configured' });
    }
    
    const { bucket = process.env.S3_BUCKET, key } = req.body;
    
    if (!bucket || !key) {
      return res.status(400).json({ error: 'Bucket and key required' });
    }
    
    await s3.send(new DeleteObjectCommand({
      Bucket: bucket,
      Key: key
    }));
    
    res.json({
      success: true,
      message: 'File deleted successfully',
      key
    });
  } catch (error) {
    res.status(500).json({
      error: 'Delete failed',
      message: error.message
    });
  }
});

// ==========================================
// ERROR HANDLING
// ==========================================
app.use((req, res) => {
  res.status(404).json({
    error: 'Not found',
    message: 'The requested endpoint does not exist',
    availableEndpoints: {
      public: [
        'GET /health',
        'GET /actions.json',
        'GET /.well-known/openai.json'
      ],
      protected: [
        'GET /api/supabase/tables',
        'POST /api/supabase/query',
        'POST /api/supabase/insert',
        'PUT /api/supabase/update',
        'DELETE /api/supabase/delete',
        'GET /api/s3/buckets',
        'GET /api/s3/files',
        'POST /api/s3/upload',
        'GET /api/s3/download/:key',
        'DELETE /api/s3/delete'
      ]
    }
  });
});

app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// ==========================================
// START SERVER
// ==========================================
app.listen(PORT, () => {
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║                                                          ║');
  console.log('║   GPT Custom Actions Server - PRODUCTION READY           ║');
  console.log('║                                                          ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log('');
  console.log(`✓ Server running on port ${PORT}`);
  console.log(`✓ Bearer Auth: ${process.env.SERVER_BEARER_TOKEN ? 'ENABLED' : 'DISABLED'}`);
  console.log(`✓ Supabase: ${supabase ? 'CONNECTED' : 'NOT CONFIGURED'}`);
  console.log(`✓ S3: ${s3 ? 'CONNECTED' : 'NOT CONFIGURED'}`);
  console.log('');
  console.log('Public endpoints:');
  console.log(`  - https://${process.env.DOMAIN || 'localhost'}/health`);
  console.log(`  - https://${process.env.DOMAIN || 'localhost'}/.well-known/openai.json`);
  console.log(`  - https://${process.env.DOMAIN || 'localhost'}/actions.json`);
  console.log('');
  console.log('Protected endpoints require Bearer Token in header:');
  console.log('  Authorization: Bearer <your-token>');
  console.log('');
});

module.exports = app;
