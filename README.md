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








📱 Uygulama Ekranları
1.Açılış Ekranı

![image](https://github.com/user-attachments/assets/c0b418b5-d56b-4d28-bfc4-745187f6ec97)

2. Ana Sayfa (Dashboard)

![Anasayfa](https://github.com/user-attachments/assets/4a880158-1948-41d1-ab86-8d4d612bed39)

* Kullanıcı Selamlaması: Kullanıcıya ismiyle ve güncel tarihle selam verilir.
* Sistem Durumu Kartı: Sistemin kontrol edildiğini veya aktif/pasif durumunu gösteren, dikkat çekici büyük bir kart. Duruma göre arka plan rengi ve ikon değişebilir.
* Olay İstatistikleri:

  * Bugün: O gün gerçekleşen toplam düşme/bayılma olayı sayısı.
  * Toplam:Sistemin kullanılmaya başladığından bu yana tespit edilen toplam olay sayısı.
* Son Olaylar: Son yaşanan olaylar özet olarak listelenir. "Tümünü Gör" ile geçmiş olayların tamamına erişilebilir.
* Alt Menü: Ana Sayfa, Bildirimler, Canlı, Ayarlar bölümlerine hızlı geçiş.


3. Ayarlar Sayfası
4. 
![Ayarlar](https://github.com/user-attachments/assets/5fc14a17-57a5-49ed-91d5-fd5e46a32649)


* Kullanıcı Profili: Profil fotoğrafı, isim ve e-posta bilgileri en üstte yer alır. Düzenleme butonuyla profil bilgileri değiştirilebilir.
* Ayarlar Bölümü:

  * Profil: Kişisel bilgilerin düzenlenmesini sağlar.
  * 
    ![profilBilgisi](https://github.com/user-attachments/assets/5d62dd1d-5f6f-400c-bebf-83a2031dfbff)

  * Bildirimler: Bildirim türleri (e-posta, SMS, Telegram vb.) ve kanallarını ayarlama.
  * 
    ![ProfilBildirim](https://github.com/user-attachments/assets/40ae2b21-cbc2-4497-a5f1-89584d9f689a)

  * Güvenlik: Şifre ve güvenlik seçeneklerini yönetme.
  * 
    ![Güvenlik](https://github.com/user-attachments/assets/49019031-4188-4ba8-b2f0-58a8cba3179e)

* Uygulama Bölümü:

  * Hakkında:Uygulamanın sürümü ve geliştirici bilgileri.
  * 
![Hakkında](https://github.com/user-attachments/assets/9b430579-c470-450d-aa14-9528ca326975)



3. Bildirimler Sayfası

![BildirimDüzenlenmiş](https://github.com/user-attachments/assets/3d05cea5-52cc-4e73-af13-17e2f271e4ae)


* Olay Kartları: Her olay için:

  * Başlık: Düşme Algılandı gibi bir uyarı başlığı.
  * Tarih & Saat: Olayın zamanı.
  * Olay Görüntüsü: Tespit anındaki kamera görüntüsü otomatik olarak eklenir.
  * Olasılık: Modelin verdiği doğruluk/olasılık oranı (% olarak).
* Yenile Butonu: En güncel olayların görülmesi için sayfa kolayca yenilenebilir.




 4. Canlı İzleme Alanı

![Canlı_izleme](https://github.com/user-attachments/assets/ce9eef9d-e76a-489b-b62f-7fe9f2da77a3)


* Canlı İzleme Kartı: Kullanıcı henüz bağlanmadıysa, kamera bağlantısı simgesi ve bilgi mesajı görülür. Bağlanınca, gerçek zamanlı video akışı burada gösterilir.
* Kamera Bağlantı Formu:
  * IP Address & Port: Bilgisayar üzerinde çalışan kamera sunucusunun adresi ve portu girilir.
  * Bağlan Butonu: "Connect & Watch" tuşuna basılarak canlı görüntüye erişim sağlanır.





📄 Lisans

Bu proje yalnızca eğitim ve geliştirme amaçlıdır.  
Tüm hakları saklıdır.  



 💬 İletişim

Daha fazla bilgi için [proje sahibine](mehmetkarataslar@gmail.com) ulaşabilirsiniz.
