//+------------------------------------------------------------------+
//|                                      Universal Trailing Stop Loss Library |
//|                                      File: TrailingStopManager.mqh |
//|                                      Version: 5.2 (Improved with Extra Checks) |
//|                                      © 2025, Mohammad & Gemini |
//|                                                                  |
//| تغییرات در نسخه 5.2:                                                     |
//| - اضافه کردن چک اضافی در CalculatePsarSL و CalculateChandelierAtrSL برای جلوگیری از SL نامعتبر (عبور از قیمت فعلی). |
//| - کامنت‌گذاری کامل‌تر برای تمام توابع بدون هیچ ساده‌سازی یا حذف.         |
//| - هیچ تغییری در منطق اصلی ایجاد نشده، فقط بهبود ایمنی.                     |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "5.2"
#include <Trade\Trade.mqh>

//================================================================================//
// بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play
//================================================================//
input group "---=== 🛡️ Universal Trailing & Breakeven 🛡️ ===---"; // گروه تنظیمات اصلی برای تریلینگ و سربه‌سر
input bool Inp_TSL_Enable = true; // فعال/غیرفعال کردن تریلینگ استاپ لاس کلی
input double Inp_TSL_Activation_RR = 1.0; // نسبت ریسک به ریوارد برای فعال‌سازی تریلینگ (مثلاً 1.0 یعنی وقتی سود = ریسک اولیه)
input bool Inp_BE_Enable = true; // فعال/غیرفعال کردن سربه‌سر (Breakeven)
input double Inp_BE_Activation_RR = 1.0; // نسبت ریسک به ریوارد برای فعال‌سازی سربه‌سر
input double Inp_BE_Plus_Pips = 1.0; // تعداد پیپ اضافی برای سربه‌سر (مثلاً +1 پیپ بالاتر از قیمت ورود برای خرید)
enum E_TSL_Mode { TSL_MODE_TENKAN, TSL_MODE_KIJUN, TSL_MODE_MA, TSL_MODE_ATR, TSL_MODE_PSAR, TSL_MODE_PRICE_CHANNEL, TSL_MODE_CHANDELIER_ATR }; // انواع مودهای تریلینگ
input E_TSL_Mode Inp_TSL_Mode = TSL_MODE_TENKAN; // انتخاب مود تریلینگ پیش‌فرض (تنکان ایچیموکو)
/*input*/ double Inp_TSL_Buffer_Pips = 3.0; // بافر اضافی در پیپ برای مودهای خطی (مانند تنکان، کیجون، MA)
/*input*/ int Inp_TSL_Ichimoku_Tenkan = 9; // دوره تنکان برای مود ایچیموکو
/*input*/ int Inp_TSL_Ichimoku_Kijun = 26; // دوره کیجون برای مود ایچیموکو
/*input*/ int Inp_TSL_Ichimoku_Senkou = 52; // دوره سنکو برای مود ایچیموکو
/*input*/ int Inp_TSL_MA_Period = 50; // دوره میانگین متحرک برای مود MA
/*input*/ ENUM_MA_METHOD Inp_TSL_MA_Method = MODE_SMA; // روش محاسبه MA (SMA, EMA, etc.)
/*input*/ ENUM_APPLIED_PRICE Inp_TSL_MA_Price = PRICE_CLOSE; // نوع قیمت برای MA (Close, High, Low, etc.)
/*input*/ int Inp_TSL_ATR_Period = 14; // دوره ATR برای مود ATR
/*input*/ double Inp_TSL_ATR_Multiplier = 2.5; // ضریب ATR برای محاسبه آفست
/*input*/ double Inp_TSL_PSAR_Step = 0.02; // گام PSAR برای مود PSAR
/*input*/ double Inp_TSL_PSAR_Max = 0.2; // حداکثر PSAR
/*input*/ int Inp_TSL_PriceChannel_Period = 22; // دوره پرایس چنل برای مود Price Channel

