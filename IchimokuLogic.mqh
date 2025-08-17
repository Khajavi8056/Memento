//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "2.1" 
#include "set.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh>
#include "VisualManager.mqh"
#include <MovingAverages.mqh>
#include "MarketStructure.mqh"

//+------------------------------------------------------------------+
//| ساختار سیگنال‌های بالقوه (SPotentialSignal) - برای ذخیره سیگنال‌ها در خزانه داده |
//| این ساختار تمام اطلاعات لازم برای یک سیگنال را نگهداری می‌کند. |
//+------------------------------------------------------------------+
struct SPotentialSignal
{
    long            id;                  // شناسه منحصر به فرد سیگنال (برای ردیابی)
    datetime        time;                // زمان تشکیل سیگنال اولیه (شیفت چیکو)
    bool            is_buy;              // جهت سیگنال (true برای خرید، false برای فروش)
    E_Signal_State  state;               // وضعیت فعلی سیگنال (INITIAL, CONFIRMED و غیره)
    int             grace_candle_count;  // شمارنده تعداد کندل‌های گذشته برای مهلت زمانی
    double          invalidation_level;  // سطح ابطال ساختاری برای حالت GRACE_BY_STRUCTURE
    
    // سازنده پیش‌فرض: برای مقداردهی اولیه تمام فیلدها به مقادیر پیش‌فرض
    SPotentialSignal()
    {
        id = 0;                          // مقداردهی اولیه شناسه به 0
        time = 0;                        // مقداردهی اولیه زمان به 0
        is_buy = false;                  // مقداردهی اولیه جهت به false (فروش)
        state = INITIAL;                 // وضعیت پیش‌فرض: INITIAL
        grace_candle_count = 0;          // مقداردهی اولیه شمارنده به 0
        invalidation_level = 0.0;        // مقداردهی اولیه سطح ابطال به 0.0
    }
    
    // سازنده کپی: برای کپی کردن یک ساختار بدون از دست دادن اطلاعات
    SPotentialSignal(const SPotentialSignal &other)
    {
        id = other.id;                   // کپی شناسه
        time = other.time;               // کپی زمان
        is_buy = other.is_buy;           // کپی جهت
        state = other.state;             // کپی وضعیت
        grace_candle_count = other.grace_candle_count; // کپی شمارنده
        invalidation_level = other.invalidation_level; // کپی سطح ابطال
    }
};

//+------------------------------------------------------------------+
//| کلاس خزانه داده مرکزی (CContext) - تنها منبع حقیقت در کل سیستم   |
//| این کلاس تمام وضعیت‌های سیستم، مانند سیگنال‌های نامزد و تنظیمات را مدیریت می‌کند. |
//| تمام ماژول‌ها فقط از طریق این کلاس به داده‌ها دسترسی دارند.        |
//+------------------------------------------------------------------+
class CContext
{
private:
    SSettings       m_settings;          // کپی تنظیمات ورودی اکسپرت برای دسترسی محلی
    SPotentialSignal m_potential_signals[]; // آرایه پویا برای نگهداری سیگنال‌های بالقوه
    long            m_next_signal_id;    // شمارنده برای تولید شناسه منحصر به فرد بعدی برای سیگنال‌ها

public:
    // تابع Init: مقداردهی اولیه خزانه داده با تنظیمات ورودی
    // این تابع تنظیمات را کپی می‌کند و آرایه سیگنال‌ها را ریست می‌کند.
    void Init(const SSettings &settings)
    {
        m_settings = settings;           // کپی تنظیمات برای دسترسی مستقل
        ArrayFree(m_potential_signals);  // خالی کردن آرایه سیگنال‌ها برای شروع تازه
        m_next_signal_id = 1;            // شروع شمارنده شناسه از ۱
    }
    
    // تابع AddSignal: اضافه کردن یک سیگنال جدید به خزانه داده
    // این تابع شناسه منحصر به فرد اختصاص می‌دهد و سیگنال را به آرایه اضافه می‌کند.
    void AddSignal(const SPotentialSignal &signal)
    {
        SPotentialSignal new_signal = signal; // کپی سیگنال ورودی
        new_signal.id = m_next_signal_id++;   // اختصاص شناسه منحصر به فرد و افزایش شمارنده
        new_signal.state = INITIAL;           // تنظیم وضعیت اولیه سیگنال به INITIAL
        int total = ArraySize(m_potential_signals); // گرفتن تعداد فعلی سیگنال‌ها
        ArrayResize(m_potential_signals, total + 1); // افزایش اندازه آرایه برای اضافه کردن سیگنال جدید
        m_potential_signals[total] = new_signal; // اضافه کردن سیگنال به انتهای آرایه
    }
    
    // تابع UpdateSignalState: آپدیت وضعیت یک سیگنال خاص بر اساس شناسه آن
    // این تابع وضعیت سیگنال را تغییر می‌دهد بدون تاثیر به سایر فیلدها.
    void UpdateSignalState(long signal_id, E_Signal_State new_state)
    {
        for(int i = 0; i < ArraySize(m_potential_signals); i++) // حلقه روی تمام سیگنال‌ها
        {
            if(m_potential_signals[i].id == signal_id) // اگر شناسه مطابقت داشت
            {
                m_potential_signals[i].state = new_state; // آپدیت وضعیت
                break; // خروج از حلقه پس از پیدا کردن سیگنال
            }
        }
    }
    
    // تابع GetInitialSignals: برگرداندن تمام سیگنال‌های در وضعیت INITIAL
    // این تابع یک آرایه جدید از سیگنال‌های INITIAL می‌سازد و برمی‌گرداند.
    void GetInitialSignals(SPotentialSignal &signals[])
    {
        ArrayFree(signals); // خالی کردن آرایه خروجی برای جلوگیری از داده‌های قدیمی
        for(int i = 0; i < ArraySize(m_potential_signals); i++) // حلقه روی تمام سیگنال‌ها
        {
            if(m_potential_signals[i].state == INITIAL) // اگر وضعیت INITIAL بود
            {
                int total = ArraySize(signals); // گرفتن تعداد فعلی در آرایه خروجی
                ArrayResize(signals, total + 1); // افزایش اندازه آرایه خروجی
                signals[total] = m_potential_signals[i]; // اضافه کردن سیگنال به آرایه خروجی
            }
        }
    }
    
    // تابع GetConfirmedSignals: برگرداندن تمام سیگنال‌های در وضعیت CONFIRMED
    // این تابع یک آرایه جدید از سیگنال‌های CONFIRMED می‌سازد و برمی‌گرداند.
    void GetConfirmedSignals(SPotentialSignal &signals[])
    {
        ArrayFree(signals); // خالی کردن آرایه خروجی
        for(int i = 0; i < ArraySize(m_potential_signals); i++) // حلقه روی تمام سیگنال‌ها
        {
            if(m_potential_signals[i].state == CONFIRMED) // اگر وضعیت CONFIRMED بود
            {
                int total = ArraySize(signals);
                ArrayResize(signals, total + 1);
                signals[total] = m_potential_signals[i];
            }
        }
    }
    
    // تابع Cleanup: حذف سیگنال‌های EXPIRED, INVALIDATED یا EXECUTED از خزانه
    // این تابع برای جلوگیری از انباشت سیگنال‌های قدیمی استفاده می‌شود.
    void Cleanup()
    {
        for(int i = ArraySize(m_potential_signals) - 1; i >= 0; i--) // حلقه از آخر به اول برای حذف ایمن
        {
            E_Signal_State state = m_potential_signals[i].state;
            if(state == EXPIRED || state == INVALIDATED || state == EXECUTED) // اگر وضعیت یکی از این‌ها بود
            {
                ArrayRemove(m_potential_signals, i, 1); // حذف سیگنال از آرایه
            }
        }
    }
    
