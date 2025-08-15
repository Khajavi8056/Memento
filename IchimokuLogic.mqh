//+------------------------------------------------------------------+
//| (نسخه نهایی با منطق انتخاب بهینه) محاسبه استاپ لاس               |
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

    // یک تابع کمکی کوچک برای اضافه کردن کاندیداهای معتبر به لیست
    auto AddCandidate = [&](double sl_price) {
        if (sl_price > 0) {
            ArrayResize(candidates, count + 1);
            candidates[count] = sl_price;
            count++;
        }
    };

    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    
    // کاندیداهای مبتنی بر ایچیموکو (که بافر نیاز دارند)
    double flat_kijun = FindFlatKijun();
    if (flat_kijun > 0) AddCandidate(is_buy ? flat_kijun - buffer : flat_kijun + buffer);

    double pivot_kijun = FindPivotKijun(is_buy);
    if (pivot_kijun > 0) AddCandidate(is_buy ? pivot_kijun - buffer : pivot_kijun + buffer);

    double pivot_tenkan = FindPivotTenkan(is_buy);
    if (pivot_tenkan > 0) AddCandidate(is_buy ? pivot_tenkan - buffer : pivot_tenkan + buffer);

    // کاندیداهای دیگر (که بافر داخلی خود را دارند یا نیازی ندارند)
    AddCandidate(FindBackupStopLoss(is_buy, buffer));
    AddCandidate(CalculateAtrStopLoss(is_buy, entry_price));
    
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
    // حداقل فاصله امن = اسپرد + بافر ورودی کاربر
    double min_safe_distance = spread + buffer; 

    for (int i = 0; i < count; i++)
    {
        double current_sl = candidates[i];
        
        // فیلتر منطقی: آیا استاپ در سمت درست قیمت قرار دارد؟
        if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price))
        {
            continue; // این کاندیدا غیرمنطقی است، نادیده بگیر
        }

        // فیلتر حداقل فضا (نسخه اصلاحی): به جای حذف، فاصله را تنظیم کن
        if (MathAbs(entry_price - current_sl) < min_safe_distance)
        {
            current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance;
            Log("کاندیدای شماره " + (string)(i+1) + " به دلیل نزدیکی بیش از حد به قیمت " + DoubleToString(current_sl, _Digits) + " اصلاح شد.");
        }

        // کاندیدای معتبر و اصلاح شده را به لیست نهایی اضافه کن
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
    double smallest_distance = DBL_MAX; // استفاده از بزرگترین عدد ممکن برای شروع مقایسه

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

    // مرحله ۴ (کنترل نهایی ریسک) طبق توافق حذف شد و سیستم به این نتیجه اعتماد می‌کند.
    return best_sl_price;
}

