//+------------------------------------------------------------------+
//|                                      Universal Trailing Stop Loss Library |
//|                                      File: TrailingStopManager.mqh |
//|                                      Version: 5.0 (Final & Independent) |
//|                                      © 2025, Mohammad & Gemini |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "5.0"
#include <Trade\Trade.mqh>

//================================================================================//
//|                                 --- راهنمای استفاده سریع ---                   |
//|                                                                                |
//| ۱. این فایل را در کنار فایل اکسپرت خود قرار دهید.                                |
//| ۲. در فایل اکسپرت اصلی (.mq5)، این دو خط را به بالای فایل اضافه کنید:             |
//|    #include "TrailingStopManager.mqh"                                          |
//|    CTrailingStopManager TrailingStop;                                          |
//| ۳. در انتهای تابع OnInit اکسپرت خود، این خط را اضافه کنید:                      |
//|    TrailingStop.Init(magic_number);                                           |
//| ۴. در انتهای تابع OnTimer (یا OnTick) اکسپرت خود، این خط را اضافه کنید:          |
//|    TrailingStop.Process();                                                     |
//|                                                                                |
//|                                 **دیگر به هیچ فراخوانی دیگری نیاز نیست!** |
//|                                                                                |
//================================================================================//

//================================================================//
// بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play
//================================================================//
input group "---=== 🛡️ Universal Trailing & Breakeven 🛡️ ===---";
input bool Inp_TSL_Enable = true;
input double Inp_TSL_Activation_RR = 1.0;
input bool Inp_BE_Enable = true;
input double Inp_BE_Activation_RR = 1.0;
input double Inp_BE_Plus_Pips = 1.0;
enum E_TSL_Mode { TSL_MODE_TENKAN, TSL_MODE_KIJUN, TSL_MODE_MA, TSL_MODE_ATR, TSL_MODE_PSAR, TSL_MODE_PRICE_CHANNEL, TSL_MODE_CHANDELIER_ATR };
input E_TSL_Mode Inp_TSL_Mode = TSL_MODE_TENKAN;
/*input*/ double Inp_TSL_Buffer_Pips = 3.0;
/*input*/ int Inp_TSL_Ichimoku_Tenkan = 9;
/*input*/ int Inp_TSL_Ichimoku_Kijun = 26;
/*input*/ int Inp_TSL_Ichimoku_Senkou = 52;
/*input*/ int Inp_TSL_MA_Period = 50;
/*input*/ ENUM_MA_METHOD Inp_TSL_MA_Method = MODE_SMA;
/*input*/ ENUM_APPLIED_PRICE Inp_TSL_MA_Price = PRICE_CLOSE;
/*input*/ int Inp_TSL_ATR_Period = 14;
/*input*/ double Inp_TSL_ATR_Multiplier = 2.5;
/*input*/ double Inp_TSL_PSAR_Step = 0.02;
/*input*/ double Inp_TSL_PSAR_Max = 0.2;
/*input*/ int Inp_TSL_PriceChannel_Period = 22;

//+------------------------------------------------------------------+
//| ساختارهای داخلی برای مدیریت بهینه هندل‌ها و وضعیت تریدها          |
//+------------------------------------------------------------------+
struct SIndicatorHandle
{
  string symbol;
  int    handle;
};

// ✅✅✅ ساختار حالت معامله بازنویسی شد ✅✅✅
struct STradeState
{
  ulong  ticket;
  double open_price;
  double initial_sl;
  bool   be_applied;
  datetime last_update_time;
};

//+------------------------------------------------------------------+
//| کلاس اصلی مدیریت حد ضرر متحرک                                     |
//+------------------------------------------------------------------+
class CTrailingStopManager
{
private:
  long               m_magic_number;
  bool               m_is_initialized;
  CTrade             m_trade;

  // --- تنظیمات ---
  bool               m_tsl_enabled, m_be_enabled;
  double             m_activation_rr, m_be_activation_rr, m_be_plus_pips;
  E_TSL_Mode         m_tsl_mode;
  double             m_buffer_pips;
  int                m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou;
  int                m_ma_period;
  ENUM_MA_METHOD     m_ma_method;
  ENUM_APPLIED_PRICE m_ma_price;
  int                m_atr_period;
  double             m_atr_multiplier;
  double             m_psar_step, m_psar_max;
  int                m_pricechannel_period;

