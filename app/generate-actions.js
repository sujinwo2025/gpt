require('dotenv').config();
const fs = require('fs');
const path = require('path');

// ==========================================
// OpenAPI 3.1.0 Generator with Bearer Auth
// ==========================================

const DOMAIN = process.env.DOMAIN || 'files.bytrix.my.id';
const SERVER_URL = `https://${DOMAIN}`;

const generateOpenAPI = (mode = 'full') => {
  const spec = {
    openapi: '3.1.0',
    info: {
      title: 'GPT Custom Actions API',
      description: 'Production-ready API for Custom GPT with Supabase CRUD and S3 File Operations. All endpoints require Bearer Token authentication.',
      version: '2.0.0',
      contact: {
        name: 'API Support',
        url: `https://${DOMAIN}`
      }
    },
    servers: [
      {
        url: SERVER_URL,
        description: 'Production server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT-like',
          description: 'Enter your Bearer token. Get it from the server administrator.'
        }
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              description: 'Error type'
            },
            message: {
              type: 'string',
              description: 'Error message'
            }
          }
        },
        SupabaseTable: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean'
            },
            tables: {
              type: 'array',
              items: {
                type: 'string'
              }
            }
          }
        },
        SupabaseQueryRequest: {
          type: 'object',
          required: ['table'],
          properties: {
            table: {
              type: 'string',
              description: 'Table name to query'
            },
            select: {
              type: 'string',
              default: '*',
              description: 'Columns to select (comma-separated or *)'
            },
            filters: {
              type: 'object',
              description: 'Key-value pairs for filtering',
              additionalProperties: true
            },
            limit: {
              type: 'integer',
              default: 100,
              description: 'Maximum number of rows to return'
            },
            offset: {
              type: 'integer',
              default: 0,
              description: 'Number of rows to skip'
            }
          }
        },
        SupabaseInsertRequest: {
          type: 'object',
          required: ['table', 'data'],
          properties: {
            table: {
              type: 'string',
              description: 'Table name'
            },
            data: {
              type: 'object',
              description: 'Data to insert (single object or array)',
              additionalProperties: true
            }
          }
        },
        SupabaseUpdateRequest: {
          type: 'object',
          required: ['table', 'data', 'filters'],
          properties: {
            table: {
              type: 'string',
              description: 'Table name'
            },
            data: {
              type: 'object',
              description: 'Data to update',
              additionalProperties: true
            },
            filters: {
              type: 'object',
              description: 'Key-value pairs for filtering which rows to update',
              additionalProperties: true
            }
          }
        },
        SupabaseDeleteRequest: {
          type: 'object',
          required: ['table', 'filters'],
          properties: {
            table: {
              type: 'string',
              description: 'Table name'
            },
            filters: {
              type: 'object',
              description: 'Key-value pairs for filtering which rows to delete',
              additionalProperties: true
            }
          }
        },
        S3BucketList: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean'
            },
            buckets: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  name: {
                    type: 'string'
                  },
                  createdAt: {
                    type: 'string',
                    format: 'date-time'
                  }
                }
              }
            }
          }
        },
        S3FileList: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean'
            },
            bucket: {
              type: 'string'
            },
            files: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  key: {
                    type: 'string'
                  },
                  size: {
                    type: 'integer'
                  },
                  lastModified: {
                    type: 'string',
                    format: 'date-time'
                  },
                  etag: {
                    type: 'string'
                  }
                }
              }
            },
            count: {
              type: 'integer'
            }
          }
        },
        S3DeleteRequest: {
          type: 'object',
          required: ['key'],
          properties: {
            bucket: {
              type: 'string',
              description: 'Bucket name (optional if default bucket is set)'
            },
            key: {
              type: 'string',
              description: 'Object key/path to delete'
            }
          }
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ],
    paths: {}
  };

  // ==========================================
  // SUPABASE ENDPOINTS
  // ==========================================
  if (mode === 'supabase' || mode === 'full') {
    spec.paths['/api/supabase/tables'] = {
      get: {
        summary: 'List all Supabase tables',
        description: 'Get a list of all tables in the public schema',
        operationId: 'listSupabaseTables',
        tags: ['Supabase'],
        responses: {
          '200': {
            description: 'Successful response',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/SupabaseTable'
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized - Bearer token missing or invalid',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          },
          '503': {
            description: 'Supabase not configured',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/supabase/query'] = {
      post: {
        summary: 'Query Supabase table',
        description: 'Execute a SELECT query on a Supabase table with optional filters',
        operationId: 'querySupabase',
        tags: ['Supabase'],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/SupabaseQueryRequest'
              },
              examples: {
                simple: {
                  summary: 'Simple query',
                  value: {
                    table: 'users',
                    select: '*',
                    limit: 10
                  }
                },
                filtered: {
                  summary: 'Query with filters',
                  value: {
                    table: 'users',
                    select: 'id,name,email',
                    filters: {
                      active: true
                    },
                    limit: 50
                  }
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'Successful query',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    data: {
                      type: 'array',
                      items: {
                        type: 'object'
                      }
                    },
                    count: {
                      type: 'integer'
                    }
                  }
                }
              }
            }
          },
          '400': {
            description: 'Bad request',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/supabase/insert'] = {
      post: {
        summary: 'Insert data into Supabase table',
        description: 'Insert one or more rows into a Supabase table',
        operationId: 'insertSupabase',
        tags: ['Supabase'],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/SupabaseInsertRequest'
              },
              examples: {
                single: {
                  summary: 'Insert single row',
                  value: {
                    table: 'users',
                    data: {
                      name: 'John Doe',
                      email: 'john@example.com'
                    }
                  }
                },
                multiple: {
                  summary: 'Insert multiple rows',
                  value: {
                    table: 'users',
                    data: [
                      { name: 'Alice', email: 'alice@example.com' },
                      { name: 'Bob', email: 'bob@example.com' }
                    ]
                  }
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'Successfully inserted',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    data: {
                      type: 'array',
                      items: {
                        type: 'object'
                      }
                    }
                  }
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/supabase/update'] = {
      put: {
        summary: 'Update Supabase table rows',
        description: 'Update rows in a Supabase table based on filters',
        operationId: 'updateSupabase',
        tags: ['Supabase'],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/SupabaseUpdateRequest'
              },
              example: {
                table: 'users',
                data: {
                  active: false
                },
                filters: {
                  id: 123
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'Successfully updated',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    data: {
                      type: 'array',
                      items: {
                        type: 'object'
                      }
                    }
                  }
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/supabase/delete'] = {
      delete: {
        summary: 'Delete Supabase table rows',
        description: 'Delete rows from a Supabase table based on filters',
        operationId: 'deleteSupabase',
        tags: ['Supabase'],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/SupabaseDeleteRequest'
              },
              example: {
                table: 'users',
                filters: {
                  id: 123
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'Successfully deleted',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    deleted: {
                      type: 'array',
                      items: {
                        type: 'object'
                      }
                    }
                  }
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };
  }

  // ==========================================
  // S3 ENDPOINTS
  // ==========================================
  if (mode === 's3' || mode === 'full') {
    spec.paths['/api/s3/buckets'] = {
      get: {
        summary: 'List S3 buckets',
        description: 'Get a list of all S3 buckets',
        operationId: 'listS3Buckets',
        tags: ['S3'],
        responses: {
          '200': {
            description: 'Successful response',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/S3BucketList'
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          },
          '503': {
            description: 'S3 not configured',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/s3/files'] = {
      get: {
        summary: 'List files in S3 bucket',
        description: 'Get a list of files in a specific S3 bucket with optional prefix filter',
        operationId: 'listS3Files',
        tags: ['S3'],
        parameters: [
          {
            name: 'bucket',
            in: 'query',
            description: 'Bucket name (optional if default bucket is set)',
            schema: {
              type: 'string'
            }
          },
          {
            name: 'prefix',
            in: 'query',
            description: 'Filter files by prefix/folder',
            schema: {
              type: 'string'
            }
          },
          {
            name: 'maxKeys',
            in: 'query',
            description: 'Maximum number of files to return',
            schema: {
              type: 'integer',
              default: 1000
            }
          }
        ],
        responses: {
          '200': {
            description: 'Successful response',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/S3FileList'
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/s3/upload'] = {
      post: {
        summary: 'Upload file to S3',
        description: 'Upload a file to S3 bucket',
        operationId: 'uploadS3File',
        tags: ['S3'],
        requestBody: {
          required: true,
          content: {
            'multipart/form-data': {
              schema: {
                type: 'object',
                required: ['file'],
                properties: {
                  file: {
                    type: 'string',
                    format: 'binary',
                    description: 'File to upload'
                  },
                  bucket: {
                    type: 'string',
                    description: 'Bucket name (optional if default is set)'
                  },
                  key: {
                    type: 'string',
                    description: 'Object key/path (optional, uses filename if not provided)'
                  }
                }
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'File uploaded successfully',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    file: {
                      type: 'object',
                      properties: {
                        bucket: {
                          type: 'string'
                        },
                        key: {
                          type: 'string'
                        },
                        location: {
                          type: 'string'
                        },
                        etag: {
                          type: 'string'
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/s3/download/{key}'] = {
      get: {
        summary: 'Download file from S3',
        description: 'Download a file from S3 bucket',
        operationId: 'downloadS3File',
        tags: ['S3'],
        parameters: [
          {
            name: 'key',
            in: 'path',
            required: true,
            description: 'Object key/path to download',
            schema: {
              type: 'string'
            }
          },
          {
            name: 'bucket',
            in: 'query',
            description: 'Bucket name (optional if default is set)',
            schema: {
              type: 'string'
            }
          }
        ],
        responses: {
          '200': {
            description: 'File download successful',
            content: {
              'application/octet-stream': {
                schema: {
                  type: 'string',
                  format: 'binary'
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          },
          '404': {
            description: 'File not found',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };

    spec.paths['/api/s3/delete'] = {
      delete: {
        summary: 'Delete file from S3',
        description: 'Delete a file from S3 bucket',
        operationId: 'deleteS3File',
        tags: ['S3'],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/S3DeleteRequest'
              },
              example: {
                bucket: 'my-bucket',
                key: 'folder/file.pdf'
              }
            }
          }
        },
        responses: {
          '200': {
            description: 'File deleted successfully',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    success: {
                      type: 'boolean'
                    },
                    message: {
                      type: 'string'
                    },
                    key: {
                      type: 'string'
                    }
                  }
                }
              }
            }
          },
          '401': {
            description: 'Unauthorized',
            content: {
              'application/json': {
                schema: {
                  $ref: '#/components/schemas/Error'
                }
              }
            }
          }
        }
      }
    };
  }

  return spec;
};

// ==========================================
// MAIN EXECUTION
// ==========================================
const mode = process.argv[2] || 'full'; // supabase, s3, or full

console.log(`\n🔧 Generating OpenAPI 3.1.0 spec (mode: ${mode})...\n`);

const spec = generateOpenAPI(mode);

// Ensure public directory exists
const publicDir = path.join(__dirname, 'public');
if (!fs.existsSync(publicDir)) {
  fs.mkdirSync(publicDir, { recursive: true });
}

// Write to public/actions.json
const outputPath = path.join(publicDir, 'actions.json');
fs.writeFileSync(outputPath, JSON.stringify(spec, null, 2));

console.log(`✅ OpenAPI spec generated successfully!`);
console.log(`📄 File: ${outputPath}`);
console.log(`🌐 URL: https://${DOMAIN}/actions.json`);
console.log(`\n🔐 Security Scheme: bearerAuth (HTTP Bearer Token)`);
console.log(`📝 All /api/* endpoints require Authorization header`);
console.log(`\n✨ Ready to import into Custom GPT Actions!\n`);