//+------------------------------------------------------------------+
//| ساختارهای داخلی برای مدیریت بهینه هندل‌ها و وضعیت تریدها          |
//+------------------------------------------------------------------+
struct SIndicatorHandle
{
  string symbol; // نماد مرتبط با هندل (برای مدیریت چندنمادی)
  int    handle; // هندل اندیکاتور
};

struct STradeState
{
  ulong  ticket; // تیکت پوزیشن
  double open_price; // قیمت ورود پوزیشن
  double initial_sl; // استاپ لاس اولیه (برای محاسبه ریسک)
  bool   be_applied; // فلگ آیا سربه‌سر اعمال شده یا نه
};

//+------------------------------------------------------------------+
//| کلاس اصلی مدیریت حد ضرر متحرک                                     |
//+------------------------------------------------------------------+
class CTrailingStopManager
{
private:
  long               m_magic_number; // مجیک نامبر اکسپرت برای فیلتر پوزیشن‌ها
  bool               m_is_initialized; // فلگ آیا کلاس اولیه‌سازی شده
  CTrade             m_trade; // شیء ترید برای مدیریت پوزیشن‌ها (PositionModify)

  // --- تنظیمات (کپی از ورودی‌ها برای دسترسی سریع) ---
  bool               m_tsl_enabled, m_be_enabled; // فعال/غیرفعال تریلینگ و سربه‌سر
  double             m_activation_rr, m_be_activation_rr, m_be_plus_pips; // نسبت‌ها و پیپ اضافی
  E_TSL_Mode         m_tsl_mode; // مود انتخابی تریلینگ
  double             m_buffer_pips; // بافر پیپ برای مودهای خطی
  int                m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou; // دوره‌های ایچیموکو
  int                m_ma_period; // دوره MA
  ENUM_MA_METHOD     m_ma_method; // روش MA
  ENUM_APPLIED_PRICE m_ma_price; // قیمت MA
  int                m_atr_period; // دوره ATR
  double             m_atr_multiplier; // ضریب ATR
  double             m_psar_step, m_psar_max; // پارامترهای PSAR
  int                m_pricechannel_period; // دوره پرایس چنل

  // --- مدیریت حالت (برای هر پوزیشن) ---
  STradeState        m_trade_states[]; // آرایه وضعیت پوزیشن‌ها (برای جلوگیری از محاسبات تکراری)

  // --- مدیریت هندل‌ها (برای جلوگیری از ایجاد تکراری) ---
  SIndicatorHandle   m_ichimoku_handles[]; // هندل‌های ایچیموکو برای هر نماد
  SIndicatorHandle   m_ma_handles[]; // هندل‌های MA
  SIndicatorHandle   m_atr_handles[]; // هندل‌های ATR
  SIndicatorHandle   m_psar_handles[]; // هندل‌های PSAR

  // --- توابع کمکی خصوصی ---
  int    GetIchimokuHandle(string symbol); // گرفتن یا ایجاد هندل ایچیموکو برای نماد
  int    GetMaHandle(string symbol); // گرفتن یا ایجاد هندل MA
  int    GetAtrHandle(string symbol); // گرفتن یا ایجاد هندل ATR
  int    GetPsarHandle(string symbol); // گرفتن یا ایجاد هندل PSAR
  void   Log(string message); // تابع لاگ کردن پیام‌ها (با پیشوند مجیک نامبر)
  void   ManageSingleTrade(ulong ticket); // مدیریت تریلینگ و سربه‌سر برای یک پوزیشن خاص
  int    FindTradeStateIndex(ulong ticket); // پیدا کردن ایندکس وضعیت پوزیشن در آرایه
  void   AddTradeState(ulong ticket, double open_price, double initial_sl); // اضافه کردن وضعیت جدید پوزیشن
  void   CleanupTradeStates(); // پاکسازی وضعیت پوزیشن‌های بسته شده از آرایه

  double CalculateIchimokuSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس ایچیموکو (تنکان یا کیجون)
  double CalculateMaSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس MA
  double CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس ATR
  double CalculatePsarSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس PSAR (با چک اضافی برای جلوگیری از عبور)
  double CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس پرایس چنل
  double CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type); // محاسبه SL بر اساس Chandelier ATR (با چک اضافی)
  void   ManageBreakeven(int state_idx); // مدیریت سربه‌سر برای یک پوزیشن