    // تابع ClearInitialSignals: پاک کردن تمام سیگنال‌های در وضعیت INITIAL
    // این تابع برای حالت MODE_REPLACE_SIGNAL استفاده می‌شود تا سیگنال‌های قدیمی پاک شوند.
    void ClearInitialSignals()
    {
        for(int i = ArraySize(m_potential_signals) - 1; i >= 0; i--) // حلقه از آخر به اول برای حذف ایمن
        {
            if(m_potential_signals[i].state == INITIAL) // اگر سیگنال در وضعیت INITIAL بود
            {
                ArrayRemove(m_potential_signals, i, 1); // حذف سیگنال از آرایه
            }
        }
    }
};

//+------------------------------------------------------------------+
//| کلاس پردازشگر سیگنال (CSignalProcessor) - ماژول متخصص بدون حالت   |
//| این کلاس تمام توابع منطقی استراتژی را بدون حفظ حالت (stateless) پیاده‌سازی می‌کند. |
//| تمام ورودی‌ها از پارامترها گرفته می‌شود و هیچ متغیری داخلی ندارد. |
//+------------------------------------------------------------------+
class CSignalProcessor
{
public:
    // تابع CheckTripleCross: بررسی کراس سه‌گانه ایچیموکو
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، هندل ایچیموکو
    // خروجی: true اگر کراس پیدا شد، و جهت آن در is_buy
    bool CheckTripleCross(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, bool &is_buy, const int ichimoku_handle)
    {
        // کامنت: گرفتن شیفت چیکو از تنظیمات
        const int shift = settings.chikou_period;
        
        // کامنت: چک کردن وجود داده کافی در چارت
        if (iBars(symbol, timeframe) < shift + 2) return false;

        // کامنت: کپی مقادیر تنکان و کیجون در شیفت و شیفت قبلی
        double tk_shifted[2], ks_shifted[2];
        if(CopyBuffer(ichimoku_handle, 0, shift, 2, tk_shifted) < 2 || 
           CopyBuffer(ichimoku_handle, 1, shift, 2, ks_shifted) < 2)
        {
            return false;
        }
        
        const double tenkan_at_shift = tk_shifted[0];
        const double kijun_at_shift = ks_shifted[0];
        const double tenkan_prev_shift = tk_shifted[1];
        const double kijun_prev_shift = ks_shifted[1];

        // کامنت: چک کردن کراس تنکان و کیجون
        const bool is_cross_up = tenkan_prev_shift < kijun_prev_shift && tenkan_at_shift > kijun_at_shift;
        const bool is_cross_down = tenkan_prev_shift > kijun_prev_shift && tenkan_at_shift < kijun_at_shift;
        const bool is_tk_cross = is_cross_up || is_cross_down;

        // کامنت: محاسبه تلورانس تلاقی بر اساس حالت انتخابی
        const double tolerance = GetTalaqiTolerance(settings, symbol, timeframe, shift, ichimoku_handle);
        const bool is_confluence = (tolerance > 0) ? (MathAbs(tenkan_at_shift - kijun_at_shift) <= tolerance) : false;

        if (!is_tk_cross && !is_confluence) return false;

        // کامنت: چک کردن کراس چیکو (قیمت فعلی به عنوان چیکو)
        const double chikou_now = iClose(symbol, timeframe, 1);
        const double chikou_prev = iClose(symbol, timeframe, 2);
        const double upper_line = MathMax(tenkan_at_shift, kijun_at_shift);
        const double lower_line = MathMin(tenkan_at_shift, kijun_at_shift);

        const bool chikou_crosses_up = chikou_now > upper_line && chikou_prev < upper_line;
        if (chikou_crosses_up)
        {
            is_buy = true;
            return true;
        }

        const bool chikou_crosses_down = chikou_now < lower_line && chikou_prev > lower_line;
        if (chikou_crosses_down)
        {
            is_buy = false;
            return true;
        }

        return false;
    }

    // تابع CheckConfirmation: بررسی تاییدیه نهایی ورود
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت سیگنال، تحلیلگر LTF
    // خروجی: true اگر تاییدیه دریافت شد
    bool CheckConfirmation(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, CMarketStructureShift &ltf_analyzer)
    {
        // کامنت: انتخاب روش تاییدیه بر اساس تنظیمات
        switch(settings.entry_confirmation_mode)
        {
            case CONFIRM_LOWER_TIMEFRAME:
            {
                // کامنت: بررسی تاییدیه با شکست ساختار در LTF
                SMssSignal mss_signal = ltf_analyzer.ProcessNewBar();
                if(mss_signal.type == MSS_NONE) return false;
                if (is_buy && (mss_signal.type == MSS_BREAK_HIGH || mss_signal.type == MSS_SHIFT_UP)) return true;
                if (!is_buy && (mss_signal.type == MSS_BREAK_LOW || mss_signal.type == MSS_SHIFT_DOWN)) return true;
                return false;
            }

            case CONFIRM_CURRENT_TIMEFRAME:
            {
                // کامنت: بررسی تاییدیه با کندل در تایم فعلی
                if (iBars(symbol, timeframe) < 2) return false;

                const int ichimoku_handle = iIchimoku(symbol, timeframe, settings.tenkan_period, settings.kijun_period, settings.senkou_period);
                double tenkan_buffer[1], kijun_buffer[1];
                CopyBuffer(ichimoku_handle, 0, 1, 1, tenkan_buffer);
                CopyBuffer(ichimoku_handle, 1, 1, 1, kijun_buffer);
                IndicatorRelease(ichimoku_handle);

                const double tenkan_at_1 = tenkan_buffer[0];
                const double kijun_at_1 = kijun_buffer[0];
                const double open_at_1 = iOpen(symbol, timeframe, 1);
                const double close_at_1 = iClose(symbol, timeframe, 1);

                if (is_buy)
                {
                    if (tenkan_at_1 <= kijun_at_1) return false;
                    if (settings.confirmation_type == MODE_OPEN_AND_CLOSE) {
                        if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                            return true;
                    } else {
                        if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                            return true;
                    }
                }
                else
                {
                    if (tenkan_at_1 >= kijun_at_1) return false;
                    if (settings.confirmation_type == MODE_OPEN_AND_CLOSE) {
                        if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                            return true;
                    } else {
                        if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                            return true;
                    }
                }
                return false;
            }
        }
        return false;
    }

    // تابع AreAllFiltersPassed: بررسی تمام فیلترهای ورود
    // ورودی‌ها: تنظیمات، نماد، تایم فریم محاسبات، جهت، هندل‌های اندیکاتور
    // خروجی: true اگر تمام فیلترها پاس شدند
    bool AreAllFiltersPassed(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES context_tf, const bool is_buy, const int ichimoku_handle, const int atr_handle, const int adx_handle)
    {
        // کامنت: چک فیلتر کومو اگر فعال باشد
        if (settings.enable_kumo_filter)
        {
            if (!CheckKumoFilter(settings, symbol, context_tf, is_buy, ichimoku_handle))
            {
                return false; // فیلتر کومو رد شد
            }
        }

        // کامنت: چک فیلتر ATR اگر فعال باشد
        if (settings.enable_atr_filter)
        {
            if (!CheckAtrFilter(settings, symbol, context_tf, atr_handle))
            {
                return false; // فیلتر ATR رد شد
            }
        }
        
        // کامنت: چک فیلتر ADX اگر فعال باشد
        if (settings.enable_adx_filter)
        {
            if (!CheckAdxFilter(settings, symbol, context_tf, is_buy, adx_handle))
            {
                return false; // فیلتر ADX رد شد
            }
        }
        
        return true; // تمام فیلترها پاس شدند
    }

