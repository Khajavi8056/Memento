//+------------------------------------------------------------------+
//|                                                                  |
//|         Project: Universal Trailing Stop Loss Library            |
//|                  File: TrailingStopManager.mqh                   |
//|                  Version: 4.0 (Final & Feature-Rich)             |
//|                  © 2025, Mohammad & Gemini                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "4.0"

#include <Trade\Trade.mqh>

//================================================================================//
//|                                                                                |
//|                         --- راهنمای استفاده سریع ---                            |
//|                                                                                |
//|  ۱. این فایل را در کنار فایل اکسپرت خود قرار دهید.                               |
//|  ۲. در فایل اکسپرت اصلی (.mq5)، این دو خط را به بالای فایل اضافه کنید:          |
//|     #include "TrailingStopManager.mqh"                                         |
//|     CTrailingStopManager TrailingStop;                                         |
//|  ۳. در انتهای تابع OnInit اکسپرت خود، این خط را اضافه کنید:                      |
//|     TrailingStop.Init(magic_number);                                           |
//|  ۴. در انتهای تابع OnTimer (یا OnTick) اکسپرت خود، این خط را اضافه کنید:          |
//|     TrailingStop.Process();                                                    |
//|                                                                                |
//================================================================================//


//================================================================//
//     بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play      //
//================================================================//
input group "---=== 🛡️ Universal Trailing & Breakeven 🛡️ ===---";

// --- تنظیمات اصلی Trailing Stop ---
input bool   Inp_TSL_Enable        = true;     // ✅ فعال/غیرفعال کردن حد ضرر متحرک
input double Inp_TSL_Activation_RR = 1.0;      // فعال‌سازی تریل در این نسبت ریسک به ریوارد (1.0 = 1:1)

// --- تنظیمات Breakeven ---
input bool   Inp_BE_Enable         = true;     // ✅ فعال/غیرفعال کردن Breakeven (سربه‌سر)
input double Inp_BE_Activation_RR  = 1.0;      // فعال‌سازی سربه‌سر در این نسبت ریسک به ریوارد
input double Inp_BE_Plus_Pips      = 1.0;      // قفل کردن این مقدار سود در هنگام سربه‌سر کردن (پیپ)

// --- انواع شمارشی برای انتخاب روش تریل ---
enum E_TSL_Mode
{
    TSL_MODE_TENKAN,          // بر اساس خط تنکان-سن ایچیموکو
    TSL_MODE_KIJUN,           // بر اساس خط کیجون-سن ایچیموکو
    TSL_MODE_MA,              // بر اساس مووینگ اوریج
    TSL_MODE_ATR,             // بر اساس اندیکاتور ATR (مقدار کندل قبل)
    TSL_MODE_PSAR,            // بر اساس اندیکاتور Parabolic SAR (مقدار کندل قبل)
    TSL_MODE_PRICE_CHANNEL,   // بر اساس سقف/کف کانال قیمت (Donchian)
    TSL_MODE_CHANDELIER_ATR   // بر اساس Chandelier Exit واقعی (ترکیب سقف/کف و ATR)
};
input E_TSL_Mode Inp_TSL_Mode      = TSL_MODE_TENKAN; // روش اجرای حد ضرر متحرک

// --- پارامترهای داخلی (برای تنظیمات پیشرفته، کلمه input را از کامنت خارج کنید) ---
/*input*/ double Inp_TSL_Buffer_Pips      = 3.0;      // فاصله از خط تریل (بر حسب پیپ)
/*input*/ int    Inp_TSL_Ichimoku_Tenkan  = 9;        // [ایچیموکو] دوره تنکان
/*input*/ int    Inp_TSL_Ichimoku_Kijun   = 26;       // [ایچیموکو] دوره کیجون
/*input*/ int    Inp_TSL_Ichimoku_Senkou  = 52;       // [ایچیموکو] دوره سنکو
/*input*/ int    Inp_TSL_MA_Period        = 50;       // [MA] دوره مووینگ اوریج
/*input*/ ENUM_MA_METHOD Inp_TSL_MA_Method  = MODE_SMA;   // [MA] نوع مووینگ اوریج
/*input*/ ENUM_APPLIED_PRICE Inp_TSL_MA_Price = PRICE_CLOSE;// [MA] قیمت اعمال
/*input*/ int    Inp_TSL_ATR_Period       = 14;       // [ATR & Chandelier] دوره ATR
/*input*/ double Inp_TSL_ATR_Multiplier   = 2.5;      // [ATR & Chandelier] ضریب ATR
/*input*/ double Inp_TSL_PSAR_Step        = 0.02;     // [PSAR] گام
/*input*/ double Inp_TSL_PSAR_Max         = 0.2;      // [PSAR] حداکثر
/*input*/ int    Inp_TSL_PriceChannel_Period = 22;    // [Price Channel] دوره سقف/کف