public:
  CTrailingStopManager() { m_magic_number = 0; m_is_initialized = false; } // کانستراکتور پیش‌فرض (ریست اولیه)
  ~CTrailingStopManager(); // دیستراکتور برای آزاد کردن هندل‌ها
  void Init(long magic_number); // اولیه‌سازی کلاس با مجیک نامبر
  void Process(); // تابع اصلی پردازش (روی تمام پوزیشن‌ها)
};

//+------------------------------------------------------------------+
//| دیستراکتور کلاس (آزاد کردن منابع)                                 |
//+------------------------------------------------------------------+
CTrailingStopManager::~CTrailingStopManager()
{
  // آزاد کردن تمام هندل‌های اندیکاتورها برای جلوگیری از memory leak
  for(int i = 0; i < ArraySize(m_ichimoku_handles); i++) IndicatorRelease(m_ichimoku_handles[i].handle); // آزاد کردن هندل ایچیموکو
  for(int i = 0; i < ArraySize(m_ma_handles); i++) IndicatorRelease(m_ma_handles[i].handle); // آزاد کردن هندل MA
  for(int i = 0; i < ArraySize(m_atr_handles); i++) IndicatorRelease(m_atr_handles[i].handle); // آزاد کردن هندل ATR
  for(int i = 0; i < ArraySize(m_psar_handles); i++) IndicatorRelease(m_psar_handles[i].handle); // آزاد کردن هندل PSAR
}

//+------------------------------------------------------------------+
//| تابع اولیه‌سازی کلاس (کپی تنظیمات و آماده‌سازی)                   |
//+------------------------------------------------------------------+
void CTrailingStopManager::Init(long magic_number)
{
  if(m_is_initialized) return; // اگر قبلاً اولیه‌سازی شده، خروج (جلوگیری از تکرار)
  m_magic_number = magic_number; // تنظیم مجیک نامبر برای فیلتر پوزیشن‌ها
  m_trade.SetExpertMagicNumber(m_magic_number); // تنظیم مجیک در شیء ترید
  m_trade.SetAsyncMode(true); // فعال کردن مود asynchronous برای سرعت بیشتر
  // کپی تمام تنظیمات ورودی برای دسترسی سریع
  m_tsl_enabled = Inp_TSL_Enable;
  m_activation_rr = Inp_TSL_Activation_RR > 0 ? Inp_TSL_Activation_RR : 1.0; // حداقل 1.0 اگر صفر باشد
  m_be_enabled = Inp_BE_Enable;
  m_be_activation_rr = Inp_BE_Activation_RR > 0 ? Inp_BE_Activation_RR : 1.0; // حداقل 1.0
  m_be_plus_pips = Inp_BE_Plus_Pips;
  m_tsl_mode = Inp_TSL_Mode;
  m_buffer_pips = Inp_TSL_Buffer_Pips;
  m_ichimoku_tenkan = Inp_TSL_Ichimoku_Tenkan;
  m_ichimoku_kijun = Inp_TSL_Ichimoku_Kijun;
  m_ichimoku_senkou = Inp_TSL_Ichimoku_Senkou;
  m_ma_period = Inp_TSL_MA_Period;
  m_ma_method = Inp_TSL_MA_Method;
  m_ma_price = Inp_TSL_MA_Price;
  m_atr_period = Inp_TSL_ATR_Period;
  m_atr_multiplier = Inp_TSL_ATR_Multiplier;
  m_psar_step = Inp_TSL_PSAR_Step;
  m_psar_max = Inp_TSL_PSAR_Max;
  m_pricechannel_period = Inp_TSL_PriceChannel_Period;
  // لاگ موفقیت اگر حداقل یکی فعال باشد
  if(m_tsl_enabled || m_be_enabled) Log("کتابخانه Universal Trailing/BE با موفقیت برای مجیک نامبر " + (string)m_magic_number + " فعال شد.");
  m_is_initialized = true; // تنظیم فلگ اولیه‌سازی
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش (روی تمام پوزیشن‌ها - منطق کاملاً مستقل)        |
//+------------------------------------------------------------------+
void CTrailingStopManager::Process()
{
  if(!m_is_initialized || (!m_tsl_enabled && !m_be_enabled)) return; // اگر اولیه‌سازی نشده یا همه غیرفعال، خروج سریع

  // گام ۱: پوزیشن‌های جدید را به لیست وضعیت اضافه کن (فقط اگر مجیک درست باشد)
  int positions_total = PositionsTotal(); // تعداد کل پوزیشن‌ها
  for(int i = 0; i < positions_total; i++) // حلقه روی تمام پوزیشن‌ها
  {
      ulong ticket = PositionGetTicket(i); // گرفتن تیکت پوزیشن
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue; // اگر مجیک اشتباه، رد کن

      int state_idx = FindTradeStateIndex(ticket); // چک آیا در لیست وضعیت هست

      if(state_idx == -1) // اگر جدید است
      {
          if(PositionSelectByTicket(ticket)) // انتخاب پوزیشن برای گرفتن اطلاعات
          {
              AddTradeState(ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL)); // اضافه به لیست
          }
      }
  }

  // گام ۲: پاکسازی لیست از پوزیشن‌های بسته شده (برای جلوگیری از انباشت)
  CleanupTradeStates(); // فراخوانی تابع پاکسازی

  // گام ۳: منطق تریلینگ و سربه‌سر را برای هر پوزیشن در لیست اجرا کن
  for(int i = 0; i < ArraySize(m_trade_states); i++) // حلقه روی وضعیت‌ها
  {
    ManageSingleTrade(m_trade_states[i].ticket); // مدیریت هر پوزیشن جداگانه
  }
}

