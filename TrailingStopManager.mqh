//+------------------------------------------------------------------+
//|                                                                  |
//|         Project: Universal Trailing Stop Loss Library            |
//|                  File: TrailingStopManager.mqh                   |
//|                  Version: 3.0 (Professional & Final)             |
//|                  © 2025, Mohammad & Gemini                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "3.0"

#include <Trade\Trade.mqh>

//================================================================================//
//|                                                                                |
//|                         --- راهنمای استفاده سریع ---                            |
//|                                                                                |
//|  برای اضافه کردن این کتابخانه به هر اکسپرتی، مراحل زیر را دنبال کنید:            |
//|                                                                                |
//|  ۱. این فایل (TrailingStopManager.mqh) را در کنار فایل اکسپرت خود قرار دهید.     |
//|                                                                                |
//|  ۲. در فایل اکسپرت اصلی (.mq5)، این دو خط را به بالای فایل اضافه کنید:          |
//|     #include "TrailingStopManager.mqh"                                         |
//|     CTrailingStopManager TrailingStop; // ساخت یک نمونه سراسری از کلاس          |
//|                                                                                |
//|  ۳. در انتهای تابع OnInit اکسپرت خود، این خط را اضافه کنید:                      |
//|     TrailingStop.Init(magic_number); // magic_number شماره جادویی اکسپرت شماست   |
//|                                                                                |
//|  ۴. در انتهای تابع OnTimer (یا OnTick) اکسپرت خود، این خط را اضافه کنید:          |
//|     TrailingStop.Process();                                                    |
//|                                                                                |
//|  تمام! تنظیمات این کتابخانه به صورت خودکار به ورودی‌های اکسپرت شما اضافه می‌شود.  |
//|                                                                                |
//================================================================================//


//================================================================//
//     بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play      //
//================================================================//
input group "---=== 🛡️ Trailing Stop Universal 🛡️ ===---";

// --- تنظیمات اصلی و قابل مشاهده در اکسپرت ---
input bool                Inp_TSL_Enable           = true;     // ✅ فعال/غیرفعال کردن حد ضرر متحرک
input double              Inp_TSL_Activation_RR    = 1.0;      // فعال‌سازی در این نسبت ریسک به ریوارد (1.0 = 1:1)

// --- انواع شمارشی برای انتخاب روش تریل ---
enum E_TSL_Mode
{
    TSL_MODE_TENKAN,       // بر اساس خط تنکان-سن ایچیموکو
    TSL_MODE_KIJUN,        // بر اساس خط کیجون-سن ایچیموکو
    TSL_MODE_MA,           // بر اساس مووینگ اوریج
    TSL_MODE_ATR,          // بر اساس اندیکاتور ATR (Average True Range)
    TSL_MODE_PSAR,         // بر اساس اندیکاتور Parabolic SAR
    TSL_MODE_CHANDELIER    // بر اساس سقف/کف کانال (Chandelier Exit)
};
input E_TSL_Mode          Inp_TSL_Mode             = TSL_MODE_TENKAN; // روش اجرای حد ضرر متحرک

// --- پارامترهای داخلی (برای تنظیمات پیشرفته، کلمه input را از کامنت خارج کنید) ---
//input group "--- پارامترهای داخلی Trailing Stop ---";
/*input*/ double Inp_TSL_Buffer_Pips      = 3.0;      // فاصله از خط تریل (بر حسب پیپ)

/*input*/ int    Inp_TSL_Ichimoku_Tenkan  = 9;        // [ایچیموکو] دوره تنکان
/*input*/ int    Inp_TSL_Ichimoku_Kijun   = 26;       // [ایچیموکو] دوره کیجون
/*input*/ int    Inp_TSL_Ichimoku_Senkou  = 52;       // [ایچیموکو] دوره سنکو

/*input*/ int    Inp_TSL_MA_Period        = 50;       // [MA] دوره مووینگ اوریج
/*input*/ ENUM_MA_METHOD Inp_TSL_MA_Method  = MODE_SMA;   // [MA] نوع مووینگ اوریج
/*input*/ ENUM_APPLIED_PRICE Inp_TSL_MA_Price = PRICE_CLOSE;// [MA] قیمت اعمال

/*input*/ int    Inp_TSL_ATR_Period       = 14;       // [ATR] دوره ATR
/*input*/ double Inp_TSL_ATR_Multiplier   = 2.5;      // [ATR] ضریب ATR

/*input*/ double Inp_TSL_PSAR_Step        = 0.02;     // [PSAR] گام
/*input*/ double Inp_TSL_PSAR_Max         = 0.2;      // [PSAR] حداکثر

/*input*/ int    Inp_TSL_Chandelier_Period= 22;       // [Chandelier] دوره سقف/کف


