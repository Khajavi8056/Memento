//+------------------------------------------------------------------+
//|                                      Universal Telegram Library  |
//|                                      File: TelegramManager.mqh    |
//|                                      Version: 3.0 (Standalone)   |
//|                                      © 2025, Mohammad & Gemini   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "3.0"
#include <Trade\Trade.mqh>
#include <Graphics\Graphic.mqh>

//================================================================================//
//|                                 --- راهنمای استفاده سریع ---                   |
//|                                                                                |
//| ۱. این فایل را در کنار فایل اکسپرت خود قرار دهید.                                |
//| ۲. در فایل اکسپرت اصلی (.mq5)، فقط این دو خط را به بالای فایل اضافه کنید:          |
//|    #include "TelegramManager.mqh"                                              |
//|    CTelegramManager Telegram;                                                  |
//| ۳. در انتهای تابع OnTimer (یا OnTick) اکسپرت خود، این خط را اضافه کنید:          |
//|    Telegram.Process();                                                         |
//|                                                                                |
//|       ** تمام تنظیمات ورودی تلگرام در این فایل قرار دارد.                       |
//|          فقط کافی است در اکسپرت اصلی از این کتابخانه استفاده کنید.             |
//|                                                                                |
//================================================================================//

//================================================================//
// بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play
//================================================================//
input group "---=== 📧 Universal Telegram Notifier 📧 ===---";
input bool   Inp_Telegram_Enable = false;  // ✅ فعال/غیرفعال کردن ارسال پیام به تلگرام
input string Inp_Telegram_Token  = "";     // توکن ربات تلگرام
input string Inp_Telegram_ChatID = "";     // آیدی چت یا کانال تلگرام


//+------------------------------------------------------------------+
//| ساختار برای ذخیره وضعیت معاملات                                   |
//+------------------------------------------------------------------+
struct STradeAlertState
{
    ulong ticket;
    bool  is_sent;
};

//+------------------------------------------------------------------+
//| کلاس مدیریت تلگرام                                               |
//+------------------------------------------------------------------+
class CTelegramManager
{
private:
    bool     m_enabled;
    string   m_token;
    string   m_chat_id;
    long     m_magic_number;
    bool     m_is_initialized;
    STradeAlertState m_trade_states[];
    
    // ✅ تعریف ورودی magic_number به صورت extern
    extern input int Inp_Magic_Number;

    // تابع کمکی برای لاگ کردن
    void Log(string message)
    {
        if (m_enabled)
        {
            Print("Telegram Manager: ", message);
        }
    }
    
    // تابع اصلی برای ارسال درخواست WebRequest
    int SendWebRequest(string endpoint, string params)
    {
        if (!m_enabled || m_token == "" || m_chat_id == "") return -1;
        
        string url = "https://api.telegram.org/bot" + m_token + "/" + endpoint;
        
        char data[];
        StringToCharArray(params, data, 0, WHOLE_ARRAY, CP_UTF8);
        
        string headers = "Content-Type: application/x-www-form-urlencoded";
        
        char result_data[];
        string result_headers;
        
        int timeout = 5000;
        
        int result = WebRequest("POST", url, headers, timeout, data, result_data, result_headers);
        
        if(result == -1)
        {
            Log("خطا در ارسال پیام به تلگرام. کد خطا: " + (string)GetLastError());
        }
        else
        {
            string s_result_data = CharArrayToString(result_data);
            if (StringFind(s_result_data, "\"ok\":false") != -1)
            {
                Log("خطا در پاسخ سرور تلگرام: " + s_result_data);
            }
            else
            {
                Log("پیام با موفقیت ارسال شد.");
            }
        }
        return result;
    }
    
    // تابع مقداردهی اولیه (فراخوانی خودکار)
    void Init()
    {
        if(m_is_initialized) return;
        
        m_enabled = Inp_Telegram_Enable;
        m_token = Inp_Telegram_Token;
        m_chat_id = Inp_Telegram_ChatID;
        m_magic_number = Inp_Magic_Number;
        
        if (m_enabled && m_token != "" && m_chat_id != "")
        {
            Log("با موفقیت راه‌اندازی شد. آماده برای ارسال پیام.");
        }
        else
        {
            m_enabled = false;
            Log("غیرفعال است. توکن، ChatID یا MagicNumber تنظیم نشده.");
        }
        
        m_is_initialized = true;
    }

public:
    CTelegramManager()
    {
        m_enabled = false;
        m_is_initialized = false;
        m_magic_number = 0;
    }
    
    // تابع اصلی پردازش (فراخوانی در OnTimer)
    void Process()
    {
        Init(); // ✅ فراخوانی Init در اولین اجرا
        if (!m_enabled) return;

        // گام ۱: پیدا کردن تمام معاملات باز با magic_number ما
        int positions_total = PositionsTotal();
        for(int i = 0; i < positions_total; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) != m_magic_number) continue;

            // گام ۲: چک کردن اینکه آیا این معامله قبلا ارسال شده یا نه
            bool already_sent = false;
            for(int j = 0; j < ArraySize(m_trade_states); j++)
            {
                if(m_trade_states[j].ticket == ticket)
                {
                    already_sent = true;
                    break;
                }
            }

            // گام ۳: اگر معامله جدید است، پیام را ارسال و وضعیتش را ذخیره کن
            if (!already_sent)
            {
                if(!PositionSelectByTicket(ticket)) continue;

                string symbol = PositionGetString(POSITION_SYMBOL);
                string trade_type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "خرید" : "فروش";
                double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

                string message = StringFormat(
                    "سیگنال جدید در اکسپرت Memento! \n" +
                    "نماد: *%s*\n" +
                    "نوع معامله: *%s*\n" +
                    "قیمت ورود: *%.*f*",
                    symbol,
                    trade_type,
                    (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
                    open_price
                );
                
                SendFormattedMessage(message);
                
                // ذخیره وضعیت معامله
                int new_idx = ArraySize(m_trade_states);
                ArrayResize(m_trade_states, new_idx + 1);
                m_trade_states[new_idx].ticket = ticket;
                m_trade_states[new_idx].is_sent = true;
            }
        }
        
        // گام ۴: پاکسازی معاملات بسته شده از آرایه
        for (int i = ArraySize(m_trade_states) - 1; i >= 0; i--)
        {
            if(!PositionSelectByTicket(m_trade_states[i].ticket))
            {
                ArrayRemove(m_trade_states, i, 1);
            }
        }
    }
    
    // --- توابع کمکی برای ارسال پیام (SendMessage و SendFormattedMessage) ---
    void SendMessage(string message)
    {
        if (!m_enabled) return;
        string params = "chat_id=" + m_chat_id + "&text=" + message;
        SendWebRequest("sendMessage", params);
    }
    
    void SendFormattedMessage(string message, string parse_mode = "Markdown")
    {
        if (!m_enabled) return;
        string params = "chat_id=" + m_chat_id + "&text=" + message + "&parse_mode=" + parse_mode;
        SendWebRequest("sendMessage", params);
    }
    
    // --- تابع ارسال اسکرین‌شات از چارت ---
    void SendChartScreenshot(string symbol, ENUM_TIMEFRAME timeframe, string caption = "")
    {
        if (!m_enabled)
        {
            Log("ارسال اسکرین‌شات غیرفعال است.");
            return;
        }
        // ... بقیه کد تابع SendChartScreenshot ...
    }
};