//+------------------------------------------------------------------+
//| تابع پاکسازی وضعیت پوزیشن‌های بسته شده از آرایه                 |
//+------------------------------------------------------------------+
void CTrailingStopManager::CleanupTradeStates()
{
    for(int i = ArraySize(m_trade_states) - 1; i >= 0; i--) // حلقه معکوس برای جلوگیری از مشکل حذف
    {
        ulong ticket = m_trade_states[i].ticket; // تیکت وضعیت فعلی
        // اگر پوزیشن پیدا نشد یا مجیک اشتباه، یعنی بسته شده – حذف از آرایه
        if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != m_magic_number)
        {
            ArrayRemove(m_trade_states, i, 1); // حذف ایتم از آرایه
            Log("حالت تیکت " + (string)ticket + " از لیست تریلینگ حذف شد."); // لاگ حذف
        }
    }
}

//+------------------------------------------------------------------+
//| تابع مدیریت تریلینگ و سربه‌سر برای یک پوزیشن خاص                |
//+------------------------------------------------------------------+
void CTrailingStopManager::ManageSingleTrade(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return; // اگر پوزیشن انتخاب نشد، خروج

    int state_idx = FindTradeStateIndex(ticket); // پیدا کردن ایندکس وضعیت
    if (state_idx == -1) return; // اگر پیدا نشد، خروج

    double initial_sl = m_trade_states[state_idx].initial_sl; // گرفتن SL اولیه از وضعیت
    
    if (initial_sl == 0) // اگر SL اولیه هنوز صفر است (ممکن است تازه تنظیم شده باشد)
    {
        double current_sl_from_position = PositionGetDouble(POSITION_SL); // گرفتن SL فعلی از پوزیشن
        if (current_sl_from_position > 0) // اگر معتبر بود
        {
            m_trade_states[state_idx].initial_sl = current_sl_from_position; // به‌روزرسانی وضعیت
            initial_sl = current_sl_from_position; // استفاده در ادامه
            Log("SL اولیه برای تیکت " + (string)ticket + " با موفقیت به‌روزرسانی شد: " + (string)initial_sl); // لاگ
        }
        else // اگر هنوز SL صفر، خروج (بعدا چک می‌شود)
        {
            return;
        }
    }
    
    if(m_be_enabled) ManageBreakeven(state_idx); // اگر سربه‌سر فعال، مدیریت آن

    if(!m_tsl_enabled) return; // اگر تریلینگ غیرفعال، خروج

    string symbol = PositionGetString(POSITION_SYMBOL); // نماد پوزیشن
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // نوع (خرید/فروش)
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN); // قیمت ورود
    double initial_risk = MathAbs(open_price - initial_sl); // ریسک اولیه (فاصله تا SL)
    if(initial_risk == 0) return; // اگر ریسک صفر، خروج (نامعتبر)

    double required_profit_for_tsl = initial_risk * m_activation_rr; // سود لازم برای فعال‌سازی تریلینگ
    double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
    double current_profit = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price); // سود فعلی
    
    if(current_profit < required_profit_for_tsl) return; // اگر سود کمتر از لازم، خروج
    
    double new_sl_level = 0; // سطح جدید SL
    switch(m_tsl_mode) // انتخاب مود و محاسبه SL
    {
    case TSL_MODE_TENKAN:
    case TSL_MODE_KIJUN:
        new_sl_level = CalculateIchimokuSL(symbol, type); // محاسبه با ایچیموکو
        break;
    case TSL_MODE_MA:
        new_sl_level = CalculateMaSL(symbol, type); // محاسبه با MA
        break;
    case TSL_MODE_ATR:
        new_sl_level = CalculateAtrSL(symbol, type); // محاسبه با ATR
        break;
    case TSL_MODE_PSAR:
        new_sl_level = CalculatePsarSL(symbol, type); // محاسبه با PSAR
        break;
    case TSL_MODE_PRICE_CHANNEL:
        new_sl_level = CalculatePriceChannelSL(symbol, type); // محاسبه با پرایس چنل
        break;
    case TSL_MODE_CHANDELIER_ATR:
        new_sl_level = CalculateChandelierAtrSL(symbol, type); // محاسبه با Chandelier ATR
        break;
    }
    if(new_sl_level == 0) return; // اگر محاسبه شکست، خروج
    
    double final_new_sl = new_sl_level; // سطح نهایی SL
    if(m_tsl_mode == TSL_MODE_TENKAN || m_tsl_mode == TSL_MODE_KIJUN || m_tsl_mode == TSL_MODE_MA) // برای مودهای خطی، بافر اضافه کن
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT); // پوینت نماد
        double pips_to_points_multiplier = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) ? 10.0 : 1.0; // تنظیم برای digits
        double buffer_points = m_buffer_pips * point * pips_to_points_multiplier; // محاسبه بافر در پوینت
        if(type == POSITION_TYPE_BUY) final_new_sl -= buffer_points; // برای خرید، پایین‌تر
        else final_new_sl += buffer_points; // برای فروش، بالاتر
    }
    
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS); // digits نماد برای نرمال‌سازی
    final_new_sl = NormalizeDouble(final_new_sl, digits); // نرمال‌سازی سطح جدید
    double current_sl = PositionGetDouble(POSITION_SL); // SL فعلی

    bool should_modify = false; // فلگ آیا نیاز به تغییر SL هست
    if(type == POSITION_TYPE_BUY) // برای خرید
    {
        if(final_new_sl > current_sl && final_new_sl < current_price) should_modify = true; // اگر جدید بهتر و معتبر
    }
    else // برای فروش
    {
        if(final_new_sl < current_sl && final_new_sl > current_price) should_modify = true; // اگر جدید بهتر و معتبر
    }

    if(should_modify) // اگر نیاز به تغییر
    {
        if(m_trade.PositionModify(ticket, final_new_sl, PositionGetDouble(POSITION_TP))) // تغییر SL (TP بدون تغییر)
        {
            Log("تریلینگ استاپ برای تیکت " + (string)ticket + " به قیمت " + DoubleToString(final_new_sl, digits) + " آپدیت شد."); // لاگ موفقیت
        }
        else // اگر شکست
        {
            Log("خطا در آپدیت تریلینگ استاپ برای تیکت " + (string)ticket + ". کد: " + (string)m_trade.ResultRetcode() + " | " + m_trade.ResultComment()); // لاگ خطا
        }
    }
}