//+------------------------------------------------------------------+
//| ساختار داخلی برای مدیریت بهینه هندل‌های اندیکاتور (مولتی-کارنسی) |
//+------------------------------------------------------------------+
struct SIndicatorHandle
{
    string symbol; // نام نماد
    int    handle; // هندل اندیکاتور
};

//+------------------------------------------------------------------+
//|           کلاس اصلی مدیریت حد ضرر متحرک                          |
//+------------------------------------------------------------------+
class CTrailingStopManager
{
private:
    // --- متغیرهای داخلی ---
    long                m_magic_number;
    bool                m_is_initialized;
    CTrade              m_trade;

    // --- تنظیمات خوانده شده از ورودی‌ها ---
    bool                m_tsl_enabled;
    double              m_activation_rr;
    E_TSL_Mode          m_tsl_mode;
    double              m_buffer_pips;
    int                 m_ichimoku_tenkan, m_ichimoku_kijun, m_ichimoku_senkou;
    int                 m_ma_period;
    ENUM_MA_METHOD      m_ma_method;
    ENUM_APPLIED_PRICE  m_ma_price;
    int                 m_atr_period;
    double              m_atr_multiplier;
    double              m_psar_step, m_psar_max;
    int                 m_chandelier_period;
    
    // --- آرایه‌ها برای مدیریت هندل‌های اندیکاتورها (هر اندیکاتور لیست خودش را دارد) ---
    SIndicatorHandle    m_ichimoku_handles[];
    SIndicatorHandle    m_ma_handles[];
    SIndicatorHandle    m_atr_handles[];
    SIndicatorHandle    m_psar_handles[];

    // --- توابع کمکی خصوصی برای دریافت هندل (مخفی و بدون رسم روی چارت) ---
    int     GetIchimokuHandle(string symbol);
    int     GetMaHandle(string symbol);
    int     GetAtrHandle(string symbol);
    int     GetPsarHandle(string symbol);

    // --- توابع کمکی خصوصی برای محاسبه سطح SL ---
    double  CalculateIchimokuSL(string symbol);
    double  CalculateMaSL(string symbol);
    double  CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type);
    double  CalculatePsarSL(string symbol);
    double  CalculateChandelierSL(string symbol, ENUM_POSITION_TYPE type);

public:
    // --- سازنده و مخرب ---
    CTrailingStopManager() { m_magic_number = 0; m_is_initialized = false; }
    ~CTrailingStopManager();

    // --- توابع عمومی اصلی ---
    void Init(long magic_number);
    void Process();
};


// --- مخرب کلاس (برای پاکسازی منابع) ---
CTrailingStopManager::~CTrailingStopManager()
{
    // پاکسازی تمام هندل‌های اندیکاتور در زمان بسته شدن اکسپرت برای جلوگیری از نشت حافظه
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

    // خواندن تنظیمات از ورودی‌ها
    m_tsl_enabled     = Inp_TSL_Enable;
    m_activation_rr   = Inp_TSL_Activation_RR > 0 ? Inp_TSL_Activation_RR : 1.0;
    m_tsl_mode        = Inp_TSL_Mode;
    m_buffer_pips     = Inp_TSL_Buffer_Pips;
    m_ichimoku_tenkan = Inp_TSL_Ichimoku_Tenkan;
    m_ichimoku_kijun  = Inp_TSL_Ichimoku_Kijun;
    m_ichimoku_senkou = Inp_TSL_Ichimoku_Senkou;
    m_ma_period       = Inp_TSL_MA_Period;
    m_ma_method       = Inp_TSL_MA_Method;
    m_ma_price        = Inp_TSL_MA_Price;
    m_atr_period      = Inp_TSL_ATR_Period;
    m_atr_multiplier  = Inp_TSL_ATR_Multiplier;
    m_psar_step       = Inp_TSL_PSAR_Step;
    m_psar_max        = Inp_TSL_PSAR_Max;
    m_chandelier_period = Inp_TSL_Chandelier_Period;
    
    if(m_tsl_enabled) Print("کتابخانه Trailing Stop Universal با موفقیت برای مجیک نامبر ", m_magic_number, " فعال شد.");
    
    m_is_initialized = true;
}

