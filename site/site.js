const languages = [
  ['en', 'English'], ['zh-Hans', '简体中文'], ['zh-Hant', '繁體中文'],
  ['ja', '日本語'], ['ko', '한국어'], ['fr', 'Français'], ['de', 'Deutsch'],
  ['es', 'Español'], ['it', 'Italiano'], ['pt-BR', 'Português (Brasil)'],
  ['ru', 'Русский'], ['ar', 'العربية'], ['hi', 'हिन्दी']
];
const picker = document.querySelector('.language-picker');
const trigger = document.querySelector('#language');
const menu = document.querySelector('#language-menu');
const label = document.querySelector('#language-label');
const translations = typeof websiteTranslations === 'undefined' ? {} : websiteTranslations;
let currentLanguage = 'en';

/** 兼容旧中文偏好，匹配系统地区语言，未知语言使用英语。 */
function matchLanguage(value) {
  if (!value) return null;
  const code = value.toLowerCase();
  if (code.startsWith('zh')) return /hant|tw|hk|mo/.test(code) ? 'zh-Hant' : 'zh-Hans';
  return languages.find(([language]) => language.toLowerCase().split('-')[0] === code.split('-')[0])?.[0] || null;
}

/** 优先沿用本机选择，否则依次匹配浏览器首选语言。 */
function preferredLanguage() {
  try { const saved = matchLanguage(localStorage.getItem('nightfall-language')); if (saved) return saved; } catch (_) { /* 存储被禁用时跟随系统。 */ }
  return (navigator.languages || [navigator.language]).map(matchLanguage).find(Boolean) || 'en';
}

/** 使用随网站分发的静态文案；缺失资源时仍保留英语内容。 */
function translated(text, language = currentLanguage) {
  return language === 'en' ? text : translations[language]?.[text] || text;
}

/** 更新正文、标题、辅助标签和阅读方向，语言偏好只保存在浏览器。 */
function applyLanguage(language) {
  currentLanguage = matchLanguage(language) || 'en';
  document.documentElement.lang = currentLanguage;
  document.documentElement.dir = currentLanguage === 'ar' ? 'rtl' : 'ltr';
  document.querySelectorAll('[data-en]').forEach(node => {
    node.textContent = currentLanguage === 'zh-Hans' && node.dataset.zh ? node.dataset.zh : translated(node.dataset.en);
  });
  document.querySelectorAll('[data-label-en]').forEach(node => node.setAttribute('aria-label', translated(node.dataset.labelEn)));
  document.querySelectorAll('[data-alt-en]').forEach(node => node.alt = translated(node.dataset.altEn));
  label.textContent = languages.find(([code]) => code === currentLanguage)[1];
  menu.querySelectorAll('[data-locale]').forEach(option => option.setAttribute('aria-checked', String(option.dataset.locale === currentLanguage)));
  try { localStorage.setItem('nightfall-language', currentLanguage); } catch (_) { /* 私密浏览或存储限制不影响内容。 */ }
}

/** 打开菜单时将焦点移至当前语言，箭头和展开状态保持一致。 */
function openLanguageMenu(index = languages.findIndex(([code]) => code === currentLanguage)) {
  menu.hidden = false;
  trigger.setAttribute('aria-expanded', 'true');
  focusLanguageOption(index);
}

/** 收起菜单，可将键盘焦点返回语言按钮。 */
function closeLanguageMenu(restoreFocus = false) {
  menu.hidden = true;
  trigger.setAttribute('aria-expanded', 'false');
  if (restoreFocus) trigger.focus();
}

/** 循环移动语言焦点并仅滚动菜单内部，避免跳动页面。 */
function focusLanguageOption(index) {
  const options = [...menu.querySelectorAll('[data-locale]')];
  const option = options[(index + options.length) % options.length];
  option.focus({ preventScroll: true });
  option.scrollIntoView({ block: 'nearest' });
}