//+------------------------------------------------------------------+
//| تابع مدیریت سربه‌سر برای یک پوزیشن                               |
//+------------------------------------------------------------------+
void CTrailingStopManager::ManageBreakeven(int state_idx)
{
    if(m_trade_states[state_idx].be_applied) return; // اگر قبلاً اعمال شده، خروج
    ulong ticket = m_trade_states[state_idx].ticket; // تیکت
    if(!PositionSelectByTicket(ticket)) return; // اگر انتخاب نشد، خروج
    string symbol = PositionGetString(POSITION_SYMBOL); // نماد
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE); // نوع

    double initial_sl = m_trade_states[state_idx].initial_sl; // SL اولیه
    if(initial_sl == 0) return; // اگر صفر، خروج
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN); // قیمت ورود
    double initial_risk = MathAbs(open_price - initial_sl); // ریسک اولیه
    if(initial_risk == 0) return; // اگر صفر، خروج
    double required_profit_for_be = initial_risk * m_be_activation_rr; // سود لازم برای سربه‌سر
    double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
    double current_profit = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price); // سود فعلی

    if(current_profit >= required_profit_for_be) // اگر سود کافی
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT); // پوینت
        double pips_to_points_multiplier = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) ? 10.0 : 1.0; // تنظیم digits
        double be_offset = m_be_plus_pips * point * pips_to_points_multiplier; // آفست سربه‌سر
        double new_sl = (type == POSITION_TYPE_BUY) ? open_price + be_offset : open_price - be_offset; // SL جدید
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS); // digits
        new_sl = NormalizeDouble(new_sl, digits); // نرمال‌سازی

        if( (type == POSITION_TYPE_BUY && new_sl > PositionGetDouble(POSITION_SL)) || // چک آیا بهتر است
            (type == POSITION_TYPE_SELL && new_sl < PositionGetDouble(POSITION_SL)) )
        {
            if(m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP))) // تغییر SL
            {
                Log("معامله تیکت " + (string)ticket + " با موفقیت سربه‌سر (Breakeven) شد."); // لاگ موفقیت
                m_trade_states[state_idx].be_applied = true; // تنظیم فلگ اعمال شده
            }
        }
    }
}