  // --- مدیریت حالت ---
  STradeState        m_trade_states[];

  // --- مدیریت هندل‌ها ---
  SIndicatorHandle   m_ichimoku_handles[];
  SIndicatorHandle   m_ma_handles[];
  SIndicatorHandle   m_atr_handles[];
  SIndicatorHandle   m_psar_handles[];

  // --- توابع کمکی خصوصی ---
  int    GetIchimokuHandle(string symbol);
  int    GetMaHandle(string symbol);
  int    GetAtrHandle(string symbol);
  int    GetPsarHandle(string symbol);
  void   Log(string message);
  void   ManageSingleTrade(ulong ticket);
  int    FindTradeStateIndex(ulong ticket);
  void   AddTradeState(ulong ticket, double open_price, double initial_sl);

  double CalculateIchimokuSL(string symbol, ENUM_POSITION_TYPE type);
  double CalculateMaSL(string symbol, ENUM_POSITION_TYPE type);
  double CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type);
  double CalculatePsarSL(string symbol, ENUM_POSITION_TYPE type);
  double CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type);
  double CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type);
  void   ManageBreakeven(int state_idx);

public:
  CTrailingStopManager() { m_magic_number = 0; m_is_initialized = false; }
  ~CTrailingStopManager();
  void Init(long magic_number);
  void Process();
};

// --- مخرب کلاس ---
CTrailingStopManager::~CTrailingStopManager()
{
  for(int i = 0; i < ArraySize(m_ichimoku_handles); i++) IndicatorRelease(m_ichimoku_handles[i].handle);
  for(int i = 0; i < ArraySize(m_ma_handles); i++) IndicatorRelease(m_ma_handles[i].handle);
  for(int i = 0; i < ArraySize(m_atr_handles); i++) IndicatorRelease(m_atr_handles[i].handle);
  for(int i = 0; i < ArraySize(m_psar_handles); i++) IndicatorRelease(m_psar_handles[i].handle);
}

// --- تابع مقداردهی اولیه ---
void CTrailingStopManager::Init(long magic_number)
{
  if(m_is_initialized) return;
  m_magic_number = magic_number;
  m_trade.SetExpertMagicNumber(m_magic_number);
  m_trade.SetAsyncMode(true);
  m_tsl_enabled = Inp_TSL_Enable;
  m_activation_rr = Inp_TSL_Activation_RR > 0 ? Inp_TSL_Activation_RR : 1.0;
  m_be_enabled = Inp_BE_Enable;
  m_be_activation_rr = Inp_BE_Activation_RR > 0 ? Inp_BE_Activation_RR : 1.0;
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
  if(m_tsl_enabled || m_be_enabled) Log("کتابخانه Universal Trailing/BE با موفقیت برای مجیک نامبر " + (string)m_magic_number + " فعال شد.");
  m_is_initialized = true;
}

// ✅✅✅ تابع اصلی پردازش (منطق کاملاً مستقل) ✅✅✅
void CTrailingStopManager::Process()
{
  if(!m_is_initialized || (!m_tsl_enabled && !m_be_enabled)) return;

  // گام ۱: تمام پوزیشن‌های باز را بررسی و وضعیت آن‌ها را در آرایه داخلی به‌روزرسانی می‌کنیم.
  int positions_total = PositionsTotal();
  for(int i = 0; i < positions_total; i++)
  {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;

      int state_idx = FindTradeStateIndex(ticket);

      // اگر پوزیشن جدید بود، آن را به لیست اضافه کن.
      if(state_idx == -1)
      {
          if(PositionSelectByTicket(ticket))
          {
              AddTradeState(ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL));
          }
      }
      else
      {
          // اگر پوزیشن در لیست بود، زمان آخرین به‌روزرسانی را به‌روز کن.
          m_trade_states[state_idx].last_update_time = TimeCurrent();
      }
  }

  // گام ۲: پوزیشن‌های قدیمی که دیگر باز نیستند را از لیست پاکسازی کن.
  for(int i = ArraySize(m_trade_states) - 1; i >= 0; i--)
  {
      ulong ticket = m_trade_states[i].ticket;
      if(!PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC) != m_magic_number)
      {
          // اگر تیکت پیدا نشد یا مجیک نامبر متفاوت بود، یعنی معامله بسته شده.
          ArrayRemove(m_trade_states, i, 1);
          Log("حالت تیکت " + (string)ticket + " از لیست تریلینگ حذف شد.");
      }
      else
      {
          // گام ۳: منطق تریلینگ و سربه‌سر را برای هر پوزیشن در لیست اجرا کن.
          ManageSingleTrade(ticket);
      }
  }
}

