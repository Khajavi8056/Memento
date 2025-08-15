//+------------------------------------------------------------------+
//| (نسخه نهایی با منطق انتخاب بهینه - کاملاً سازگار) محاسبه استاپ لاس |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price)
{
    // اگر کاربر روش ساده یا ATR را انتخاب کرده بود، همان را اجرا کن (بدون تغییر)
    if (m_settings.stoploss_type == MODE_SIMPLE)
    {
        double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        return FindBackupStopLoss(is_buy, buffer);
    }
    if (m_settings.stoploss_type == MODE_ATR)
    {
        double sl_price = CalculateAtrStopLoss(is_buy, entry_price);
        if (sl_price == 0) // اگر ATR به هر دلیلی جواب نداد
        {
            Log("محاسبه ATR SL با خطا مواجه شد. استفاده از روش پشتیبان...");
            double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            return FindBackupStopLoss(is_buy, buffer);
        }
        return sl_price;
    }

    // --- قلب تپنده منطق جدید: انتخاب بهینه (برای MODE_COMPLEX) ---

    Log("شروع فرآیند انتخاب استاپ لاس بهینه...");

    // --- مرحله ۱: تشکیل لیست کاندیداها ---
    double candidates[];
    int count = 0;
    double sl_candidate = 0; // متغیر کمکی برای نگهداری نتیجه هر تابع
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    // کاندیدای ۱: کیجون فلت
    sl_candidate = FindFlatKijun();
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1);
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
        count++;
    }
    
    // کاندیدای ۲: پیوت کیجون
    sl_candidate = FindPivotKijun(is_buy);
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1);
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
        count++;
    }

    // کاندیدای ۳: پیوت تنکان
    sl_candidate = FindPivotTenkan(is_buy);
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1);
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer;
        count++;
    }

    // کاندیدای ۴: روش ساده (کندل مخالف)
    sl_candidate = FindBackupStopLoss(is_buy, buffer);
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1);
        candidates[count] = sl_candidate;
        count++;
    }
    
    // کاندیدای ۵: روش ATR
    sl_candidate = CalculateAtrStopLoss(is_buy, entry_price);
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1);
        candidates[count] = sl_candidate;
        count++;
    }

    if (count == 0)
    {
        Log("خطا: هیچ کاندیدای اولیه‌ای برای استاپ لاس پیدا نشد.");
        return 0.0;
    }

    // --- مرحله ۲: اعتبارسنجی و بهینه‌سازی کاندیداها ---
    double valid_candidates[];
    int valid_count = 0;
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * point;
    double min_safe_distance = spread + buffer; 

    for (int i = 0; i < count; i++)
    {
        double current_sl = candidates[i];
        
        if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price))
        {
            continue; 
        }

        if (MathAbs(entry_price - current_sl) < min_safe_distance)
        {
            current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance;
            Log("کاندیدای شماره " + (string)(i+1) + " به دلیل نزدیکی بیش از حد به قیمت " + DoubleToString(current_sl, _Digits) + " اصلاح شد.");
        }

        ArrayResize(valid_candidates, valid_count + 1);
        valid_candidates[valid_count] = current_sl;
        valid_count++;
    }

    if (valid_count == 0)
    {
        Log("خطا: پس از فیلترینگ، هیچ کاندیدای معتبری برای استاپ لاس باقی نماند.");
        return 0.0;
    }
    
    // --- مرحله ۳: انتخاب نزدیک‌ترین گزینه معتبر ---
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

    Log("✅ استاپ لاس بهینه پیدا شد: " + DoubleToString(best_sl_price, _Digits) + ". فاصله: " + DoubleToString(smallest_distance / point, 1) + " پوینت.");

    return best_sl_price;
}