    // تابع CheckKumoFilter: فیلتر موقعیت قیمت نسبت به ابر کومو
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، هندل ایچیموکو
    // خروجی: true اگر موقعیت قیمت مناسب باشد
    bool CheckKumoFilter(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const int ichimoku_handle)
    {
        double senkou_a[1], senkou_b[1];
        // کامنت: کپی سنکو A و B برای کندل فعلی
        if(CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_a) < 1 || 
           CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_b) < 1)
        {
            return false; // داده کافی نیست
        }
        
        const double high_kumo = MathMax(senkou_a[0], senkou_b[0]); // بالاترین سطح ابر
        const double low_kumo = MathMin(senkou_a[0], senkou_b[0]); // پایین‌ترین سطح ابر
        const double close_price = iClose(symbol, timeframe, 1); // قیمت بسته شدن کندل تاییدیه

        if (is_buy)
        {
            return (close_price > high_kumo); // برای خرید، قیمت بالای ابر باشد
        }
        else
        {
            return (close_price < low_kumo); // برای فروش، قیمت پایین ابر باشد
        }
    }

    // تابع CheckAtrFilter: فیلتر حداقل نوسان با ATR
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، هندل ATR
    // خروجی: true اگر ATR بیشتر از آستانه باشد
    bool CheckAtrFilter(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const int atr_handle)
    {
        double atr_value_buffer[1];
        // کامنت: کپی مقدار ATR برای کندل قبلی
        if(CopyBuffer(atr_handle, 0, 1, 1, atr_value_buffer) < 1)
            return false; // داده کافی نیست
        
        const double current_atr = atr_value_buffer[0];
        
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double min_atr_threshold = settings.atr_filter_min_value_pips * point;
        if(_Digits == 3 || _Digits == 5)
        {
            min_atr_threshold *= 10; // تنظیم برای نمادهای ۳ یا ۵ رقمی
        }

        return (current_atr >= min_atr_threshold); // چک آستانه ATR
    }

    // تابع CheckAdxFilter: فیلتر قدرت و جهت روند با ADX
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، هندل ADX
    // خروجی: true اگر قدرت روند کافی و جهت مناسب باشد
    bool CheckAdxFilter(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const int adx_handle) 
    {  
        double adx_buffer[1], di_plus_buffer[1], di_minus_buffer[1];  
        
        // کامنت: کپی بافرهای ADX, DI+, DI- برای کندل قبلی
        if (CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) < 1 || 
            CopyBuffer(adx_handle, 1, 1, 1, di_plus_buffer) < 1 || 
            CopyBuffer(adx_handle, 2, 1, 1, di_minus_buffer) < 1)
        {
            return false; // داده کافی نیست
        }
        
        // شرط قدرت روند
        if (adx_buffer[0] <= settings.adx_threshold) 
        {
            return false;
        }
        
        // شرط جهت روند
        if (is_buy)
        {
            return (di_plus_buffer[0] > di_minus_buffer[0]); // DI+ > DI- برای خرید
        }
        else
        {
            return (di_minus_buffer[0] > di_plus_buffer[0]); // DI- > DI+ برای فروش
        }
    }

    // تابع CalculateStopLoss: محاسبه حد ضرر بر اساس روش انتخابی
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، قیمت ورود، هندل‌های لازم
    // خروجی: قیمت استاپ لاس محاسبه شده
    double CalculateStopLoss(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const double entry_price, const int ichimoku_handle, const int atr_handle)
    {
        // کامنت: اگر روش ساده باشد، از پشتیبان استفاده کن
        if (settings.stoploss_type == MODE_SIMPLE)
        {
            const double buffer = settings.sl_buffer_multiplier * SymbolInfoDouble(symbol, SYMBOL_POINT);
            return FindBackupStopLoss(settings, symbol, timeframe, is_buy, buffer);
        }
        
        // کامنت: اگر روش ATR باشد، از ATR استفاده کن
        if (settings.stoploss_type == MODE_ATR)
        {
            double sl_price = CalculateAtrStopLoss(settings, symbol, timeframe, is_buy, entry_price, atr_handle);
            if (sl_price == 0) 
            {
                const double buffer = settings.sl_buffer_multiplier * SymbolInfoDouble(symbol, SYMBOL_POINT);
                return FindBackupStopLoss(settings, symbol, timeframe, is_buy, buffer);
            }
            return sl_price;
        }

        // کامنت: منطق پیچیده (MODE_COMPLEX): جمع‌آوری کاندیداها
        double candidates[];
        int count = 0;
        double sl_candidate = 0;
        const double buffer = settings.sl_buffer_multiplier * SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        // کاندیدا ۱: کیجون فلت
        sl_candidate = FindFlatKijun(settings, symbol, timeframe, ichimoku_handle);
        if (sl_candidate > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
            count++;
        }
        
        // کاندیدا ۲: پیوت کیجون
        sl_candidate = FindPivotKijun(settings, symbol, timeframe, is_buy, ichimoku_handle);
        if (sl_candidate > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
            count++;
        }

        // کاندیدا ۳: پیوت تنکان
        sl_candidate = FindPivotTenkan(settings, symbol, timeframe, is_buy, ichimoku_handle);
        if (sl_candidate > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
            count++;
        }

        // کاندیدا ۴: پشتیبان ساده
        sl_candidate = FindBackupStopLoss(settings, symbol, timeframe, is_buy, buffer);
        if (sl_candidate > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = sl_candidate;
            count++;
        }
        
        // کاندیدا ۵: ATR
        sl_candidate = CalculateAtrStopLoss(settings, symbol, timeframe, is_buy, entry_price, atr_handle);
        if (sl_candidate > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = sl_candidate;
            count++;
        }

        if (count == 0) return 0.0;

        // کامنت: اعتبارسنجی کاندیداها و انتخاب نزدیک‌ترین
        double valid_candidates[];
        int valid_count = 0;
        const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        const double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
        const double min_safe_distance = spread + buffer;

        for (int i = 0; i < count; i++)
        {
            double current_sl = candidates[i];
            
            if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price))
                continue;

            if (MathAbs(entry_price - current_sl) < min_safe_distance)
                current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance;

            ArrayResize(valid_candidates, valid_count + 1);
            valid_candidates[valid_count] = current_sl;
            valid_count++;
        }

        if (valid_count == 0) return 0.0;
        
        double best_sl_price = 0.0;
        double smallest_distance = DBL_MAX;

        for (int i = 0; i < valid_count; i++)
        {
            double distance = MathAbs(entry_price - valid_candidates[i]);
            if (distance < smallest_distance)
            {
                smallest_distance = distance;
                best_sl_price = valid_candidates[i];
            }
        }

        return best_sl_price;
    }

    // تابع کمکی GetTalaqiTolerance: محاسبه حد مجاز تلاقی
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، شیفت مرجع، هندل ایچیموکو
    // خروجی: تلورانس محاسبه شده
    double GetTalaqiTolerance(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const int reference_shift, const int ichimoku_handle)
    {
        switch(settings.talaqi_calculation_mode)
        {
            case TALAQI_MODE_MANUAL:
                return settings.talaqi_distance_in_points * SymbolInfoDouble(symbol, SYMBOL_POINT);
            
            case TALAQI_MODE_KUMO:
                return CalculateDynamicTolerance(settings, symbol, timeframe, reference_shift, ichimoku_handle);
            
            case TALAQI_MODE_ATR:
                return CalculateAtrTolerance(settings, symbol, timeframe, reference_shift);
            
            default:
                return 0.0;
        }
    }

    // تابع کمکی CalculateDynamicTolerance: تلورانس مبتنی بر ضخامت کومو
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، شیفت، هندل ایچیموکو
    // خروجی: تلورانس محاسبه شده
    double CalculateDynamicTolerance(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const int reference_shift, const int ichimoku_handle)
    {
        if(settings.talaqi_kumo_factor <= 0) return 0.0;

        double senkou_a_buffer[1], senkou_b_buffer[1];
        if(CopyBuffer(ichimoku_handle, 2, reference_shift, 1, senkou_a_buffer) < 1 || 
           CopyBuffer(ichimoku_handle, 3, reference_shift, 1, senkou_b_buffer) < 1)
        {
            return 0.0; // داده کافی نیست
        }

        const double kumo_thickness = MathAbs(senkou_a_buffer[0] - senkou_b_buffer[0]);
        if(kumo_thickness == 0) return SymbolInfoDouble(symbol, SYMBOL_POINT);

        return kumo_thickness * settings.talaqi_kumo_factor;
    }

    // تابع کمکی CalculateAtrTolerance: تلورانس مبتنی بر ATR
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، شیفت مرجع
    // خروجی: تلورانس محاسبه شده
    double CalculateAtrTolerance(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const int reference_shift)
    {
        if(settings.talaqi_atr_multiplier <= 0) return 0.0;
        
        const int atr_handle = iATR(symbol, timeframe, settings.atr_filter_period);
        double atr_buffer[1];
        if(CopyBuffer(atr_handle, 0, reference_shift, 1, atr_buffer) < 1)
        {
            IndicatorRelease(atr_handle);
            return 0.0;
        }
        IndicatorRelease(atr_handle);
        
        return atr_buffer[0] * settings.talaqi_atr_multiplier;
    }

    // تابع کمکی CalculateAtrStopLoss: محاسبه استاپ لاس با ATR (با پشتیبانی از رژیم نوسان)
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، قیمت ورود، هندل ATR
    // خروجی: قیمت استاپ لاس
    double CalculateAtrStopLoss(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const double entry_price, const int atr_handle)
    {
        // کامنت: اگر رژیم نوسان غیرفعال باشد، از منطق ساده ATR استفاده کن
        if (!settings.enable_sl_vol_regime)
        {
            double atr_buffer[1];
            if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1)
                return 0.0;
            
            const double atr_value = atr_buffer[0];
            return is_buy ? entry_price - (atr_value * settings.sl_atr_multiplier) : entry_price + (atr_value * settings.sl_atr_multiplier);
        }

        // کامنت: منطق پویا با رژیم نوسان
        const int history_size = settings.sl_vol_regime_ema_period + 5;
        double atr_values[], ema_values[];

        const int atr_sl_handle = iATR(symbol, timeframe, settings.sl_vol_regime_atr_period);
        if (atr_sl_handle == INVALID_HANDLE || CopyBuffer(atr_sl_handle, 0, 0, history_size, atr_values) < history_size)
        {
            if(atr_sl_handle != INVALID_HANDLE) IndicatorRelease(atr_sl_handle);
            return 0.0;
        }
        
        IndicatorRelease(atr_sl_handle);
        ArraySetAsSeries(atr_values, true); 

        if(SimpleMAOnBuffer(history_size, 0, settings.sl_vol_regime_ema_period, MODE_EMA, atr_values, ema_values) < 1)
            return 0.0;

        const double current_atr = atr_values[1]; 
        const double ema_atr = ema_values[1];     

        const bool is_high_volatility = (current_atr > ema_atr);
        const double final_multiplier = is_high_volatility ? settings.sl_high_vol_multiplier : settings.sl_low_vol_multiplier;

        return is_buy ? entry_price - (current_atr * final_multiplier) : entry_price + (current_atr * final_multiplier);
    }

    // تابع کمکی FindBackupStopLoss: استاپ لاس پشتیبان بر اساس رنگ مخالف کندل
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، بافر
    // خروجی: قیمت استاپ لاس
    double FindBackupStopLoss(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const double buffer)
    {
        const int bars_to_check = settings.sl_lookback_period;
        if (iBars(symbol, timeframe) < bars_to_check + 1) return 0;
        
        for (int i = 1; i <= bars_to_check; i++)
        {
            const bool is_candle_bullish = (iClose(symbol, timeframe, i) > iOpen(symbol, timeframe, i));
            const bool is_candle_bearish = (iClose(symbol, timeframe, i) < iOpen(symbol, timeframe, i));

            if (is_buy && is_candle_bearish)
            {
                return iLow(symbol, timeframe, i) - buffer;
            }
            else if (!is_buy && is_candle_bullish)
            {
                return iHigh(symbol, timeframe, i) + buffer;
            }
        }
        
        // کامنت: اگر کندل مخالف پیدا نشد، از سقف/کف مطلق استفاده کن
        double high_buffer[], low_buffer[];
        CopyHigh(symbol, timeframe, 1, bars_to_check, high_buffer);
        CopyLow(symbol, timeframe, 1, bars_to_check, low_buffer);

        if(is_buy)
        {
            const int min_index = ArrayMinimum(low_buffer, 0, bars_to_check);
            return low_buffer[min_index] - buffer;
        }
        else
        {
            const int max_index = ArrayMaximum(high_buffer, 0, bars_to_check);
            return high_buffer[max_index] + buffer;
        }
    }

    // تابع کمکی FindFlatKijun: پیدا کردن سطح کیجون فلت
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، هندل ایچیموکو
    // خروجی: سطح کیجون فلت اگر پیدا شد
    double FindFlatKijun(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const int ichimoku_handle)
    {
        double kijun_values[];
        if (CopyBuffer(ichimoku_handle, 1, 1, settings.flat_kijun_period, kijun_values) < settings.flat_kijun_period)
            return 0.0;

        ArraySetAsSeries(kijun_values, true);

        int flat_count = 1;
        for (int i = 1; i < settings.flat_kijun_period; i++)
        {
            if (kijun_values[i] == kijun_values[i - 1])
            {
                flat_count++;
                if (flat_count >= settings.flat_kijun_min_length)
                    return kijun_values[i]; // سطح فلت پیدا شد
            }
            else
            {
                flat_count = 1; // ریست شمارنده
            }
        }

        return 0.0; // هیچ سطح فلتی پیدا نشد
    }

    // تابع کمکی FindPivotKijun: پیدا کردن پیوت روی کیجون
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، هندل ایچیموکو
    // خروجی: سطح پیوت اگر پیدا شد
    double FindPivotKijun(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const int ichimoku_handle)
    {
        double kijun_values[];
        if (CopyBuffer(ichimoku_handle, 1, 1, settings.pivot_lookback, kijun_values) < settings.pivot_lookback)
            return 0.0;

        ArraySetAsSeries(kijun_values, true);

        for (int i = 1; i < settings.pivot_lookback - 1; i++)
        {
            if (is_buy && kijun_values[i] < kijun_values[i - 1] && kijun_values[i] < kijun_values[i + 1])
                return kijun_values[i]; // پیوت کف برای خرید
            if (!is_buy && kijun_values[i] > kijun_values[i - 1] && kijun_values[i] > kijun_values[i + 1])
                return kijun_values[i]; // پیوت سقف برای فروش
        }

        return 0.0; // هیچ پیوتی پیدا نشد
    }

    // تابع کمکی FindPivotTenkan: پیدا کردن پیوت روی تنکان
    // ورودی‌ها: تنظیمات، نماد، تایم فریم، جهت، هندل ایچیموکو
    // خروجی: سطح پیوت اگر پیدا شد
    double FindPivotTenkan(const SSettings &settings, const string symbol, const ENUM_TIMEFRAMES timeframe, const bool is_buy, const int ichimoku_handle)
    {
        double tenkan_values[];
        if (CopyBuffer(ichimoku_handle, 0, 1, settings.pivot_lookback, tenkan_values) < settings.pivot_lookback)
            return 0.0;

        ArraySetAsSeries(tenkan_values, true);

        for (int i = 1; i < settings.pivot_lookback - 1; i++)
        {
            if (is_buy && tenkan_values[i] < tenkan_values[i - 1] && tenkan_values[i] < tenkan_values[i + 1])
                return tenkan_values[i]; // پیوت کف برای خرید
            if (!is_buy && tenkan_values[i] > tenkan_values[i - 1] && tenkan_values[i] > tenkan_values[i + 1])
                return tenkan_values[i]; // پیوت سقف برای فروش
        }

        return 0.0; // هیچ پیوتی پیدا نشد
    }
};