// ✅✅✅ تابع مدیریت یک معامله ✅✅✅
void CTrailingStopManager::ManageSingleTrade(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;

    int state_idx = FindTradeStateIndex(ticket);
    if (state_idx == -1) return;

    // --- دریافت SL اولیه از حافظه ---
    double initial_sl = m_trade_states[state_idx].initial_sl;
    
    // ✅ چک کردن اینکه SL اولیه معتبر است یا نه
    if (initial_sl == 0)
    {
        // اگر هنوز 0 بود، سعی کن از پوزیشن اصلی بخونیش
        double current_sl_from_position = PositionGetDouble(POSITION_SL);
        // اگر معتبر بود، ذخیره‌اش کن
        if (current_sl_from_position > 0)
        {
            m_trade_states[state_idx].initial_sl = current_sl_from_position;
            initial_sl = current_sl_from_position;
            Log("SL اولیه برای تیکت " + (string)ticket + " با موفقیت به‌روزرسانی شد: " + (string)initial_sl);
        }
        else
        {
            // اگر هنوز 0 بود، بیخیال شو تا کندل بعدی.
            return;
        }
    }
    
    // --- بخش ۱: مدیریت Breakeven (همیشه اول اجرا می‌شود) ---
    if(m_be_enabled) ManageBreakeven(state_idx);

    // --- بخش ۲: مدیریت Trailing Stop ---
    if(!m_tsl_enabled) return;

    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double initial_risk = MathAbs(open_price - initial_sl);
    if(initial_risk == 0) return;

    double required_profit_for_tsl = initial_risk * m_activation_rr;
    double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double current_profit = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);
    
    if(current_profit < required_profit_for_tsl) return;
    
    // ... ادامه منطق تریلینگ مانند نسخه قبلی ...
    double new_sl_level = 0;
    switch(m_tsl_mode)
    {
      // ... تمام حالت‌ها ...
    case TSL_MODE_TENKAN:
    case TSL_MODE_KIJUN:
        new_sl_level = CalculateIchimokuSL(symbol, type);
        break;
    case TSL_MODE_MA:
        new_sl_level = CalculateMaSL(symbol, type);
        break;
    case TSL_MODE_ATR:
        new_sl_level = CalculateAtrSL(symbol, type);
        break;
    case TSL_MODE_PSAR:
        new_sl_level = CalculatePsarSL(symbol, type);
        break;
    case TSL_MODE_PRICE_CHANNEL:
        new_sl_level = CalculatePriceChannelSL(symbol, type);
        break;
    case TSL_MODE_CHANDELIER_ATR:
        new_sl_level = CalculateChandelierAtrSL(symbol, type);
        break;
    }
    if(new_sl_level == 0) return;
    
    double final_new_sl = new_sl_level;
    if(m_tsl_mode == TSL_MODE_TENKAN || m_tsl_mode == TSL_MODE_KIJUN || m_tsl_mode == TSL_MODE_MA)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pips_to_points_multiplier = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) ? 10.0 : 1.0;
        double buffer_points = m_buffer_pips * point * pips_to_points_multiplier;
        if(type == POSITION_TYPE_BUY) final_new_sl -= buffer_points;
        else final_new_sl += buffer_points;
    }
    
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    final_new_sl = NormalizeDouble(final_new_sl, digits);
    double current_sl = PositionGetDouble(POSITION_SL);

    bool should_modify = false;
    if(type == POSITION_TYPE_BUY)
    {
        if(final_new_sl > current_sl && final_new_sl < current_price) should_modify = true;
    }
    else
    {
        if(final_new_sl < current_sl && final_new_sl > current_price) should_modify = true;
    }

    if(should_modify)
    {
        if(m_trade.PositionModify(ticket, final_new_sl, PositionGetDouble(POSITION_TP)))
        {
            Log("تریلینگ استاپ برای تیکت " + (string)ticket + " به قیمت " + DoubleToString(final_new_sl, digits) + " آپدیت شد.");
        }
        else
        {
            Log("خطا در آپدیت تریلینگ استاپ برای تیکت " + (string)ticket + ". کد: " + (string)m_trade.ResultRetcode() + " | " + m_trade.ResultComment());
        }
    }
}