/** 鼠标或触屏点击语言按钮时切换展开状态。 */
function toggleLanguageMenu() {
  if (menu.hidden) openLanguageMenu(); else closeLanguageMenu(true);
}

/** 方向键从语言按钮进入菜单，保留原生 Enter 和空格操作。 */
function handleTriggerKey(event) {
  if (!['ArrowDown', 'ArrowUp'].includes(event.key)) return;
  event.preventDefault();
  openLanguageMenu(event.key === 'ArrowDown' ? 0 : languages.length - 1);
}

/** 菜单支持方向键、首末项、字母定位及 Escape 返回，Tab 正常离开。 */
function handleMenuKey(event) {
  const options = [...menu.querySelectorAll('[data-locale]')];
  const index = options.indexOf(document.activeElement);
  if (event.key === 'Escape') { event.preventDefault(); closeLanguageMenu(true); return; }
  if (event.key === 'Tab') { closeLanguageMenu(true); return; }
  const movements = { ArrowDown: index + 1, ArrowUp: index - 1, Home: 0, End: options.length - 1 };
  if (event.key in movements) { event.preventDefault(); focusLanguageOption(movements[event.key]); return; }
  if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey && event.key !== ' ') {
    const match = options.findIndex(option => option.textContent.toLocaleLowerCase().startsWith(event.key.toLocaleLowerCase()));
    if (match !== -1) { event.preventDefault(); focusLanguageOption(match); }
  }
}

/** 选择语言后即时更新所有内容，再收起菜单。 */
function selectLanguage(event) {
  const option = event.target.closest('[data-locale]');
  if (!option) return;
  applyLanguage(option.dataset.locale);
  closeLanguageMenu(true);
}

/** 点击菜单之外或离开语言控件时收起，避免遮挡页面内容。 */
function dismissLanguageMenu(event) {
  const target = event.type === 'focusout' ? event.relatedTarget : event.target;
  if (!picker.contains(target)) closeLanguageMenu();
}

/** 创建统一语言菜单并保留现有图片、导航的辅助标签翻译来源。 */
function initializeLanguagePicker() {
  for (const [code, name] of languages) {
    const option = document.createElement('button');
    option.type = 'button';
    option.className = 'language-option';
    option.dataset.locale = code;
    option.lang = code;
    option.dir = 'auto';
    option.tabIndex = -1;
    option.setAttribute('role', 'menuitemradio');
    option.setAttribute('aria-checked', 'false');
    option.textContent = name;
    menu.append(option);
  }
  document.querySelectorAll('[aria-label]').forEach(node => { node.dataset.labelEn = node.getAttribute('aria-label'); });
  document.querySelectorAll('img[alt]').forEach(node => { if (node.alt) node.dataset.altEn = node.alt; });
  trigger.addEventListener('click', toggleLanguageMenu);
  trigger.addEventListener('keydown', handleTriggerKey);
  menu.addEventListener('keydown', handleMenuKey);
  menu.addEventListener('click', selectLanguage);
  picker.addEventListener('focusout', dismissLanguageMenu);
  document.addEventListener('pointerdown', dismissLanguageMenu);
  applyLanguage(preferredLanguage());
}

/** 仅切换真实摄影静态预览，不下载视频或自动发声。 */
function previewScene(button) {
  document.querySelectorAll('[data-preview]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  document.body.dataset.scene = button.dataset.preview;
  const image = document.querySelector('.cover');
  if (button.dataset.preview !== 'black') {
    image.src = 'assets/' + button.dataset.preview + '.jpg';
    const alt = { aurora: 'Northern lights filmed in Lapland', ocean: 'Ocean', ember: 'Fireplace' }[button.dataset.preview];
    image.dataset.altEn = alt;
    image.alt = translated(alt);
  }
}

initializeLanguagePicker();
document.querySelectorAll('[data-preview]').forEach(button => button.addEventListener('click', () => previewScene(button)));
