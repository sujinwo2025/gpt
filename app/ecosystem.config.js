module.exports = {
  apps: [
    {
      name: 'gpt-custom-actions',
      script: './index.js',
      cwd: '/opt/gpt/app',
      instances: 1,
      exec_mode: 'cluster',
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 3000
      },
      error_file: '/opt/gpt/app/logs/error.log',
      out_file: '/opt/gpt/app/logs/out.log',
      log_file: '/opt/gpt/app/logs/combined.log',
      time: true,
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
    }
  ]
};