//+------------------------------------------------------------------+
//| ساختارهای داخلی برای مدیریت بهینه هندل‌ها و وضعیت تریدها          |
//+------------------------------------------------------------------+
struct SIndicatorHandle { string symbol; int handle; };
struct STradeState { long ticket; bool be_applied; };

//+------------------------------------------------------------------+
//|           کلاس اصلی مدیریت حد ضرر متحرک                          |
//+------------------------------------------------------------------+
class CTrailingStopManager
{
private:
    long                m_magic_number;
    bool                m_is_initialized;
    CTrade              m_trade;

    // --- تنظیمات ---
    bool                m_tsl_enabled, m_be_enabled;
    double              m_activation_rr, m_be_activation_rr, m_be_plus_pips;
    E_TSL_Mode          m_tsl_mode;
    double              m_buffer_pips;
    int                 m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou;
    int                 m_ma_period;
    ENUM_MA_METHOD      m_ma_method;
    ENUM_APPLIED_PRICE  m_ma_price;
    int                 m_atr_period;
    double              m_atr_multiplier;
    double              m_psar_step, m_psar_max;
    int                 m_pricechannel_period;
    
    // --- مدیریت حالت ---
    STradeState         m_trade_states[];
    
    // --- مدیریت هندل‌ها ---
    SIndicatorHandle    m_ichimoku_handles[];
    SIndicatorHandle    m_ma_handles[];
    SIndicatorHandle    m_atr_handles[];
    SIndicatorHandle    m_psar_handles[];

    // --- توابع کمکی خصوصی ---
    int     GetIchimokuHandle(string symbol);
    int     GetMaHandle(string symbol);
    int     GetAtrHandle(string symbol);
    int     GetPsarHandle(string symbol);
    
    double  CalculateIchimokuSL(string symbol);
    double  CalculateMaSL(string symbol);
    double  CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type);
    double  CalculatePsarSL(string symbol);
    double  CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type);
    double  CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type);
    
    void    ManageBreakeven(long ticket);
    int     GetTradeStateIndex(long ticket);

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

    // خواندن تنظیمات
    m_tsl_enabled         = Inp_TSL_Enable;
    m_activation_rr       = Inp_TSL_Activation_RR > 0 ? Inp_TSL_Activation_RR : 1.0;
    m_be_enabled          = Inp_BE_Enable;
    m_be_activation_rr    = Inp_BE_Activation_RR > 0 ? Inp_BE_Activation_RR : 1.0;
    m_be_plus_pips        = Inp_BE_Plus_Pips;
    m_tsl_mode            = Inp_TSL_Mode;
    m_buffer_pips         = Inp_TSL_Buffer_Pips;
    m_ichimoku_tenkan     = Inp_TSL_Ichimoku_Tenkan;
    m_ichimoku_kijun      = Inp_TSL_Ichimoku_Kijun;
    m_ichimoku_senkou     = Inp_TSL_Ichimoku_Senkou;
    m_ma_period           = Inp_TSL_MA_Period;
    m_ma_method           = Inp_TSL_MA_Method;
    m_ma_price            = Inp_TSL_MA_Price;
    m_atr_period          = Inp_TSL_ATR_Period;
    m_atr_multiplier      = Inp_TSL_ATR_Multiplier;
    m_psar_step           = Inp_TSL_PSAR_Step;
    m_psar_max            = Inp_TSL_PSAR_Max;
    m_pricechannel_period = Inp_TSL_PriceChannel_Period;
    
    if(m_tsl_enabled || m_be_enabled) Print("کتابخانه Universal Trailing/BE با موفقیت برای مجیک نامبر ", m_magic_number, " فعال شد.");
    
    m_is_initialized = true;
}