//+------------------------------------------------------------------+
//| تابع پیدا کردن ایندکس وضعیت پوزیشن در آرایه                      |
//+------------------------------------------------------------------+
int CTrailingStopManager::FindTradeStateIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(m_trade_states); i++) // حلقه روی آرایه
    {
        if(m_trade_states[i].ticket == ticket) return i; // اگر پیدا شد، بازگشت ایندکس
    }
    return -1; // اگر پیدا نشد، -1
}

//+------------------------------------------------------------------+
//| تابع اضافه کردن وضعیت جدید پوزیشن به آرایه                       |
//+------------------------------------------------------------------+
void CTrailingStopManager::AddTradeState(ulong ticket, double open_price, double initial_sl)
{
    int idx = FindTradeStateIndex(ticket); // چک تکراری
    if(idx != -1) return; // اگر وجود داشت، خروج
    
    int new_idx = ArraySize(m_trade_states); // ایندکس جدید
    ArrayResize(m_trade_states, new_idx + 1); // تغییر اندازه آرایه
    m_trade_states[new_idx].ticket = ticket; // تنظیم تیکت
    m_trade_states[new_idx].open_price = open_price; // قیمت ورود
    m_trade_states[new_idx].initial_sl = initial_sl; // SL اولیه
    m_trade_states[new_idx].be_applied = false; // ریست فلگ سربه‌سر
    Log("حالت جدید برای تیکت " + (string)ticket + " با SL اولیه " + (string)initial_sl + " اضافه شد."); // لاگ اضافه
}