// ... بقیه توابع کلاس CTrailingStopManager (مانند نسخه قبلی) ...
// ✅ تابع مدیریت Breakeven
void CTrailingStopManager::ManageBreakeven(int state_idx)
{
    if(m_trade_states[state_idx].be_applied) return;
    ulong ticket = m_trade_states[state_idx].ticket;
    if(!PositionSelectByTicket(ticket)) return;
    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    double initial_sl = m_trade_states[state_idx].initial_sl;
    if(initial_sl == 0) return;
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double initial_risk = MathAbs(open_price - initial_sl);
    if(initial_risk == 0) return;
    double required_profit_for_be = initial_risk * m_be_activation_rr;
    double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double current_profit = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);

    if(current_profit >= required_profit_for_be)
    {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pips_to_points_multiplier = (SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5) ? 10.0 : 1.0;
        double be_offset = m_be_plus_pips * point * pips_to_points_multiplier;
        double new_sl = (type == POSITION_TYPE_BUY) ? open_price + be_offset : open_price - be_offset;
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        new_sl = NormalizeDouble(new_sl, digits);

        if( (type == POSITION_TYPE_BUY && new_sl > PositionGetDouble(POSITION_SL)) ||
            (type == POSITION_TYPE_SELL && new_sl < PositionGetDouble(POSITION_SL)) )
        {
            if(m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
            {
                Log("معامله تیکت " + (string)ticket + " با موفقیت سربه‌سر (Breakeven) شد.");
                m_trade_states[state_idx].be_applied = true;
            }
        }
    }
}
// ✅ تابع کمکی برای پیدا کردن ایندکس یک تیکت
int CTrailingStopManager::FindTradeStateIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(m_trade_states); i++)
    {
        if(m_trade_states[i].ticket == ticket) return i;
    }
    return -1;
}