// --- تابع اصلی پردازش ---
void CTrailingStopManager::Process()
{
    if(!m_is_initialized || (!m_tsl_enabled && !m_be_enabled)) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByIndex(i)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;

        long ticket = PositionGetInteger(POSITION_TICKET);

        // --- بخش ۱: مدیریت Breakeven (همیشه اول اجرا می‌شود) ---
        if(m_be_enabled) ManageBreakeven(ticket);

        // --- بخش ۲: مدیریت Trailing Stop ---
        if(!m_tsl_enabled) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        double initial_sl = 0;
        if(HistorySelectByPosition(ticket) && HistoryDealsTotal() > 0) {
           ulong deal_ticket = HistoryDealGetTicket(0);
           if(deal_ticket > 0) initial_sl = HistoryDealGetDouble(deal_ticket, DEAL_SL);
        }
        if(initial_sl == 0) continue;

        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double initial_risk = MathAbs(open_price - initial_sl);
        double required_profit_pips = initial_risk * m_activation_rr;

        double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
        double current_profit_pips = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);
        
        if(current_profit_pips < required_profit_pips) continue;

        double new_sl_level = 0;
        switch(m_tsl_mode)
        {
            case TSL_MODE_TENKAN:
            case TSL_MODE_KIJUN:          new_sl_level = CalculateIchimokuSL(symbol);           break;
            case TSL_MODE_MA:             new_sl_level = CalculateMaSL(symbol);                 break;
            case TSL_MODE_ATR:            new_sl_level = CalculateAtrSL(symbol, type);          break;
            case TSL_MODE_PSAR:           new_sl_level = CalculatePsarSL(symbol);               break;
            case TSL_MODE_PRICE_CHANNEL:  new_sl_level = CalculatePriceChannelSL(symbol, type); break;
            case TSL_MODE_CHANDELIER_ATR: new_sl_level = CalculateChandelierAtrSL(symbol, type);break;
        }
        if(new_sl_level == 0) continue;

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
        if(type == POSITION_TYPE_BUY) {
            if(final_new_sl > current_sl && final_new_sl < current_price) should_modify = true;
        } else {
            if(final_new_sl < current_sl && final_new_sl > current_price) should_modify = true;
        }
        
        if(should_modify) {
            if(m_trade.PositionModify(ticket, final_new_sl, PositionGetDouble(POSITION_TP))) {
                Print("تریلینگ استاپ برای تیکت ", ticket, " به قیمت ", DoubleToString(final_new_sl, digits), " آپدیت شد.");
            } else {
                Print("خطا در آپدیت تریلینگ استاپ برای تیکت ", ticket, ". کد: ", m_trade.ResultRetcode(), " | ", m_trade.ResultComment());
            }
        }
    }
}

// --- مدیریت Breakeven ---
void CTrailingStopManager::ManageBreakeven(long ticket)
{
    int state_idx = GetTradeStateIndex(ticket);
    if(m_trade_states[state_idx].be_applied) return; // اگر قبلا اعمال شده، خارج شو

    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    double initial_sl = 0;
    if(HistorySelectByPosition(ticket) && HistoryDealsTotal() > 0) {
       ulong deal_ticket = HistoryDealGetTicket(0);
       if(deal_ticket > 0) initial_sl = HistoryDealGetDouble(deal_ticket, DEAL_SL);
    }
    if(initial_sl == 0) return;

    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double initial_risk = MathAbs(open_price - initial_sl);
    double required_profit_pips = initial_risk * m_be_activation_rr;

    double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double current_profit_pips = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);

    if(current_profit_pips >= required_profit_pips)
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
                Print("معامله تیکت ", ticket, " با موفقیت سربه‌سر (Breakeven) شد.");
                m_trade_states[state_idx].be_applied = true; // ثبت کن که اعمال شده
            }
        }
    }
}

// --- مدیریت حالت ترید (برای جلوگیری از تکرار Breakeven) ---
int CTrailingStopManager::GetTradeStateIndex(long ticket)
{
    for(int i = 0; i < ArraySize(m_trade_states); i++) {
        if(m_trade_states[i].ticket == ticket) return i;
    }
    // اگر تیکت پیدا نشد، یک حالت جدید برایش بساز
    int new_idx = ArraySize(m_trade_states);
    ArrayResize(m_trade_states, new_idx + 1);
    m_trade_states[new_idx].ticket = ticket;
    m_trade_states[new_idx].be_applied = false;
    return new_idx;
}