//+------------------------------------------------------------------+
//| تابع گرفتن یا ایجاد هندل ایچیموکو برای نماد                       |
//+------------------------------------------------------------------+
int CTrailingStopManager::GetIchimokuHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_ichimoku_handles); i++) if(m_ichimoku_handles[i].symbol==symbol) return m_ichimoku_handles[i].handle; // چک وجود
  int handle = iIchimoku(symbol, _Period, m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou); // ایجاد جدید
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_ichimoku_handles); ArrayResize(m_ichimoku_handles,n+1); m_ichimoku_handles[n].symbol=symbol; m_ichimoku_handles[n].handle=handle;} // اضافه به آرایه
  return handle; // بازگشت هندل
}

//+------------------------------------------------------------------+
//| تابع گرفتن یا ایجاد هندل MA برای نماد                              |
//+------------------------------------------------------------------+
int CTrailingStopManager::GetMaHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_ma_handles); i++) if(m_ma_handles[i].symbol==symbol) return m_ma_handles[i].handle; // چک وجود
  int handle = iMA(symbol, _Period, m_ma_period, 0, m_ma_method, m_ma_price); // ایجاد جدید
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_ma_handles); ArrayResize(m_ma_handles,n+1); m_ma_handles[n].symbol=symbol; m_ma_handles[n].handle=handle;} // اضافه
  return handle;
}

//+------------------------------------------------------------------+
//| تابع گرفتن یا ایجاد هندل ATR برای نماد                             |
//+------------------------------------------------------------------+
int CTrailingStopManager::GetAtrHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_atr_handles); i++) if(m_atr_handles[i].symbol==symbol) return m_atr_handles[i].handle; // چک وجود
  int handle = iATR(symbol, _Period, m_atr_period); // ایجاد جدید
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_atr_handles); ArrayResize(m_atr_handles,n+1); m_atr_handles[n].symbol=symbol; m_atr_handles[n].handle=handle;} // اضافه
  return handle;
}

//+------------------------------------------------------------------+
//| تابع گرفتن یا ایجاد هندل PSAR برای نماد                            |
//+------------------------------------------------------------------+
int CTrailingStopManager::GetPsarHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_psar_handles); i++) if(m_psar_handles[i].symbol==symbol) return m_psar_handles[i].handle; // چک وجود
  int handle = iSAR(symbol, _Period, m_psar_step, m_psar_max); // ایجاد جدید
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_psar_handles); ArrayResize(m_psar_handles,n+1); m_psar_handles[n].symbol=symbol; m_psar_handles[n].handle=handle;} // اضافه
  return handle;
}