//+------------------------------------------------------------------+
//| کلاس مدیریت استراتژی برای یک نماد خاص (CStrategyManager)          |
//| این کلاس به عنوان کنترلر عمل می‌کند و رویدادها را دیسپچ می‌کند.    |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string                  m_symbol;                // نماد معاملاتی جاری
    SSettings               m_settings;              // کپی تنظیمات ورودی برای دسترسی محلی
    CTrade                  m_trade;                 // شیء ترید برای باز کردن معاملات
    CVisualManager*         m_visual_manager;        // مدیر گرافیک برای رسم اشیاء
    
    // کامنت: خزانه داده و پردازشگر سیگنال
    CContext                m_context;               // خزانه داده مرکزی (تنها منبع حقیقت)
    CSignalProcessor        m_processor;             // پردازشگر منطقی سیگنال (stateless)
    
    // کامنت: تحلیلگرهای ساختار بازار
    CMarketStructureShift   m_htf_analyzer;          // تحلیلگر ساختار در تایم فریم اصلی (HTF)
    CMarketStructureShift   m_ltf_analyzer;          // تحلیلگر ساختار در تایم فریم تاییدیه (LTF)
    CMarketStructureShift   m_grace_structure_analyzer; // تحلیلگر برای مهلت ساختاری
    
    // کامنت: مدیریت زمان‌بندی کندل‌ها
    datetime                m_last_bar_time_htf;     // زمان آخرین کندل پردازش شده در HTF
    datetime                m_last_bar_time_ltf;     // زمان آخرین کندل پردازش شده در LTF
    
    // کامنت: هندل‌های اندیکاتور برای HTF
    int                     m_ichimoku_handle_htf;   // هندل ایچیموکو در HTF
    int                     m_atr_handle_htf;        // هندل ATR در HTF
    int                     m_adx_handle_htf;        // هندل ADX در HTF
    int                     m_rsi_exit_handle_htf;   // هندل RSI برای خروج در HTF
    
    // کامنت: هندل‌های اندیکاتور برای LTF (اگر context_timeframe متفاوت باشد)
    int                     m_ichimoku_handle_ltf;   // هندل ایچیموکو در LTF
    int                     m_atr_handle_ltf;        // هندل ATR در LTF
    int                     m_adx_handle_ltf;        // هندل ADX در LTF
    int                     m_rsi_exit_handle_ltf;   // هندل RSI برای خروج در LTF

    // توابع کمکی خصوصی
    void Log(string message);                        // تابع لاگینگ پیام‌ها اگر فعال باشد
    bool IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time); // چک تشکیل کندل جدید
    bool IsDataReady();                              // چک آماده بودن داده‌ها برای تحلیل
    int CountSymbolTrades();                         // شمارش معاملات باز برای نماد جاری
    int CountTotalTrades();                          // شمارش کل معاملات باز
    void OpenTrade(bool is_buy, double sl);          // باز کردن معامله با مدیریت سرمایه
    void CheckForEarlyExit();                        // بررسی خروج زودرس معاملات باز
    bool CheckChikouRsiExit(bool is_buy);            // منطق خروج با چیکو و RSI

