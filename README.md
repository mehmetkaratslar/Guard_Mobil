Guard – Gerçek Zamanlı Düşme/Bayılma Algılama ve Bildirim Sistemi

🧠 Proje Amacı

Guard, yaşlılar ve hassas bireyler için geliştirilen, yapay zekâ destekli gerçek zamanlı bir güvenlik sistemidir. Sistem; düşme, bayılma gibi acil durumları anlık olarak analiz eder, kullanıcıya ve ilgili kişilere bildirim gönderir. Sisteme hem masaüstü (PC) hem de mobil uygulama üzerinden erişilebilir.


🧩 Sistem Mimarisi

1. Görüntü Analizi (Python – Masaüstü)

- Teknolojiler: Python, PyTorch, OpenCV, YOLOv11, FastAPI
- Amaç: Kamera görüntülerini analiz ederek düşme olaylarını tespit etmek
- UI Özellikleri:
  - Giriş ve Kayıt ekranı (Firebase Authentication)
  - Bildirim tercihleri (e-posta, telefon, SMS, Telegram)
  - Veri paylaşım ayarları
  - "Sistemi Başlat" butonu
  - Gerçek zamanlı kamera görüntüsü
  - Son algılanan olayın ekran görüntüsü
  - Olay geçmişi ve detayları

2. Veri ve Bildirim Katmanı (Firebase)

- Authentication: Google ile güvenli giriş, çoklu cihaz desteği
- Firestore: Kullanıcı bilgileri ve olay kayıtları (zaman, olasılık, görüntü URL)
- cloud Storage: Düşme anındaki ekran görüntülerinin yüklenmesi
- Cloud Messaging: Anlık bildirim gönderimi (e-posta, SMS, Telegram)

3. Mobil/Web Uygulama (Flutter – Android Studio)

- Giriş & Kayıt: Tüm platformlarda ortak oturum (Firebase Authentication)
- Ana Ekran:
  - Anlık durum ("Her şey normal" / "Düşme algılandı")
  - Son düşme bilgisi (tarih, saat, yer, ekran görüntüsü)
- Canlı izleme (RTSP veya Firebase canlı bağlantı)
- Bildirimı: Önceki olayların listesi ve detaylı görüntüleme
- Ayarlar: Bildirim tercihi, kullanıcı bilgileri, sistem başlat/durdur



🔐 Güvenlik & Senkronizasyon

- Kullanıcı tüm cihazlarda aynı bilgilerle giriş yapabilir.
- Firebase Security Rules: Kullanıcı sadece kendi verilerine erişebilir.
- Gizlilik:Kamera verileri sistemde tutulmaz, sadece olay anının ekran görüntüsü saklanır.
- Veriler uçtan uca şifrelenir.



🚨 Olay Akışı (Senaryo)

1. Kullanıcı masaüstü uygulamasından giriş yapar.
2. "Sistemi Başlat" butonuna tıklar.
3. Kamera verisi analiz edilir.
4. Düşme tespit edilirse:
    - O anın ekran görüntüsü alınır.
    - Firebase Storage'a yüklenir.
    - Firestore’a olay bilgisi yazılır.
    - Bildirim tercihine göre uyarı gönderilir (e-posta, SMS, telefon, Telegram vb.).
5. Mobil uygulamadan da giriş yapılabilir ve geçmiş ile son olaylar görüntülenebilir.
6. Canlı izleme sayfasından ortam anlık olarak gözlemlenebilir.


🔧 Kullanılan Ana Teknolojiler

| Katman           | Teknoloji                               | Açıklama                        |
|------------------|----------------------------------------|---------------------------------|
| Görüntü İşleme   | Python, OpenCV, PyTorch                | Düşme algılama modeli           |
| API Servisi      | FastAPI                                | Python modeli ile Flutter arası |
| Mobil/Web        | Flutter (Android Studio)               | UI ve kullanıcı deneyimi        |
| Giriş            | Firebase Authentication                | Oturum yönetimi                 |
| Veri             | Firebase Firestore + Storage           | Veritabanı ve medya dosyaları   |
| Bildirim         | Firebase Cloud Messaging, Telegram API, SMTP | Anlık uyarı sistemleri    |



📄 Lisans

Bu proje yalnızca eğitim ve geliştirme amaçlıdır.  
Tüm hakları saklıdır.  



 💬 İletişim

Daha fazla bilgi için [proje sahibine](mehmetkarataslar@gmail.com) ulaşabilirsiniz.
