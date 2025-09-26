-- PostgreSQL initialization script for Apogee
-- Creates database schema and initial indexes

-- Enable UUID extension for better ID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable JSONB operations extension
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    base_xp INTEGER DEFAULT 0,
    today_xp INTEGER DEFAULT 0,
    tomorrow_xp INTEGER DEFAULT 0,
    coins INTEGER DEFAULT 0,
    diamonds INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    current_streak INTEGER DEFAULT 0,
    max_streak INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_xp_reset TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_sync_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    device_id VARCHAR(255) NOT NULL,
    sync_version INTEGER DEFAULT 1,

    -- Constraints
    CONSTRAINT users_email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT users_base_xp_positive CHECK (base_xp >= 0),
    CONSTRAINT users_today_xp_positive CHECK (today_xp >= 0),
    CONSTRAINT users_tomorrow_xp_positive CHECK (tomorrow_xp >= 0),
    CONSTRAINT users_coins_positive CHECK (coins >= 0),
    CONSTRAINT users_diamonds_positive CHECK (diamonds >= 0),
    CONSTRAINT users_level_positive CHECK (level >= 1),
    CONSTRAINT users_streaks_positive CHECK (current_streak >= 0 AND max_streak >= 0),
    CONSTRAINT users_sync_version_positive CHECK (sync_version >= 1)
);

-- Create user authentication table
CREATE TABLE IF NOT EXISTS user_auth (
    user_id VARCHAR(255) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_password_change TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT user_auth_email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Create task templates table
CREATE TABLE IF NOT EXISTS task_templates (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    coins INTEGER NOT NULL,
    user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recurrency_type VARCHAR(50) NOT NULL,
    custom_days INTEGER[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_generated TIMESTAMP WITH TIME ZONE,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    streak_data JSONB NOT NULL DEFAULT '{}',

    -- Constraints
    CONSTRAINT task_templates_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT task_templates_coins_positive CHECK (coins >= 0),
    CONSTRAINT task_templates_recurrency_valid CHECK (
        recurrency_type IN ('none', 'daily', 'weekly', 'monthly', 'custom')
    ),
    CONSTRAINT task_templates_date_range_valid CHECK (
        start_date IS NULL OR end_date IS NULL OR start_date <= end_date
    )
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    coins INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP WITH TIME ZONE,
    is_late BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    template_id VARCHAR(255) NOT NULL REFERENCES task_templates(id) ON DELETE CASCADE,
    scheduled_date DATE NOT NULL,

    -- Constraints
    CONSTRAINT tasks_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
    CONSTRAINT tasks_coins_positive CHECK (coins >= 0),
    CONSTRAINT tasks_status_valid CHECK (
        status IN ('pending', 'completed', 'not_necessary', 'not_did')
    ),
    CONSTRAINT tasks_completion_logic CHECK (
        (status = 'pending' AND completed_at IS NULL) OR
        (status != 'pending' AND completed_at IS NOT NULL)
    )
);

-- Create sync log table for tracking changes
CREATE TABLE IF NOT EXISTS sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(255) NOT NULL,
    operation VARCHAR(20) NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    sync_version INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT sync_log_entity_type_valid CHECK (
        entity_type IN ('user', 'task_template', 'task')
    ),
    CONSTRAINT sync_log_operation_valid CHECK (
        operation IN ('create', 'update', 'delete')
    )
);

-- Create performance indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);
CREATE INDEX IF NOT EXISTS idx_users_last_sync ON users(last_sync_at);

CREATE INDEX IF NOT EXISTS idx_user_auth_email ON user_auth(email);