// --- توابع کمکی برای مدیریت هندل‌ها (موتور مولتی-کارنسی) ---
int CTrailingStopManager::GetIchimokuHandle(string symbol) {
    for(int i=0; i<ArraySize(m_ichimoku_handles); i++) if(m_ichimoku_handles[i].symbol==symbol) return m_ichimoku_handles[i].handle;
    int handle = iIchimoku(symbol, _Period, m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou);
    if(handle!=INVALID_HANDLE){int n=ArraySize(m_ichimoku_handles); ArrayResize(m_ichimoku_handles,n+1); m_ichimoku_handles[n].symbol=symbol; m_ichimoku_handles[n].handle=handle;}
    return handle;
}
int CTrailingStopManager::GetMaHandle(string symbol) {
    for(int i=0; i<ArraySize(m_ma_handles); i++) if(m_ma_handles[i].symbol==symbol) return m_ma_handles[i].handle;
    int handle = iMA(symbol, _Period, m_ma_period, 0, m_ma_method, m_ma_price);
    if(handle!=INVALID_HANDLE){int n=ArraySize(m_ma_handles); ArrayResize(m_ma_handles,n+1); m_ma_handles[n].symbol=symbol; m_ma_handles[n].handle=handle;}
    return handle;
}
int CTrailingStopManager::GetAtrHandle(string symbol) {
    for(int i=0; i<ArraySize(m_atr_handles); i++) if(m_atr_handles[i].symbol==symbol) return m_atr_handles[i].handle;
    int handle = iATR(symbol, _Period, m_atr_period);
    if(handle!=INVALID_HANDLE){int n=ArraySize(m_atr_handles); ArrayResize(m_atr_handles,n+1); m_atr_handles[n].symbol=symbol; m_atr_handles[n].handle=handle;}
    return handle;
}
int CTrailingStopManager::GetPsarHandle(string symbol) {
    for(int i=0; i<ArraySize(m_psar_handles); i++) if(m_psar_handles[i].symbol==symbol) return m_psar_handles[i].handle;
    int handle = iSAR(symbol, _Period, m_psar_step, m_psar_max);
    if(handle!=INVALID_HANDLE){int n=ArraySize(m_psar_handles); ArrayResize(m_psar_handles,n+1); m_psar_handles[n].symbol=symbol; m_psar_handles[n].handle=handle;}
    return handle;
}

// --- توابع کمکی برای محاسبه سطوح SL ---
double CTrailingStopManager::CalculateIchimokuSL(string symbol) {
    int handle = GetIchimokuHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    int buffer_idx = (m_tsl_mode == TSL_MODE_TENKAN) ? 0 : 1;
    double values[1];
    if(CopyBuffer(handle, buffer_idx, 1, 1, values) < 1) return 0.0;
    return values[0];
}
double CTrailingStopManager::CalculateMaSL(string symbol) {
    int handle = GetMaHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0;
    return values[0];
}
double CTrailingStopManager::CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type) {
    int handle = GetAtrHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0; // ✅ استفاده از کندل قبلی
    double atr_offset = values[0] * m_atr_multiplier;
    if(type == POSITION_TYPE_BUY) return SymbolInfoDouble(symbol, SYMBOL_BID) - atr_offset;
    else return SymbolInfoDouble(symbol, SYMBOL_ASK) + atr_offset;
}
double CTrailingStopManager::CalculatePsarSL(string symbol) {
    int handle = GetPsarHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0; // ✅ استفاده از کندل قبلی
    return values[0];
}
double CTrailingStopManager::CalculatePriceChannelSL(string symbol, ENUM_POSITION_TYPE type) {
    double values[];
    if(type == POSITION_TYPE_BUY) {
        if(CopyLow(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0;
        return values[ArrayMinimum(values, 0, m_pricechannel_period)];
    } else {
        if(CopyHigh(symbol, _Period, 1, m_pricechannel_period, values) < m_pricechannel_period) return 0.0;
        return values[ArrayMaximum(values, 0, m_pricechannel_period)];
    }
}
double CTrailingStopManager::CalculateChandelierAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
    // این متد به هر دو داده سقف/کف و ATR نیاز دارد
    int atr_handle = GetAtrHandle(symbol); if(atr_handle == INVALID_HANDLE) return 0.0;
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
    else // POSITION_TYPE_SELL
    {
        if(CopyLow(symbol, _Period, 1, m_pricechannel_period, price_channel_values) < m_pricechannel_period) return 0.0;
        double lowest_low = price_channel_values[ArrayMinimum(price_channel_values, 0, m_pricechannel_period)];
        return lowest_low + atr_offset;
    }
}
