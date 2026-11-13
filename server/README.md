# سرور نرخ دیه — راهنمای نصب روی VPS

سرویس یک endpoint دارد: `GET /api/v1/diyeh-rates` (و `GET /api/v1/health` برای بررسی سلامت).
در پوشه‌ی جدا (`/opt/diyeh-api`)، با کاربر لینوکسی جدا (`diyehapi`) و سرویس systemd جدا (`diyeh-api`) اجرا می‌شود و فقط روی `127.0.0.1:8105` گوش می‌دهد؛ بنابراین با سرویس‌های دیگر تداخل ندارد.

## پیش‌نیاز
- Python نسخه‌ی ۳٫۹ یا بالاتر: `python3 --version`
- آزاد بودن پورت 8105: `sudo ss -ltnp | grep 8105` (اگر خروجی داشت، پورت اشغال است؛ عدد دیگری انتخاب کنید و در `deploy/diyeh-api.service` و `deploy/nginx_api.vakilrobot.ir.conf` عوض کنید.)
- رکورد DNS از نوع A برای `api.vakilrobot.ir` به IP همین سرور.
- nginx و certbot (برای HTTPS؛ اپ اندروید بدون HTTPS وصل نمی‌شود).

## نصب (یک‌بار)

۱. فایل‌ها را از کامپیوتر خودتان به سرور بفرستید (در پوشه‌ی `server` مخزن):
```bash
scp -r ./* USER@VPS_IP:/tmp/diyeh-api/
```

۲. روی سرور:
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin diyehapi
sudo mkdir -p /opt/diyeh-api
sudo cp -r /tmp/diyeh-api/* /opt/diyeh-api/
sudo python3 -m venv /opt/diyeh-api/venv
sudo /opt/diyeh-api/venv/bin/pip install -r /opt/diyeh-api/requirements.txt
```
اگر PyPI از سرور در دسترس نبود، از یک mirror داخلی pip استفاده کنید.

۳. دسترسی‌ها (سرویس فقط خواندن لازم دارد):
```bash
sudo chown -R root:diyehapi /opt/diyeh-api
sudo chmod -R g+rX,o-rwx /opt/diyeh-api
```

۴. بررسی فایل نرخ:
```bash
cd /opt/diyeh-api && sudo venv/bin/python validate_rates_v1.py data/diyeh_rates_1405.json
```

۵. نصب و اجرای سرویس:
```bash
sudo cp /opt/diyeh-api/deploy/diyeh-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now diyeh-api
sudo systemctl status diyeh-api
curl http://127.0.0.1:8105/api/v1/health
```
پاسخ درست: `{"schema_version":1,"status":"ok","updated_at":"1405-08-22","year":1405}`

۶. nginx و HTTPS (سایت جدا برای `api.vakilrobot.ir`، بدون دست زدن به سایت‌های دیگر):
```bash
sudo cp /opt/diyeh-api/deploy/nginx_api.vakilrobot.ir.conf /etc/nginx/sites-available/api.vakilrobot.ir
sudo ln -s /etc/nginx/sites-available/api.vakilrobot.ir /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl http://api.vakilrobot.ir/api/v1/health
sudo certbot --nginx -d api.vakilrobot.ir
curl https://api.vakilrobot.ir/api/v1/health
```

## کارهای روزمره
- **لاگ:** `sudo journalctl -u diyeh-api -f`
- **ویرایش نرخ یا آیتم‌ها:** راهنمای `README.md` در ریشه‌ی مخزن. بعد از ویرایش فایل JSON **ری‌استارت لازم نیست**.
- **اگر فایل ویرایش‌شده خطا داشته باشد:** سرور همان نسخه‌ی سالم قبلی را می‌دهد و خطا را در لاگ می‌نویسد. پس همیشه بعد از ویرایش، `validate_rates_v1.py` را اجرا کنید.
- **ری‌استارت خودکار:** اگر سرویس بیفتد، systemd بعد از ۳ ثانیه دوباره اجرایش می‌کند؛ بعد از ریبوت سرور هم خودکار بالا می‌آید.

## نسخه‌ی جدید کد سرور
طبق `NAMING.md`: فایل جدید (مثلاً `diyeh_api_v2.py`) کنار نسخه‌ی قبلی کپی می‌شود، در `/etc/systemd/system/diyeh-api.service` نام `diyeh_api_v1:app` به `diyeh_api_v2:app` تغییر می‌کند و:
```bash
sudo systemctl daemon-reload && sudo systemctl restart diyeh-api
```
برای برگشت، همین کار را با نام نسخه‌ی قبلی انجام دهید.

## تست روی کامپیوتر توسعه
```bash
python3 -m venv venv && venv/bin/pip install -r requirements-dev.txt
venv/bin/python -m pytest -q
```
