import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'nexusedu_ultra.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── DERSLER ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE subjects (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        color_hex   TEXT    NOT NULL DEFAULT '#00E676',
        teacher     TEXT,
        weekly_hours INTEGER DEFAULT 0,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── NOTLAR (sınav / yazılı) ───────────────────────────────
    await db.execute('''
      CREATE TABLE grades (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id  INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
        exam_name   TEXT    NOT NULL,
        score       REAL    NOT NULL,
        max_score   REAL    NOT NULL DEFAULT 100,
        exam_date   TEXT    NOT NULL,
        weight      REAL    NOT NULL DEFAULT 1.0,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── ÖDEVLER ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE homework (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id      INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
        title           TEXT    NOT NULL,
        description     TEXT,
        due_date        TEXT    NOT NULL,
        urgency         INTEGER NOT NULL DEFAULT 2,
        importance      INTEGER NOT NULL DEFAULT 2,
        quadrant        TEXT    NOT NULL DEFAULT 'plan',
        is_completed    INTEGER NOT NULL DEFAULT 0,
        ai_analyzed     INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    // quadrant: 'do_now' | 'plan' | 'delegate' | 'eliminate'

    // ── FLASHCARD DESTELERİ ───────────────────────────────────
    await db.execute('''
      CREATE TABLE flashcard_decks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id  INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
        title       TEXT    NOT NULL,
        description TEXT,
        card_count  INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── FLASHCARD'LAR ─────────────────────────────────────────
    await db.execute('''
      CREATE TABLE flashcards (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id         INTEGER NOT NULL REFERENCES flashcard_decks(id) ON DELETE CASCADE,
        question        TEXT    NOT NULL,
        answer          TEXT    NOT NULL,
        difficulty      TEXT    NOT NULL DEFAULT 'new',
        next_review     TEXT    NOT NULL DEFAULT (datetime('now')),
        interval_days   INTEGER NOT NULL DEFAULT 1,
        ease_factor     REAL    NOT NULL DEFAULT 2.5,
        review_count    INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    -- difficulty: 'new' | 'again' | 'hard' | 'good' | 'easy'

    // ── POMODORO SEANSLAR ─────────────────────────────────────
    await db.execute('''
      CREATE TABLE pomodoro_sessions (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id    INTEGER REFERENCES subjects(id) ON DELETE SET NULL,
        duration_min  INTEGER NOT NULL DEFAULT 25,
        break_min     INTEGER NOT NULL DEFAULT 5,
        completed     INTEGER NOT NULL DEFAULT 0,
        focus_score   REAL    NOT NULL DEFAULT 0,
        started_at    TEXT    NOT NULL,
        ended_at      TEXT,
        notes         TEXT
      )
    ''');

    // ── BÜTÇE KAYITLARI ───────────────────────────────────────
    await db.execute('''
      CREATE TABLE budget_entries (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        type        TEXT    NOT NULL DEFAULT 'expense',
        amount      REAL    NOT NULL,
        category    TEXT    NOT NULL DEFAULT 'genel',
        description TEXT,
        entry_date  TEXT    NOT NULL DEFAULT (date('now')),
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    -- type: 'income' | 'expense'

    // ── GÜNLÜK BÜTÇE LİMİTİ ──────────────────────────────────
    await db.execute('''
      CREATE TABLE budget_settings (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_allowance REAL    NOT NULL DEFAULT 50.0,
        weekly_limit    REAL    NOT NULL DEFAULT 300.0,
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    await db.insert('budget_settings', {
      'daily_allowance': 50.0,
      'weekly_limit': 300.0,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // ── DEVAMSIZLIK ───────────────────────────────────────────
    await db.execute('''
      CREATE TABLE absences (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id  INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
        absence_date TEXT   NOT NULL,
        type        TEXT    NOT NULL DEFAULT 'unexcused',
        reason      TEXT,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    -- type: 'excused' | 'unexcused'

    // ── DEVAMSIZLIK LİMİTLERİ ────────────────────────────────
    await db.execute('''
      CREATE TABLE absence_limits (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id      INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
        max_excused     INTEGER NOT NULL DEFAULT 14,
        max_unexcused   INTEGER NOT NULL DEFAULT 10,
        warn_at_percent REAL    NOT NULL DEFAULT 0.7
      )
    ''');

    // ── STRES / BURNOUT ANKETLERİ ─────────────────────────────
    await db.execute('''
      CREATE TABLE burnout_surveys (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        energy_level    INTEGER NOT NULL,
        stress_level    INTEGER NOT NULL,
        motivation      INTEGER NOT NULL,
        sleep_quality   INTEGER NOT NULL,
        ai_analysis     TEXT,
        recommendation  TEXT,
        survey_date     TEXT    NOT NULL DEFAULT (date('now')),
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── MEB DUYURULARI ────────────────────────────────────────
    await db.execute('''
      CREATE TABLE meb_announcements (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        raw_title       TEXT    NOT NULL,
        raw_content     TEXT,
        source_url      TEXT,
        ai_title        TEXT,
        ai_summary      TEXT,
        ai_action       TEXT,
        impact_level    TEXT    NOT NULL DEFAULT 'Normal',
        affected_student INTEGER NOT NULL DEFAULT 0,
        is_read         INTEGER NOT NULL DEFAULT 0,
        fetched_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── ÇALIŞMA PROGRAMI (AI üretimi) ────────────────────────
    await db.execute('''
      CREATE TABLE study_plans (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_date       TEXT    NOT NULL,
        subject_id      INTEGER REFERENCES subjects(id) ON DELETE CASCADE,
        task_title      TEXT    NOT NULL,
        duration_min    INTEGER NOT NULL DEFAULT 30,
        priority        INTEGER NOT NULL DEFAULT 2,
        is_completed    INTEGER NOT NULL DEFAULT 0,
        ai_generated    INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── ODAKLANMA ANALİTİĞİ (günlük özet) ────────────────────
    await db.execute('''
      CREATE TABLE focus_analytics (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        analytics_date  TEXT    NOT NULL UNIQUE,
        total_focus_min INTEGER NOT NULL DEFAULT 0,
        sessions_count  INTEGER NOT NULL DEFAULT 0,
        focus_score     REAL    NOT NULL DEFAULT 0,
        best_subject    TEXT,
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── İNDEKSLER ────────────────────────────────────────────
    await db.execute('CREATE INDEX idx_grades_subject ON grades(subject_id)');
    await db.execute('CREATE INDEX idx_homework_due ON homework(due_date)');
    await db.execute('CREATE INDEX idx_flashcards_review ON flashcards(next_review)');
    await db.execute('CREATE INDEX idx_absences_date ON absences(absence_date)');
    await db.execute('CREATE INDEX idx_budget_date ON budget_entries(entry_date)');
    await db.execute('CREATE INDEX idx_meb_read ON meb_announcements(is_read)');
    await db.execute('CREATE INDEX idx_study_date ON study_plans(plan_date)');

    // ── BAŞLANGIÇ VERİLERİ ────────────────────────────────────
    final defaultSubjects = [
      {'name': 'Matematik',    'color_hex': '#FF6B6B'},
      {'name': 'Türkçe',       'color_hex': '#4ECDC4'},
      {'name': 'Fen Bilimleri','color_hex': '#45B7D1'},
      {'name': 'Sosyal Bilgiler','color_hex': '#96CEB4'},
      {'name': 'İngilizce',    'color_hex': '#FFEAA7'},
      {'name': 'Din Kültürü',  'color_hex': '#DDA0DD'},
      {'name': 'Beden Eğitimi','color_hex': '#98D8C8'},
    ];
    for (final subject in defaultSubjects) {
      await db.insert('subjects', {
        ...subject,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ── GENERIC CRUD ──────────────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