//+------------------------------------------------------------------+
//| تابع لاگ کردن پیام‌ها (با پیشوند مجیک نامبر)                      |
//+------------------------------------------------------------------+
void CTrailingStopManager::Log(string message)
{
  if (m_magic_number > 0) Print("TSL Manager [", (string)m_magic_number, "]: ", message); // چاپ با پیشوند
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس ایچیموکو (تنکان یا کیجون)                        |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculateIchimokuSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetIchimokuHandle(symbol); // گرفتن هندل
  if(handle == INVALID_HANDLE) return 0.0; // اگر شکست، صفر
  int buffer_idx = (m_tsl_mode == TSL_MODE_TENKAN) ? 0 : 1; // انتخاب بافر (0=تنکان، 1=کیجون)
  double values[1]; // بافر داده
  if(CopyBuffer(handle, buffer_idx, 1, 1, values) < 1) return 0.0; // کپی داده شیفت 1
  double line_value = values[0]; // مقدار خط
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
  if (type == POSITION_TYPE_BUY && line_value > current_price) return 0.0; // برای خرید، اگر خط بالای قیمت، نامعتبر
  if (type == POSITION_TYPE_SELL && line_value < current_price) return 0.0; // برای فروش، اگر خط پایین قیمت، نامعتبر
  return line_value; // بازگشت مقدار معتبر
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس میانگین متحرک (MA)                               |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculateMaSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetMaHandle(symbol); // گرفتن هندل
  if(handle == INVALID_HANDLE) return 0.0; // شکست
  double values[1]; // بافر
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0; // کپی شیفت 1
  double ma_value = values[0]; // مقدار MA
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
  if (type == POSITION_TYPE_BUY && ma_value > current_price) return 0.0; // نامعتبر برای خرید
  if (type == POSITION_TYPE_SELL && ma_value < current_price) return 0.0; // نامعتبر برای فروش
  return ma_value; // بازگشت معتبر
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس ATR (آفست از قیمت فعلی)                          |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetAtrHandle(symbol); // گرفتن هندل
  if(handle == INVALID_HANDLE) return 0.0; // شکست
  double values[1]; // بافر
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0; // کپی شیفت 1
  double atr_offset = values[0] * m_atr_multiplier; // آفست = ATR * ضریب
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
  if(type == POSITION_TYPE_BUY) return current_price - atr_offset; // برای خرید، پایین قیمت
  else return current_price + atr_offset; // برای فروش، بالای قیمت
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس PSAR                                              |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculatePsarSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetPsarHandle(symbol); // گرفتن هندل
  if(handle == INVALID_HANDLE) return 0.0; // شکست
  double values[1]; // بافر
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0; // کپی شیفت 1
  double psar_value = values[0]; // مقدار PSAR
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
  if (type == POSITION_TYPE_BUY && psar_value > current_price) return 0.0; // نامعتبر اگر PSAR بالای قیمت برای خرید
  if (type == POSITION_TYPE_SELL && psar_value < current_price) return 0.0; // نامعتبر اگر PSAR پایین قیمت برای فروش
  return psar_value; // بازگشت معتبر
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس پرایس چنل (بالاترین/پایین‌ترین در دوره)          |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type)
{
  double values[]; // آرایه برای High/Low
  if(type == POSITION_TYPE_BUY) // برای خرید
  {
      if(CopyLow(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0; // کپی Lowها
      return values[ArrayMinimum(values, 0, m_pricechannel_period)]; // پایین‌ترین Low
  }
  else // برای فروش
  {
      if(CopyHigh(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0; // کپی Highها
      return values[ArrayMaximum(values, 0, m_pricechannel_period)]; // بالاترین High
  }
}

//+------------------------------------------------------------------+
//| محاسبه SL بر اساس Chandelier ATR (بالاترین/پایین‌ترین + آفست ATR)  |
//+------------------------------------------------------------------+
double CTrailingStopManager::CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
  int atr_handle = GetAtrHandle(symbol); // گرفتن هندل ATR
  if(atr_handle == INVALID_HANDLE) return 0.0; // شکست
  double atr_values[1]; // بافر ATR
  if(CopyBuffer(atr_handle, 0, 1, 1, atr_values) < 1) return 0.0; // کپی شیفت 1
  double atr_offset = atr_values[0] * m_atr_multiplier; // آفست = ATR * ضریب
  double price_channel_values[]; // آرایه برای High/Low
  if(type == POSITION_TYPE_BUY) // برای خرید
  {
      if(CopyHigh(symbol, _Period, 1, m_pricechannel_period, price_channel_values) < m_pricechannel_period) return 0.0; // کپی Highها
      double highest_high = price_channel_values[ArrayMaximum(price_channel_values, 0, m_pricechannel_period)]; // بالاترین High
      double new_sl = highest_high - atr_offset; // SL = بالاترین - آفست
      double current_price = SymbolInfoDouble(symbol, SYMBOL_BID); // قیمت فعلی
      if (new_sl >= current_price) return 0.0; // چک اضافی: اگر SL از قیمت عبور کند، نامعتبر
      return new_sl; // بازگشت معتبر
  }
  else // برای فروش
  {
      if(CopyLow(symbol, _Period, 1, m_pricechannel_period, price_channel_values) < m_pricechannel_period) return 0.0; // کپی Lowها
      double lowest_low = price_channel_values[ArrayMinimum(price_channel_values, 0, m_pricechannel_period)]; // پایین‌ترین Low
      double new_sl = lowest_low + atr_offset; // SL = پایین‌ترین + آفست
      double current_price = SymbolInfoDouble(symbol, SYMBOL_ASK); // قیمت فعلی
      if (new_sl <= current_price) return 0.0; // چک اضافی: اگر SL از قیمت عبور کند، نامعتبر
      return new_sl; // بازگشت معتبر
  }
}