public:
    CStrategyManager(string symbol, SSettings &settings); // کانستراکتور کلاس
    ~CStrategyManager();                             // دیستراکتور برای پاکسازی منابع
    bool Init();                                     // مقداردهی اولیه کلاس و اعضای آن
    void OnTimerTick();                              // تابع اصلی دیسپچر رویدادها (هر ثانیه)
    string GetSymbol() const { return m_symbol; }    // برگرداندن نماد جاری
    void UpdateMyDashboard();                        // آپدیت داشبورد گرافیکی
    CVisualManager* GetVisualManager() { return m_visual_manager; } // دسترسی به مدیر گرافیک
};

//+------------------------------------------------------------------+
//| کانستراکتور کلاس CStrategyManager - مقداردهی اولیه اعضای اولیه    |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;                           // ذخیره نماد
    m_settings = settings;                       // کپی تنظیمات
    m_last_bar_time_htf = 0;                     // ریست زمان HTF
    m_last_bar_time_ltf = 0;                     // ریست زمان LTF
    m_ichimoku_handle_htf = INVALID_HANDLE;      // هندل‌های HTF را نامعتبر تنظیم کن
    m_atr_handle_htf = INVALID_HANDLE;
    m_adx_handle_htf = INVALID_HANDLE;
    m_rsi_exit_handle_htf = INVALID_HANDLE;
    m_ichimoku_handle_ltf = INVALID_HANDLE;      // هندل‌های LTF را نامعتبر تنظیم کن
    m_atr_handle_ltf = INVALID_HANDLE;
    m_adx_handle_ltf = INVALID_HANDLE;
    m_rsi_exit_handle_ltf = INVALID_HANDLE;
    m_visual_manager = new CVisualManager(m_symbol, m_settings); // ایجاد مدیر گرافیک
}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس CStrategyManager - پاکسازی منابع                  |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
    // کامنت: پاک کردن مدیر گرافیک
    if (m_visual_manager != NULL)
    {
        delete m_visual_manager;
        m_visual_manager = NULL;
    }

    // کامنت: آزاد کردن هندل‌های اندیکاتور HTF
    if(m_ichimoku_handle_htf != INVALID_HANDLE) IndicatorRelease(m_ichimoku_handle_htf);
    if(m_atr_handle_htf != INVALID_HANDLE) IndicatorRelease(m_atr_handle_htf);
    if(m_adx_handle_htf != INVALID_HANDLE) IndicatorRelease(m_adx_handle_htf);
    if(m_rsi_exit_handle_htf != INVALID_HANDLE) IndicatorRelease(m_rsi_exit_handle_htf);

    // کامنت: آزاد کردن هندل‌های اندیکاتور LTF
    if(m_ichimoku_handle_ltf != INVALID_HANDLE) IndicatorRelease(m_ichimoku_handle_ltf);
    if(m_atr_handle_ltf != INVALID_HANDLE) IndicatorRelease(m_atr_handle_ltf);
    if(m_adx_handle_ltf != INVALID_HANDLE) IndicatorRelease(m_adx_handle_ltf);
    if(m_rsi_exit_handle_ltf != INVALID_HANDLE) IndicatorRelease(m_rsi_exit_handle_ltf);
}