CREATE INDEX IF NOT EXISTS idx_task_templates_user_id ON task_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_task_templates_user_active ON task_templates(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_task_templates_last_modified ON task_templates(last_modified);

CREATE INDEX IF NOT EXISTS idx_tasks_template_id ON tasks(template_id);
CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_date ON tasks(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_tasks_template_date ON tasks(template_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at);

CREATE INDEX IF NOT EXISTS idx_sync_log_user_id ON sync_log(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_timestamp ON sync_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_sync_log_entity ON sync_log(entity_type, entity_id);

-- Create JSONB indexes for better query performance on streak data
CREATE INDEX IF NOT EXISTS idx_task_templates_streak_data ON task_templates USING gin (streak_data);

-- Create functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for automatic updated_at on tasks
CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function for automatic last_modified update on task_templates
CREATE OR REPLACE FUNCTION update_last_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for automatic last_modified on task_templates
CREATE TRIGGER update_task_templates_last_modified
    BEFORE UPDATE ON task_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_last_modified_column();

-- Create function to log sync operations
CREATE OR REPLACE FUNCTION log_sync_operation()
RETURNS TRIGGER AS $$
BEGIN
    -- Determine operation type
    DECLARE
        op_type VARCHAR(20);
        entity_type VARCHAR(50);
        entity_id VARCHAR(255);
        user_id_val VARCHAR(255);
    BEGIN
        IF TG_OP = 'DELETE' then
            op_type = 'delete';
            entity_id = OLD.id;
            IF TG_TABLE_NAME = 'users' THEN
                entity_type = 'user';
                user_id_val = OLD.id;
            ELSIF TG_TABLE_NAME = 'task_templates' THEN
                entity_type = 'task_template';
                user_id_val = OLD.user_id;
            ELSIF TG_TABLE_NAME = 'tasks' THEN
                entity_type = 'task';
                -- Get user_id from template
                SELECT user_id INTO user_id_val FROM task_templates WHERE id = OLD.template_id;
            END IF;
        ELSE
            entity_id = NEW.id;
            IF TG_TABLE_NAME = 'users' THEN
                entity_type = 'user';
                user_id_val = NEW.id;
            ELSIF TG_TABLE_NAME = 'task_templates' THEN
                entity_type = 'task_template';
                user_id_val = NEW.user_id;
            ELSIF TG_TABLE_NAME = 'tasks' THEN
                entity_type = 'task';
                -- Get user_id from template
                SELECT user_id INTO user_id_val FROM task_templates WHERE id = NEW.template_id;
            END IF;

            IF TG_OP = 'INSERT' THEN
                op_type = 'create';
            ELSE
                op_type = 'update';
            END IF;
        END IF;

        -- Insert sync log entry
        INSERT INTO sync_log (user_id, entity_type, entity_id, operation, device_id, sync_version)
        VALUES (
            user_id_val,
            entity_type,
            entity_id,
            op_type,
            COALESCE(NEW.device_id, OLD.device_id, 'server'),
            COALESCE(NEW.sync_version, OLD.sync_version, 1)
        );

        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END;
END;
$$ language 'plpgsql';

-- Create sync logging triggers
CREATE TRIGGER sync_log_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_sync_operation();

CREATE TRIGGER sync_log_task_templates_trigger
    AFTER INSERT OR UPDATE OR DELETE ON task_templates
    FOR EACH ROW EXECUTE FUNCTION log_sync_operation();

CREATE TRIGGER sync_log_tasks_trigger
    AFTER INSERT OR UPDATE OR DELETE ON tasks
    FOR EACH ROW EXECUTE FUNCTION log_sync_operation();

-- Insert initial data (optional, for testing)
-- This will be automatically removed in production
DO $$
BEGIN
    -- Check if we're in development mode
    IF current_setting('server_version_num')::int >= 140000 THEN
        -- Only insert test data if no users exist
        IF NOT EXISTS (SELECT 1 FROM users LIMIT 1) THEN
            INSERT INTO users (
                id, email, display_name, device_id
            ) VALUES (
                'test_user_001',
                'test@apogee.dev',
                'Test User',
                'test_device'
            );

            INSERT INTO user_auth (
                user_id, email, password_hash
            ) VALUES (
                'test_user_001',
                'test@apogee.dev',
                '$2a$10$example.hash.for.development.only'
            );
        END IF;
    END IF;
END $$;

-- Create views for common queries
CREATE OR REPLACE VIEW user_summary AS
SELECT
    u.id,
    u.email,
    u.display_name,
    u.base_xp + u.today_xp + u.tomorrow_xp as total_xp,
    u.coins,
    u.diamonds,
    u.level,
    u.current_streak,
    u.max_streak,
    u.last_login_at,
    COUNT(tt.id) as template_count,
    COUNT(CASE WHEN tt.is_active THEN 1 END) as active_templates
FROM users u
LEFT JOIN task_templates tt ON u.id = tt.user_id
GROUP BY u.id;

-- Grant appropriate permissions (if needed for specific user)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO apogee_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO apogee_user;

COMMENT ON DATABASE apogee IS 'Apogee Habit Tracker Database - PostgreSQL Edition';
COMMENT ON TABLE users IS 'User accounts with gamification data';
COMMENT ON TABLE user_auth IS 'User authentication credentials (separate for security)';
COMMENT ON TABLE task_templates IS 'Templates for generating recurring tasks';
COMMENT ON TABLE tasks IS 'Individual task instances generated from templates';
COMMENT ON TABLE sync_log IS 'Audit log for sync operations and conflict resolution';