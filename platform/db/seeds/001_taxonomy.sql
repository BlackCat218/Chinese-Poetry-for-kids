INSERT INTO category_types (code, name, multiple_allowed) VALUES
  ('grade', '年级', false),
  ('library', '学习库', false),
  ('topic', '考试高频题材', true),
  ('form', '体裁', false),
  ('era', '时代', false),
  ('object', '古诗与物', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO categories (type_id, code, name, sort_order)
SELECT id, 'grade-' || grade_number, grade_number || '年级', grade_number
FROM category_types CROSS JOIN generate_series(1, 6) AS grade_number
WHERE code = 'grade'
ON CONFLICT (type_id, code) DO NOTHING;

INSERT INTO categories (type_id, code, name, sort_order)
SELECT type_id, code, name, sort_order
FROM (
  SELECT id AS type_id, 'required' AS code, '小学必备' AS name, 1 AS sort_order FROM category_types WHERE code = 'library'
  UNION ALL SELECT id, 'extra', '课外推荐', 2 FROM category_types WHERE code = 'library'
  UNION ALL SELECT id, 'advanced', '进阶学习', 3 FROM category_types WHERE code = 'library'
  UNION ALL SELECT id, 'landscape', '山水田园诗', 1 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'farewell', '送别抒怀诗', 2 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'homesickness', '思乡怀亲诗', 3 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'frontier', '爱国・边塞诗', 4 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'object-aspiration', '咏物言志诗', 5 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'childhood', '童真童趣诗', 6 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'festival', '传统节日诗', 7 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'philosophy', '哲理说理诗', 8 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'history', '咏史怀古诗', 9 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'livelihood', '亲情民生诗', 10 FROM category_types WHERE code = 'topic'
  UNION ALL SELECT id, 'five-jueju', '五言绝句', 1 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'seven-jueju', '七言绝句', 2 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'five-ancient', '五言古诗', 3 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'yuefu', '古乐府', 4 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'regulated', '律诗', 5 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'ci', '词', 6 FROM category_types WHERE code = 'form'
  UNION ALL SELECT id, 'moon', '月亮', 1 FROM category_types WHERE code = 'object'
  UNION ALL SELECT id, 'seasons', '四季', 2 FROM category_types WHERE code = 'object'
  UNION ALL SELECT id, 'flowers', '花木', 3 FROM category_types WHERE code = 'object'
  UNION ALL SELECT id, 'mountains', '山川', 4 FROM category_types WHERE code = 'object'
  UNION ALL SELECT id, 'water', '水', 5 FROM category_types WHERE code = 'object'
) AS seed
ON CONFLICT (type_id, code) DO NOTHING;