//+------------------------------------------------------------------+
//| تابع Init کلاس CStrategyManager - مقداردهی اولیه تمام اعضای کلاس   |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    // کامنت: تنظیمات اولیه شیء ترید
    m_trade.SetExpertMagicNumber(m_settings.magic_number);
    m_trade.SetTypeFillingBySymbol(m_symbol);
    
    // کامنت: ایجاد هندل‌های اندیکاتور برای HTF (حالت نامرئی)
    MqlParam ichimoku_params[3];
    ichimoku_params[0].type = TYPE_INT; ichimoku_params[0].integer_value = m_settings.tenkan_period;
    ichimoku_params[1].type = TYPE_INT; ichimoku_params[1].integer_value = m_settings.kijun_period;
    ichimoku_params[2].type = TYPE_INT; ichimoku_params[2].integer_value = m_settings.senkou_period;
    m_ichimoku_handle_htf = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ICHIMOKU, 3, ichimoku_params);
    
    MqlParam atr_params[1];
    atr_params[0].type = TYPE_INT; atr_params[0].integer_value = m_settings.atr_filter_period;
    m_atr_handle_htf = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ATR, 1, atr_params);

    MqlParam adx_params[1];
    adx_params[0].type = TYPE_INT; adx_params[0].integer_value = m_settings.adx_period;
    m_adx_handle_htf = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ADX, 1, adx_params);

    MqlParam rsi_params[2];
    rsi_params[0].type = TYPE_INT; rsi_params[0].integer_value = m_settings.early_exit_rsi_period;
    rsi_params[1].type = TYPE_INT; rsi_params[1].integer_value = PRICE_CLOSE;
    m_rsi_exit_handle_htf = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_RSI, 2, rsi_params);
    
    // کامنت: چک اعتبار هندل‌های HTF
    if (m_ichimoku_handle_htf == INVALID_HANDLE || m_atr_handle_htf == INVALID_HANDLE || m_adx_handle_htf == INVALID_HANDLE || m_rsi_exit_handle_htf == INVALID_HANDLE)
    {
        Log("خطا در ایجاد اندیکاتورهای HTF.");
        return false;
    }

    // کامنت: ایجاد هندل‌های اندیکاتور برای LTF (همیشه، برای حداکثر انعطاف‌پذیری)
    MqlParam ichi_params_ltf[3];
    ichi_params_ltf[0].type = TYPE_INT; ichi_params_ltf[0].integer_value = m_settings.tenkan_period;
    ichi_params_ltf[1].type = TYPE_INT; ichi_params_ltf[1].integer_value = m_settings.kijun_period;
    ichi_params_ltf[2].type = TYPE_INT; ichi_params_ltf[2].integer_value = m_settings.senkou_period;
    m_ichimoku_handle_ltf = IndicatorCreate(m_symbol, m_settings.ltf_timeframe, IND_ICHIMOKU, 3, ichi_params_ltf);
    
    MqlParam atr_params_ltf[1];
    atr_params_ltf[0].type = TYPE_INT; atr_params_ltf[0].integer_value = m_settings.atr_filter_period;
    m_atr_handle_ltf = IndicatorCreate(m_symbol, m_settings.ltf_timeframe, IND_ATR, 1, atr_params_ltf);

    MqlParam adx_params_ltf[1];
    adx_params_ltf[0].type = TYPE_INT; adx_params_ltf[0].integer_value = m_settings.adx_period;
    m_adx_handle_ltf = IndicatorCreate(m_symbol, m_settings.ltf_timeframe, IND_ADX, 1, adx_params_ltf);

    MqlParam rsi_params_ltf[2];
    rsi_params_ltf[0].type = TYPE_INT; rsi_params_ltf[0].integer_value = m_settings.early_exit_rsi_period;
    rsi_params_ltf[1].type = TYPE_INT; rsi_params_ltf[1].integer_value = PRICE_CLOSE;
    m_rsi_exit_handle_ltf = IndicatorCreate(m_symbol, m_settings.ltf_timeframe, IND_RSI, 2, rsi_params_ltf);
    
    // کامنت: چک اعتبار هندل‌های LTF (همیشه)
    if (m_ichimoku_handle_ltf == INVALID_HANDLE || m_atr_handle_ltf == INVALID_HANDLE || m_adx_handle_ltf == INVALID_HANDLE || m_rsi_exit_handle_ltf == INVALID_HANDLE)
    {
        Log("خطا در ایجاد اندیکاتورهای LTF.");
        return false;
    }

    // کامنت: مقداردهی اولیه خزانه داده با تنظیمات
    m_context.Init(m_settings);

    // کامنت: مقداردهی اولیه تحلیلگرهای ساختار بازار
    m_htf_analyzer.Init(m_symbol, m_settings.ichimoku_timeframe);
    m_ltf_analyzer.Init(m_symbol, m_settings.ltf_timeframe);
    m_grace_structure_analyzer.Init(m_symbol, m_settings.ichimoku_timeframe); // برای مهلت ساختاری

    // کامنت: مقداردهی اولیه مدیر گرافیک
    if (!m_visual_manager.Init())
    {
        Log("خطا در مقداردهی اولیه VisualManager.");
        return false;
    }

    if(m_symbol == _Symbol)
    {
        m_visual_manager.InitDashboard();
    }
    
    Log("با موفقیت مقداردهی اولیه شد.");
    return true;
}