// --- تابع اصلی پردازش که در هر تیک/تایمر اجرا می‌شود ---
void CTrailingStopManager::Process()
{
    if(!m_tsl_enabled || !m_is_initialized) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(i)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;

        long   ticket     = PositionGetInteger(POSITION_TICKET);
        string symbol     = PositionGetString(POSITION_SYMBOL);
        
        // دریافت SL اولیه از تاریخچه معامله برای محاسبه دقیق ریسک
        double initial_sl = 0;
        if(HistorySelectByPosition(ticket) && HistoryDealsTotal() > 0)
        {
           ulong deal_ticket = HistoryDealGetTicket(0);
           if(deal_ticket > 0) initial_sl = HistoryDealGetDouble(deal_ticket, DEAL_SL);
        }
        
        if(initial_sl == 0) continue; // اگر معامله از ابتدا SL نداشته، تریل نمی‌کنیم

        // --- مرحله ۱: چک کردن شرط فعال‌سازی Trailing Stop ---
        double open_price      = PositionGetDouble(POSITION_PRICE_OPEN);
        double initial_risk    = MathAbs(open_price - initial_sl);
        double required_profit = initial_risk * m_activation_rr;
        double current_profit  = PositionGetDouble(POSITION_PROFIT);

        if(current_profit < required_profit) continue;

        // --- مرحله ۲: محاسبه سطح جدید حد ضرر ---
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double new_sl_level = 0;
        switch(m_tsl_mode)
        {
            case TSL_MODE_TENKAN:
            case TSL_MODE_KIJUN:       new_sl_level = CalculateIchimokuSL(symbol);        break;
            case TSL_MODE_MA:          new_sl_level = CalculateMaSL(symbol);              break;
            case TSL_MODE_ATR:         new_sl_level = CalculateAtrSL(symbol, type);       break;
            case TSL_MODE_PSAR:        new_sl_level = CalculatePsarSL(symbol);            break;
            case TSL_MODE_CHANDELIER:  new_sl_level = CalculateChandelierSL(symbol, type);break;
        }

        if(new_sl_level == 0) continue;

        // --- مرحله ۳: اعمال بافر (فقط برای روش‌های نیازمند به بافر) ---
        double final_new_sl = new_sl_level;
        if(m_tsl_mode == TSL_MODE_TENKAN || m_tsl_mode == TSL_MODE_KIJUN || m_tsl_mode == TSL_MODE_MA)
        {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double buffer_points = m_buffer_pips * point;
            if(type == POSITION_TYPE_BUY) final_new_sl -= buffer_points;
            else final_new_sl += buffer_points;
        }
        
        // نرمال‌سازی قیمت بر اساس ارقام اعشار نماد
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        final_new_sl = NormalizeDouble(final_new_sl, digits);

        // --- مرحله ۴: چک کردن اعتبار و بهبود حد ضرر ---
        double current_sl      = PositionGetDouble(POSITION_SL);
        bool should_modify = false;
        if(type == POSITION_TYPE_BUY)
        {
            if(final_new_sl > current_sl && final_new_sl < SymbolInfoDouble(symbol, SYMBOL_BID))
                should_modify = true;
        }
        else // POSITION_TYPE_SELL
        {
            if(final_new_sl < current_sl && final_new_sl > SymbolInfoDouble(symbol, SYMBOL_ASK))
                should_modify = true;
        }
        
        // --- مرحله ۵: ارسال دستور ویرایش پوزیشن ---
        if(should_modify)
        {
            m_trade.PositionModify(ticket, final_new_sl, PositionGetDouble(POSITION_TP));
        }
    }
}

// --- توابع کمکی برای مدیریت هندل‌ها (موتور مولتی-کارنسی) ---
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

// --- توابع کمکی برای محاسبه سطوح SL ---
double CTrailingStopManager::CalculateIchimokuSL(string symbol)
{
    int handle = GetIchimokuHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    int buffer_idx = (m_tsl_mode == TSL_MODE_TENKAN) ? 0 : 1;
    double values[1];
    if(CopyBuffer(handle, buffer_idx, 1, 1, values) < 1) return 0.0;
    return values[0];
}
double CTrailingStopManager::CalculateMaSL(string symbol)
{
    int handle = GetMaHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 1, 1, values) < 1) return 0.0;
    return values[0];
}
double CTrailingStopManager::CalculateAtrSL(string symbol, ENUM_POSITION_TYPE type)
{
    int handle = GetAtrHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 0, 1, values) < 1) return 0.0;
    double atr_offset = values[0] * m_atr_multiplier;
    if(type == POSITION_TYPE_BUY) return SymbolInfoDouble(symbol, SYMBOL_BID) - atr_offset;
    else return SymbolInfoDouble(symbol, SYMBOL_ASK) + atr_offset;
}
double CTrailingStopManager::CalculatePsarSL(string symbol)
{
    int handle = GetPsarHandle(symbol); if(handle == INVALID_HANDLE) return 0.0;
    double values[1];
    if(CopyBuffer(handle, 0, 0, 1, values) < 1) return 0.0;
    return values[0];
}
double CTrailingStopManager::CalculateChandelierSL(string symbol, ENUM_POSITION_TYPE type)
{
    double values[];
    if(type == POSITION_TYPE_BUY)
    {
        if(CopyLow(symbol, _Period, 1, m_chandelier_period, values) < m_chandelier_period) return 0.0;
        return values[ArrayMinimum(values, 0, m_chandelier_period)];
    }
    else // POSITION_TYPE_SELL
    {
        if(CopyHigh(symbol, _Period, 1, m_chandelier_period, values) < m_chandelier_period) return 0.0;
        return values[ArrayMaximum(values, 0, m_chandelier_period)];
    }
}
