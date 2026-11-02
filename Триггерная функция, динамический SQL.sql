-- ============================================================
-- ЗАДАНИЕ №3. Хранимые процедуры, функции и триггеры
-- ============================================================

-- ---------- Часть 0. Уборка (чтобы можно было запускать повторно) ----------
DROP TABLE IF EXISTS spec CASCADE;
DROP TABLE IF EXISTS test CASCADE;
DROP TABLE IF EXISTS test2 CASCADE;
DROP FUNCTION IF EXISTS get_next_id(text, text) CASCADE;
DROP FUNCTION IF EXISTS enable_column_logging(text, text) CASCADE;
DROP FUNCTION IF EXISTS check_and_update_max() CASCADE;


-- ---------- Часть 1. Создание спец. таблицы (пункты 1-2) ----------
CREATE TABLE spec (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    current_value INTEGER NOT NULL,
    UNIQUE (table_name, column_name)
);

INSERT INTO spec (id, table_name, column_name, current_value) 
VALUES (1, 'spec', 'id', 1);


-- ---------- Часть 2. Создание функции get_next_id (пункт 3) ----------
CREATE OR REPLACE FUNCTION get_next_id(p_table_name text, p_column_name text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_val integer;
    v_max_val integer;
    v_new_id_for_spec integer;
BEGIN
    SELECT current_value INTO v_current_val
    FROM spec
    WHERE table_name = p_table_name AND column_name = p_column_name;

    IF FOUND THEN
        UPDATE spec
        SET current_value = current_value + 1
        WHERE table_name = p_table_name AND column_name = p_column_name
        RETURNING current_value INTO v_current_val;
        
        RETURN v_current_val;
    ELSE
        EXECUTE format('SELECT MAX(%I) FROM %I', p_column_name, p_table_name) INTO v_max_val;

        IF v_max_val IS NULL THEN
            v_current_val := 1;
        ELSE
            v_current_val := v_max_val + 1;
        END IF;

        v_new_id_for_spec := get_next_id('spec', 'id');

        INSERT INTO spec (id, table_name, column_name, current_value)
        VALUES (v_new_id_for_spec, p_table_name, p_column_name, v_current_val);

        RETURN v_current_val;
    END IF;
END;
$$;


-- ---------- Часть 3. Тестирование функции (пункты 4-23) ----------

-- Пункт 4-5
SELECT get_next_id('spec', 'id');
SELECT * FROM spec;

-- Пункт 6-7
SELECT get_next_id('spec', 'id');
SELECT * FROM spec;

-- Пункты 8-11
CREATE TABLE test (id INTEGER);
INSERT INTO test (id) VALUES (10);
SELECT get_next_id('test', 'id');
SELECT * FROM spec;

-- Пункты 12-13
SELECT get_next_id('test', 'id');
SELECT * FROM spec;

-- Пункты 14-16
CREATE TABLE test2 (num_value1 INTEGER, num_value2 INTEGER);
SELECT get_next_id('test2', 'num_value1');
SELECT * FROM spec;

-- Пункты 17-18
SELECT get_next_id('test2', 'num_value1');
SELECT * FROM spec;

-- Пункты 19-21
INSERT INTO test2 (num_value1, num_value2) VALUES (2, 13);
SELECT get_next_id('test2', 'num_value2');
SELECT * FROM spec;

-- Пункты 22-23
SELECT get_next_id('test2', 'num_value1');
SELECT get_next_id('test2', 'num_value1');
SELECT get_next_id('test2', 'num_value1');
SELECT get_next_id('test2', 'num_value1');
SELECT get_next_id('test2', 'num_value1');
SELECT * FROM spec;


-- ---------- Часть 4. Триггерная функция (пункт 26) ----------
CREATE OR REPLACE FUNCTION check_and_update_max()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_in_table integer;
    v_current_spec integer;
BEGIN
    EXECUTE format('SELECT MAX(%I) FROM %I', TG_ARGV[0], TG_TABLE_NAME) INTO v_max_in_table;
    
    IF v_max_in_table IS NULL THEN
        v_max_in_table := 1;
    END IF;

    SELECT current_value INTO v_current_spec
    FROM spec
    WHERE table_name = TG_TABLE_NAME AND column_name = TG_ARGV[0];

    IF v_current_spec IS NULL THEN
        INSERT INTO spec (id, table_name, column_name, current_value)
        VALUES (get_next_id('spec', 'id'), TG_TABLE_NAME, TG_ARGV[0], v_max_in_table);
    ELSIF v_max_in_table > v_current_spec THEN
        UPDATE spec
        SET current_value = v_max_in_table
        WHERE table_name = TG_TABLE_NAME AND column_name = TG_ARGV[0];
    END IF;

    RETURN NEW;
END;
$$;


-- ---------- Часть 5. Функция автоматического создания триггера ----------
CREATE OR REPLACE FUNCTION enable_column_logging(p_table_name text, p_column_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_trigger_name text;
BEGIN
    v_trigger_name := 'trg_check_' || p_table_name || '_' || p_column_name;
    
    EXECUTE format(
        'CREATE TRIGGER %I
         AFTER INSERT OR UPDATE OF %I ON %I
         FOR EACH ROW
         EXECUTE FUNCTION check_and_update_max(%L)',
        v_trigger_name,
        p_column_name,
        p_table_name,
        p_column_name
    );
    
    RAISE NOTICE 'Триггер % создан для таблицы %.', v_trigger_name, p_table_name;
END;
$$;


-- ---------- Часть 6. Тестирование триггеров (пункт 26) ----------

-- Тест 1: таблица test
SELECT enable_column_logging('test', 'id');
INSERT INTO test (id) VALUES (50);
SELECT * FROM spec WHERE table_name = 'test';

-- Тест 2: таблица test2
SELECT enable_column_logging('test2', 'num_value1');
INSERT INTO test2 (num_value1) VALUES (100);
SELECT * FROM spec WHERE table_name = 'test2' AND column_name = 'num_value1';


-- ---------- Часть 7. Уборка (пункты 24-25) ----------
DROP FUNCTION IF EXISTS get_next_id(text, text) CASCADE;
DROP FUNCTION IF EXISTS enable_column_logging(text, text) CASCADE;
DROP FUNCTION IF EXISTS check_and_update_max() CASCADE;

DROP TABLE IF EXISTS spec CASCADE;
DROP TABLE IF EXISTS test CASCADE;
DROP TABLE IF EXISTS test2 CASCADE;