//+------------------------------------------------------------------+
//| تابع OnTimerTick: دیسپچر اصلی رویدادها - هر ثانیه اجرا می‌شود     |
//| این تابع منطق اصلی استراتژی را مدیریت می‌کند.                   |
//+------------------------------------------------------------------+
void CStrategyManager::OnTimerTick()
{
    // کامنت: اگر داده آماده نباشد، از تابع خارج شو
    if (!IsDataReady()) return;

    // کامنت: اگر خروج زودرس فعال باشد، پوزیشن‌ها را چک کن
    if(m_settings.enable_early_exit)
    {
        CheckForEarlyExit();
    }

    // کامنت: پاکسازی اشیاء گرافیکی قدیمی اگر نماد جاری باشد
    if(m_symbol == _Symbol && m_visual_manager != NULL)
    {
        m_visual_manager.CleanupOldObjects(200);
    }

    // کامنت: بخش ۱ - شکار سیگنال اولیه در HTF (اگر کندل جدید تشکیل شده باشد)
    if (IsNewBar(m_settings.ichimoku_timeframe, m_last_bar_time_htf))
    {
        bool is_buy = false;
        // کامنت: استفاده از پردازشگر برای چک کراس سه‌گانه
        if (m_processor.CheckTripleCross(m_settings, m_symbol, m_settings.ichimoku_timeframe, is_buy, m_ichimoku_handle_htf))
        {
            // کامنت: ایجاد سیگنال جدید و پر کردن فیلدها
            SPotentialSignal new_signal;
            new_signal.time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period);
            new_signal.is_buy = is_buy;
            new_signal.grace_candle_count = 0;
            new_signal.invalidation_level = 0.0;

            // کامنت: اگر مهلت ساختاری باشد، سطح ابطال را محاسبه کن
            if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE)
            {
                m_grace_structure_analyzer.ProcessNewBar();
                new_signal.invalidation_level = is_buy ? m_grace_structure_analyzer.GetLastSwingLow() : m_grace_structure_analyzer.GetLastSwingHigh();
                Log("سطح ابطال برای سیگنال " + (is_buy ? "خرید" : "فروش") + ": " + DoubleToString(new_signal.invalidation_level, _Digits));
            }
            
            // کامنت: اگر حالت REPLACE_SIGNAL فعال باشد، سیگنال‌های INITIAL قبلی را پاک کن
            if(m_settings.signal_mode == MODE_REPLACE_SIGNAL)
            {
                m_context.ClearInitialSignals();
                Log("تمام سیگنال‌های INITIAL قبلی پاک شدند (MODE_REPLACE_SIGNAL).");
            }
            
            // کامنت: اضافه کردن سیگنال به خزانه داده
            m_context.AddSignal(new_signal);
            Log("سیگنال اولیه " + (new_signal.is_buy ? "خرید" : "فروش") + " پیدا شد و به خزانه اضافه شد.");

            // کامنت: رسم مستطیل کراس روی چارت اگر نماد جاری باشد
            if(m_symbol == _Symbol && m_visual_manager != NULL) 
                m_visual_manager.DrawTripleCrossRectangle(is_buy, m_settings.chikou_period);
        }
    }

    // کامنت: بخش ۲ - پردازش تاییدیه و ابطال در LTF (اگر کندل جدید تشکیل شده باشد)
    if (IsNewBar(m_settings.ltf_timeframe, m_last_bar_time_ltf))
    {
        // کامنت: گرفتن سیگنال‌های INITIAL از خزانه
        SPotentialSignal initial_signals[];
        m_context.GetInitialSignals(initial_signals);

        // کامنت: پردازش هر سیگنال INITIAL
        for (int i = 0; i < ArraySize(initial_signals); i++)
        {
            SPotentialSignal signal = initial_signals[i]; // کپی سیگنال برای آپدیت
            
            // کامنت: بررسی ابطال سیگنال قبل از چک تاییدیه
            bool is_signal_expired = false;

            // کامنت: حالت ابطال بر اساس تعداد کندل
            if (m_settings.grace_period_mode == GRACE_BY_CANDLES)
            {
                if (signal.grace_candle_count >= m_settings.grace_period_candles)
                {
                    is_signal_expired = true;
                    Log("سیگنال ID " + (string)signal.id + " به دلیل اتمام مهلت کندلی منقضی شد.");
                }
                else
                {
                    // کامنت: افزایش شمارنده برای کندل جدید
                    signal.grace_candle_count++;
                    // آپدیت سیگنال در خزانه
                    m_context.UpdateSignalState(signal.id, signal.state); // به‌روزرسانی برای اطمینان
                }
            }
            // کامنت: حالت ابطال بر اساس شکست ساختار
            else // GRACE_BY_STRUCTURE
            {
                const double current_price = iClose(m_symbol, m_settings.ltf_timeframe, 1);
                if (signal.invalidation_level > 0 &&
                    ((signal.is_buy && current_price < signal.invalidation_level) ||
                     (!signal.is_buy && current_price > signal.invalidation_level)))
                {
                    is_signal_expired = true;
                    Log("سیگنال ID " + (string)signal.id + " به دلیل شکست سطح ابطال ساختاری منقضی شد.");
                }
            }

            // کامنت: اگر سیگنال منقضی شده بود، وضعیتش را آپدیت کن و به سراغ سیگنال بعدی برو
            if (is_signal_expired)
            {
                m_context.UpdateSignalState(signal.id, EXPIRED);
                continue;
            }

            // کامنت: چک تاییدیه برای سیگنال
            bool is_confirmed = m_processor.CheckConfirmation(m_settings, m_symbol, m_settings.ltf_timeframe, signal.is_buy, m_ltf_analyzer);
            if (is_confirmed)
            {
                m_context.UpdateSignalState(signal.id, CONFIRMED);
                Log("سیگنال ID " + (string)signal.id + " تایید شد و وضعیت به CONFIRMED تغییر کرد.");
            }

            // کامنت: رسم ناحیه اسکن اگر نماد جاری باشد
            if(m_symbol == _Symbol && m_visual_manager != NULL) 
                m_visual_manager.DrawScanningArea(signal.is_buy, m_settings.chikou_period, signal.grace_candle_count);
        }
    }

    // کامنت: بخش ۳ - اجرای معاملات برای سیگنال‌های CONFIRMED
    SPotentialSignal confirmed_signals[];
    m_context.GetConfirmedSignals(confirmed_signals);

    if (ArraySize(confirmed_signals) > 0)
    {
        // کامنت: انتخاب تایم فریم محاسبات بر اساس تنظیمات
        const ENUM_TIMEFRAMES context_tf = (m_settings.context_timeframe == CTX_TIMEFRAME_MAIN) ? m_settings.ichimoku_timeframe : m_settings.ltf_timeframe;
        
        // کامنت: انتخاب هندل‌های مناسب بر اساس تایم فریم
        const int ichi_handle = (context_tf == m_settings.ichimoku_timeframe) ? m_ichimoku_handle_htf : m_ichimoku_handle_ltf;
        const int atr_handle = (context_tf == m_settings.ichimoku_timeframe) ? m_atr_handle_htf : m_atr_handle_ltf;
        const int adx_handle = (context_tf == m_settings.ichimoku_timeframe) ? m_adx_handle_htf : m_adx_handle_ltf;
        
        for (int i = 0; i < ArraySize(confirmed_signals); i++)
        {
            const SPotentialSignal signal = confirmed_signals[i];
            
            // کامنت: چک تمام فیلترها با تایم فریم انتخابی
            bool filters_passed = m_processor.AreAllFiltersPassed(m_settings, m_symbol, context_tf, signal.is_buy, ichi_handle, atr_handle, adx_handle);
            if (filters_passed)
            {
                // کامنت: محاسبه قیمت ورود و استاپ لاس
                const double entry_price = signal.is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
                const double sl = m_processor.CalculateStopLoss(m_settings, m_symbol, context_tf, signal.is_buy, entry_price, ichi_handle, atr_handle);
                
                if (sl > 0)
                {
                    // کامنت: باز کردن معامله
                    OpenTrade(signal.is_buy, sl);
                    
                    // کامنت: آپدیت وضعیت سیگنال به EXECUTED
                    m_context.UpdateSignalState(signal.id, EXECUTED);
                    
                    // کامنت: رسم فلش تاییدیه روی چارت اگر نماد جاری باشد
                    if(m_symbol == _Symbol && m_visual_manager != NULL) 
                        m_visual_manager.DrawConfirmationArrow(signal.is_buy, 1);
                    
                    Log("معامله بر اساس سیگنال ID " + (string)signal.id + " با موفقیت باز شد.");
                }
            }
            else
            {
                // کامنت: اگر فیلترها رد شد، وضعیت به INVALIDATED تغییر کند
                m_context.UpdateSignalState(signal.id, INVALIDATED);
                Log("سیگنال ID " + (string)signal.id + " توسط فیلترها رد شد.");
            }
        }
    }

    // کامنت: بخش ۴ - پاکسازی دوره‌ای خزانه داده از سیگنال‌های نامعتبر
    m_context.Cleanup();
}

//+------------------------------------------------------------------+
//| تابع Log: لاگینگ پیام اگر لاگینگ فعال باشد                       |
//+------------------------------------------------------------------+
void CStrategyManager::Log(string message)
{
    if (m_settings.enable_logging)
    {
        Print(m_symbol, ": ", message); // چاپ پیام با پیشوند نماد
    }
}

//+------------------------------------------------------------------+
//| تابع IsNewBar: چک تشکیل کندل جدید در تایم فریم داده شده           |
//+------------------------------------------------------------------+
bool CStrategyManager::IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time)
{
    datetime current_bar_time = iTime(m_symbol, timeframe, 0); // گرفتن زمان کندل فعلی
    if (current_bar_time != last_bar_time) // اگر با آخرین زمان متفاوت بود
    {
        last_bar_time = current_bar_time; // آپدیت آخرین زمان
        return true; // کندل جدید تشکیل شده
    }
    return false; // کندل جدید نیست
}

//+------------------------------------------------------------------+
//| تابع IsDataReady: چک آماده بودن داده‌ها برای تحلیل                |
//+------------------------------------------------------------------+
bool CStrategyManager::IsDataReady()
{
    // کامنت: چک آماده بودن HTF
    if(iBars(m_symbol, m_settings.ichimoku_timeframe) < 200 || iTime(m_symbol, m_settings.ichimoku_timeframe, 1) == 0)
        return false;
    
    // کامنت: چک آماده بودن LTF
    if(iBars(m_symbol, m_settings.ltf_timeframe) < 200 || iTime(m_symbol, m_settings.ltf_timeframe, 1) == 0)
        return false;
    
    // کامنت: چک آماده بودن چارت فعلی
    if(iBars(m_symbol, PERIOD_CURRENT) < 200 || iTime(m_symbol, PERIOD_CURRENT, 1) == 0)
        return false;
    
    return true; // تمام داده‌ها آماده است
}