// ✅ تابع جدید: اضافه کردن حالت معامله به آرایه
void CTrailingStopManager::AddTradeState(ulong ticket, double open_price, double initial_sl)
{
    int idx = FindTradeStateIndex(ticket);
    if(idx != -1) return; // اگر از قبل وجود داره، کاری نکن
    
    int new_idx = ArraySize(m_trade_states);
    ArrayResize(m_trade_states, new_idx + 1);
    m_trade_states[new_idx].ticket = ticket;
    m_trade_states[new_idx].open_price = open_price;
    m_trade_states[new_idx].initial_sl = initial_sl;
    m_trade_states[new_idx].be_applied = false;
    m_trade_states[new_idx].last_update_time = TimeCurrent();

    Log("حالت جدید برای تیکت " + (string)ticket + " با SL اولیه " + (string)initial_sl + " اضافه شد.");
}
// --- بقیه توابع کمکی ---
int CTrailingStopManager::GetIchimokuHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_ichimoku_handles); i++) if(m_ichimoku_handles[i].symbol==symbol) return m_ichimoku_handles[i].handle;
  int handle = iIchimoku(symbol, _Period, m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou);
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_ichimoku_handles); ArrayResize(m_ichimoku_handles,n+1); m_ichimoku_handles[n].symbol=symbol; m_ichimoku_handles[n].handle=handle;}
  return handle;
}
int CTrailingStopManager::GetMaHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_ma_handles); i++) if(m_ma_handles[i].symbol==symbol) return m_ma_handles[i].handle;
  int handle = iMA(symbol, _Period, m_ma_period, 0, m_ma_method, m_ma_price);
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_ma_handles); ArrayResize(m_ma_handles,n+1); m_ma_handles[n].symbol=symbol; m_ma_handles[n].handle=handle;}
  return handle;
}
int CTrailingStopManager::GetAtrHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_atr_handles); i++) if(m_atr_handles[i].symbol==symbol) return m_atr_handles[i].handle;
  int handle = iATR(symbol, _Period, m_atr_period);
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_atr_handles); ArrayResize(m_atr_handles,n+1); m_atr_handles[n].symbol=symbol; m_atr_handles[n].handle=handle;}
  return handle;
}
int CTrailingStopManager::GetPsarHandle(string symbol)
{
  for(int i=0; i<ArraySize(m_psar_handles); i++) if(m_psar_handles[i].symbol==symbol) return m_psar_handles[i].handle;
  int handle = iSAR(symbol, _Period, m_psar_step, m_psar_max);
  if(handle!=INVALID_HANDLE){int n=ArraySize(m_psar_handles); ArrayResize(m_psar_handles,n+1); m_psar_handles[n].symbol=symbol; m_psar_handles[n].handle=handle;}
  return handle;
}
void CTrailingStopManager::Log(string message)
{
  if (m_magic_number > 0) Print("TSL Manager [", (string)m_magic_number, "]: ", message);
}
double CTrailingStopManager::CalculateIchimokuSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetIchimokuHandle(symbol);
  if(handle == INVALID_HANDLE) return 0.0;
  int buffer_idx = (m_tsl_mode == TSL_MODE_TENKAN) ? 0 : 1;
  double values[1];
  if(CopyBuffer(handle, buffer_idx, 1, 1, values) < 1) return 0.0;
  double line_value = values[0];
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
  if (type == POSITION_TYPE_BUY && line_value > current_price) return 0.0;
  if (type == POSITION_TYPE_SELL && line_value < current_price) return 0.0;
  return line_value;
}
double CTrailingStopManager::CalculateMaSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetMaHandle(symbol);
  if(handle == INVALID_HANDLE) return 0.0;
  double values[1];
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0;
  double ma_value = values[0];
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
  if (type == POSITION_TYPE_BUY && ma_value > current_price) return 0.0;
  if (type == POSITION_TYPE_SELL && ma_value < current_price) return 0.0;
  return ma_value;
}
double CTrailingStopManager::CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetAtrHandle(symbol);
  if(handle == INVALID_HANDLE) return 0.0;
  double values[1];
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0;
  double atr_offset = values[0] * m_atr_multiplier;
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
  if(type == POSITION_TYPE_BUY) return current_price - atr_offset;
  else return current_price + atr_offset;
}
double CTrailingStopManager::CalculatePsarSL(string symbol, ENUM_POSITION_TYPE type)
{
  int handle = GetPsarHandle(symbol);
  if(handle == INVALID_HANDLE) return 0.0;
  double values[1];
  if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0;
  double psar_value = values[0];
  double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
  if (type == POSITION_TYPE_BUY && psar_value > current_price) return 0.0;
  if (type == POSITION_TYPE_SELL && psar_value < current_price) return 0.0;
  return psar_value;
}
double CTrailingStopManager::CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type)
{
  double values[];
  if(type == POSITION_TYPE_BUY)
  {
      if(CopyLow(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0;
      return values[ArrayMinimum(values, 0, m_pricechannel_period)];
  }
  else
  {
      if(CopyHigh(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0;
      return values[ArrayMaximum(values, 0, m_pricechannel_period)];
  }
}
double CTrailingStopManager::CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
  int atr_handle = GetAtrHandle(symbol);
  if(atr_handle == INVALID_HANDLE) return 0.0;
  double atr_values[1];
  if(CopyBuffer(atr_handle, 0, 1, 1, atr_values) < 1) return 0.0;
  double atr_offset = atr_values[0] * m_atr_multiplier;
  double price_channel_values[];
  if(type == POSITION_TYPE_BUY)
  {
      if(CopyHigh(symbol, _Period, 1, m_pricechannel_period, price_channel_values) < m_pricechannel_period) return 0.0;
      double highest_high = price_channel_values[ArrayMaximum(price_channel_values, 0, m_pricechannel_period)];
      return highest_high - atr_offset;
  }
  else
  {
      if(CopyLow(symbol, _Period, 1, m_pricechannel_period, price_channel_values) < m_pricechannel_period) return 0.0;
      double lowest_low = price_channel_values[ArrayMinimum(price_channel_values, 0, m_pricechannel_period)];
      return lowest_low + atr_offset;
  }
}
