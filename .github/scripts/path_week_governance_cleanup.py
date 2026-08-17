from pathlib import Path

p = Path('lib/app/shell/shared/shell_more_menu.dart')
s = p.read_text(encoding='utf-8')

for block in [
    """      'offer' => 'Free / paid',
      'website' => 'Website',
      'licensing' => 'Licensing',
      'support' => 'Support',
""",
    """    'offer' => 'Бесплатное / платное',
    'website' => 'Сайт',
    'licensing' => 'Лицензирование',
    'support' => 'Поддержка',
""",
]:
    s = s.replace(block, '', 1)

p.write_text(s, encoding='utf-8')