//+------------------------------------------------------------------+
//| تابع CountSymbolTrades: شمارش معاملات باز برای نماد جاری          |
//+------------------------------------------------------------------+
int CStrategyManager::CountSymbolTrades()
{
    int count = 0; // شمارنده اولیه
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه از آخر به اول روی پوزیشن‌ها
    {
        if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            count++; // افزایش شمارنده اگر پوزیشن مربوط به این نماد و مجیک باشد
        }
    }
    return count; // برگرداندن تعداد
}

//+------------------------------------------------------------------+
//| تابع CountTotalTrades: شمارش کل معاملات باز                        |
//+------------------------------------------------------------------+
int CStrategyManager::CountTotalTrades()
{
    int count = 0; // شمارنده اولیه
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه از آخر به اول روی پوزیشن‌ها
    {
        if(PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            count++; // افزایش شمارنده اگر پوزیشن مربوط به مجیک باشد
        }
    }
    return count; // برگرداندن تعداد
}

//+------------------------------------------------------------------+
//| تابع OpenTrade: باز کردن معامله با مدیریت سرمایه                   |
//+------------------------------------------------------------------+
void CStrategyManager::OpenTrade(bool is_buy, double sl)
{
    // کامنت: چک حد مجاز معاملات
    if(CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol)
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد.");
        return;
    }

    // کامنت: محاسبه قیمت ورود
    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
    
    // کامنت: اگر استاپ لاس صفر بود، خارج شو
    if(sl == 0)
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد.");
        return;
    }
    
    // کامنت: محاسبه ریسک بر اساس موجودی حساب
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0);

    // کامنت: محاسبه ضرر برای یک لات
    double loss_for_one_lot = 0;
    if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, entry_price, sl, loss_for_one_lot))
    {
        Log("خطا در محاسبه سود/زیان با OrderCalcProfit.");
        return;
    }
    loss_for_one_lot = MathAbs(loss_for_one_lot);

    // کامنت: اگر ضرر یک لات معتبر نبود، خارج شو
    if(loss_for_one_lot <= 0)
    {
        Log("میزان ضرر محاسبه شده برای ۱ لات معتبر نیست.");
        return;
    }

    // کامنت: محاسبه حجم لات بر اساس ریسک
    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2);

    // کامنت: گرفتن محدودیت‌های حجم از نماد
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    // کامنت: تنظیم حجم در محدوده مجاز
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    
    // کامنت: گرد کردن حجم بر اساس گام بروکر
    lot_size = MathRound(lot_size / lot_step) * lot_step;

    // کامنت: اگر حجم کمتر از حداقل بود، خارج شو
    if(lot_size < min_lot)
    {
        Log("حجم محاسبه شده کمتر از حداقل لات مجاز است.");
        return;
    }

    // کامنت: محاسبه فاصله استاپ لاس و تیک پروفیت
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(entry_price - sl) / point;
    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio;
    double tp = is_buy ? entry_price + tp_distance_points * point : entry_price - tp_distance_points * point;
    
    // کامنت: نرمال‌سازی استاپ لاس و تیک پروفیت
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    // کامنت: ساخت کامنت معامله
    string comment = "Memento " + (is_buy ? "Buy" : "Sell");
    
    // کامنت: ارسال دستور خرید یا فروش
    if(is_buy)
    {
        m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment);
    }
    else
    {
        m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment);
    }
    
    // کامنت: چک نتیجه ترید
    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
    {
        Log("معامله " + comment + " با لات " + DoubleToString(lot_size, 2) + " با موفقیت باز شد.");
    }
    else
    {
        Log("خطا در باز کردن معامله " + comment + ": " + (string)m_trade.ResultRetcode() + " - " + m_trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| تابع CheckForEarlyExit: بررسی خروج زودرس تمام پوزیشن‌های باز     |
//+------------------------------------------------------------------+
void CStrategyManager::CheckForEarlyExit()
{
    // کامنت: انتخاب هندل RSI و ایچیموکو بر اساس context_timeframe
    const int rsi_handle = (m_settings.context_timeframe == CTX_TIMEFRAME_MAIN) ? m_rsi_exit_handle_htf : m_rsi_exit_handle_ltf;
    const int ichimoku_handle = (m_settings.context_timeframe == CTX_TIMEFRAME_MAIN) ? m_ichimoku_handle_htf : m_ichimoku_handle_ltf;

    // کامنت: حلقه از آخر به اول روی پوزیشن‌ها برای جلوگیری از مشکلات ایندکس
    for (int i = PositionsTotal() - 1; i >= 0; i--) 
    {
        ulong ticket = PositionGetTicket(i); // گرفتن تیکت پوزیشن
        // کامنت: چک نماد و مجیک برای مطابقت با اکسپرت
        if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            if (PositionSelectByTicket(ticket)) // انتخاب پوزیشن
            {
                const bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY); // تعیین جهت پوزیشن
                if (CheckChikouRsiExit(is_buy)) // چک شرط خروج
                { 
                    Log("🚨 سیگنال خروج زودرس برای تیکت " + (string)ticket + " صادر شد. بستن معامله...");
                    m_trade.PositionClose(ticket); // بستن پوزیشن
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| تابع CheckChikouRsiExit: منطق خروج با چیکو و RSI                  |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckChikouRsiExit(bool is_buy)
{
    // کامنت: گرفتن قیمت چیکو (کلوز کندل قبلی)
    const double chikou_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
    
    // کامنت: کپی بافرهای تنکان، کیجون و RSI
    double tenkan_buffer[1], kijun_buffer[1], rsi_buffer[1];
    if(CopyBuffer(m_ichimoku_handle_htf, 0, 1, 1, tenkan_buffer) < 1 ||
       CopyBuffer(m_ichimoku_handle_htf, 1, 1, 1, kijun_buffer) < 1 ||
       CopyBuffer(m_rsi_exit_handle_htf, 0, 1, 1, rsi_buffer) < 1)
    {
        return false; // داده کافی نیست
    }
    
    const double tenkan = tenkan_buffer[0];
    const double kijun = kijun_buffer[0];
    const double rsi = rsi_buffer[0];
    
    bool chikou_cross_confirms_exit = false;
    bool rsi_confirms_exit = false;

    if (is_buy) // برای معامله خرید
    {
        chikou_cross_confirms_exit = (chikou_price < MathMin(tenkan, kijun)); // چیکو زیر خطوط
        rsi_confirms_exit = (rsi < m_settings.early_exit_rsi_oversold); // RSI زیر سطح اشباع فروش
    }
    else // برای معامله فروش
    {
        chikou_cross_confirms_exit = (chikou_price > MathMax(tenkan, kijun)); // چیکو بالای خطوط
        rsi_confirms_exit = (rsi > m_settings.early_exit_rsi_overbought); // RSI بالای سطح اشباع خرید
    }
    
    return (chikou_cross_confirms_exit && rsi_confirms_exit); // هر دو شرط برقرار باشد
}

//+------------------------------------------------------------------+
//| تابع UpdateMyDashboard: آپدیت داشبورد گرافیکی                     |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateMyDashboard() 
{ 
    if (m_visual_manager != NULL)
    {
        m_visual_manager.UpdateDashboard(); // فراخوانی تابع آپدیت داشبورد از مدیر گرافیک
    }
}
